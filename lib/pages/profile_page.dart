// User profile page — shows avatar, stats, and blocked post history.
// Extracted from home_page.dart for clarity.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _userPostsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _moderatedPostsStream;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedModeratedDocs = [];
  bool _hasModeratedSnapshot = false;

  @override
  void initState() {
    super.initState();
    _userPostsStream = FirebaseFirestore.instance
        .collection('UserPosts')
        .where('UserId', isEqualTo: widget.user.uid)
        .snapshots();
    _moderatedPostsStream = FirebaseFirestore.instance
        .collection('ModeratedPosts')
        .where('UserId', isEqualTo: widget.user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE5EC), Color(0xFFFFF0F5), Color(0xFFFFEFD5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB4A7D6), Color(0xFFD8B4E2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0x1AB4A7D6),
                    child: Text(
                      widget.user.email![0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB4A7D6),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                widget.user.email!.split('@')[0],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.email!,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

              // ── Stats ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _userPostsStream,
                  builder: (context, snapshot) {
                    final postCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Posts',
                            value: postCount.toString(),
                            icon: Icons.article_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: 'Member',
                            value: 'Since ${DateTime.now().year}',
                            icon: Icons.calendar_today,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── Moderated posts ──────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ModeratedPosts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _moderatedPostsStream,
                          builder: (context, snapshot) {
                            final freshDocs = snapshot.data?.docs.toList();
                            if (freshDocs != null) {
                              freshDocs.sort((a, b) {
                                final aTs = a.data()['TimeStamp'];
                                final bTs = b.data()['TimeStamp'];
                                final aMs = aTs is Timestamp
                                    ? aTs.millisecondsSinceEpoch
                                    : 0;
                                final bMs = bTs is Timestamp
                                    ? bTs.millisecondsSinceEpoch
                                    : 0;
                                return bMs.compareTo(aMs);
                              });
                              _cachedModeratedDocs = freshDocs;
                              _hasModeratedSnapshot = true;
                            }
                            final docs = _cachedModeratedDocs;

                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !_hasModeratedSnapshot &&
                                docs.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFB4A7D6),
                                ),
                              );
                            }

                            if (snapshot.hasError && docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'Unable to load moderated posts right now',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }

                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 64,
                                        color: Colors.green[300],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No moderated posts!',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'All your posts are clean and safe',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              key: const PageStorageKey<String>(
                                'profile_moderated_posts',
                              ),
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data();
                                final ts = data['TimeStamp'];
                                final reason = data['Reason']?.toString();
                                final message =
                                    data['Message']?.toString() ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.block,
                                            color: Colors.red[400],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Blocked by AI Moderator',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF2D3142),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Reason: ${reason?.isNotEmpty == true ? reason : 'Inappropriate content'}',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        ts is Timestamp
                                            ? timeago.format(ts.toDate())
                                            : 'Recently',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB4A7D6), size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
