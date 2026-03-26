// Admin Moderation Page — entry point.
// This file contains only the page scaffold, tab layout, header, and
// the moderation list widget. All logic is split into the moderation/ subfolder:
//
//   moderation_card.dart       — expandable card widget (delete/dismiss actions)
//   moderation_dialogs.dart    — canned reason picker + confirm dialogs
//   moderation_context_view.dart — parent thread context bottom sheet
//   moderation_widgets.dart    — shared chip, pill, and block widgets
//   moderation_utils.dart      — shared field-reading utility functions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'moderation/moderation_card.dart';
import 'moderation/moderation_utils.dart';
import 'moderation/moderation_widgets.dart';

// ── Main page ─────────────────────────────────────────────────────────────────

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF4FF), Color(0xFFFFF1F6), Color(0xFFFFF8EE)],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 154,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF6B6B),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF6B6B),
                unselectedLabelColor: const Color(0xFF677489),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Flagged Posts'),
                  Tab(text: 'Flagged Comments'),
                ],
              ),
            ),
          ],
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ModerationList(
                      collection: 'ModeratedPosts',
                      emptyLabel: 'No flagged posts',
                      icon: Icons.article_rounded,
                      searchQuery: _searchQuery,
                    ),
                    _ModerationList(
                      collection: 'ModeratedComments',
                      emptyLabel: 'No flagged comments',
                      icon: Icons.comment_rounded,
                      searchQuery: _searchQuery,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        style: const TextStyle(color: Color(0xFF2D3142)),
        decoration: InputDecoration(
          hintText: 'Search by reason, content, or user email...',
          hintStyle: const TextStyle(color: Color(0xFF7D8A9C)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF7D8A9C),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF7D8A9C),
                  ),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) =>
            setState(() => _searchQuery = value.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE6EC), Color(0xFFFFF1D9)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Moderation Queue',
                      style: TextStyle(
                        color: Color(0xFF2D3142),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('ModeratedPosts')
                              .snapshots(),
                          builder: (_, snap) => CountPill(
                            '${snap.data?.docs.length ?? 0} posts',
                            const Color(0xFFFF6B6B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('ModeratedComments')
                              .snapshots(),
                          builder: (_, snap) => CountPill(
                            '${snap.data?.docs.length ?? 0} comments',
                            const Color(0xFFFF9F43),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Moderation list ───────────────────────────────────────────────────────────

class _ModerationList extends StatelessWidget {
  const _ModerationList({
    required this.collection,
    required this.emptyLabel,
    required this.icon,
    required this.searchQuery,
  });

  final String collection;
  final String emptyLabel;
  final IconData icon;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('TimeStamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
          );
        }

        var items = snapshot.data?.docs ?? const [];

        if (searchQuery.isNotEmpty) {
          items = items.where((doc) {
            final d = doc.data();
            return extractMessage(d).toLowerCase().contains(searchQuery) ||
                extractReason(d).toLowerCase().contains(searchQuery) ||
                extractEmail(d).toLowerCase().contains(searchQuery) ||
                extractType(d).toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C49A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00C49A),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'All clear',
                  style: TextStyle(
                    color: Color(0xFF2D3142),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emptyLabel,
                  style: const TextStyle(
                    color: Color(0xFF677489),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // ── Toolbar row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _PendingBadge(count: items.length),
                  const Spacer(),
                  _DismissAllButton(onTap: () => _dismissAll(context, items)),
                ],
              ),
            ),
            // ── Item list ──────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => ModerationCard(
                  key: ValueKey(items[index].id),
                  doc: items[index],
                  icon: icon,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _dismissAll(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD7DCE5)),
        ),
        title: const Text(
          'Dismiss all reports?',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This clears all ${docs.length} items from the queue. The original content remains live.',
          style: const TextStyle(color: Color(0xFF677489)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7D8A9C)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              await FirebaseFirestore.instance
                  .collection('Admin Activity')
                  .add({
                    'Action': 'dismiss_all',
                    'AdminEmail':
                        FirebaseAuth.instance.currentUser?.email ??
                        'unknown_admin',
                    'Reason': 'Bulk dismiss',
                    'Count': docs.length,
                    'Timestamp': Timestamp.now(),
                  });
            },
            child: const Text(
              'Dismiss All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar helper widgets ────────────────────────────────────────────────────

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFFF6B6B), size: 13),
          const SizedBox(width: 5),
          Text(
            '$count item${count > 1 ? 's' : ''} pending',
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissAllButton extends StatelessWidget {
  const _DismissAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7DCE5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.clear_all_rounded, color: Color(0xFF677489), size: 13),
            SizedBox(width: 4),
            Text(
              'Dismiss All',
              style: TextStyle(
                color: Color(0xFF677489),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
