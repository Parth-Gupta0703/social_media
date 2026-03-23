// Home Page — the main social feed.
// Related files:
//   profile_page.dart      — user profile screen (was previously in this file)
//   create_post_sheet.dart — "Create Post" bottom sheet widget

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/components/user_post.dart';
import 'package:social_media/services/moderation_service.dart';

import 'create_post_sheet.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;
  final textController = TextEditingController();
  final ModerationService _moderationService = ModerationService();
  late AnimationController _fabController;
  bool _isSubmittingPost = false;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    unawaited(_moderationService.startWarmUpSequence());
  }

  @override
  void dispose() {
    _moderationService.dispose();
    _fabController.dispose();
    textController.dispose();
    super.dispose();
  }

  // ── Post submission ─────────────────────────────────────────────────────────

  Future<void> _postMessage(BuildContext sheetContext) async {
    final postText = textController.text.trim();
    if (postText.isEmpty || _isSubmittingPost) return;

    setState(() => _isSubmittingPost = true);

    try {
      final moderationResult = await _moderationService.moderatePost(postText);

      if (!mounted) return;

      if (moderationResult.action == 'allow') {
        await FirebaseFirestore.instance.collection('User Posts').add({
          'UserEmail': user.email,
          'UserId': user.uid,
          'Message': postText,
          'TimeStamp': Timestamp.now(),
          'Likes': [],
        });

        textController.clear();
        if (!mounted) return;
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Post was flagged by SLM — store in Moderated Posts
      await FirebaseFirestore.instance.collection('Moderated Posts').add({
        'UserEmail': user.email,
        'UserId': user.uid,
        'Message': postText,
        'Reason': moderationResult.reason,
        'MatchedCount': moderationResult.matchedCount,
        'TimeStamp': Timestamp.now(),
      });

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Post removed'),
          content: Text(
            moderationResult.reason.isNotEmpty
                ? moderationResult.reason
                : 'This post violated moderation rules.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit post right now'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingPost = false);
    }
  }

  void _showCreatePostSheet() {
    CreatePostSheet.show(
      context,
      controller: textController,
      isSubmitting: _isSubmittingPost,
      onPost: () => _postMessage(context),
      onCancel: () => Navigator.pop(context),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB6C1), Color(0xFFFFDAB9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.shield, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('SafeSpot'),
          ],
        ),
        actions: [
          IconButton(
            icon: _appBarIcon(Icons.person, const Color(0xFFB4A7D6)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _appBarIcon(Icons.logout, const Color(0xFFFF6B6B)),
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 151, 210, 230),
                Color(0xFFFFF0F5),
                Color(0xFFFFEFD5),
              ],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('User Posts')
                  .orderBy('TimeStamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB4A7D6)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0x1AB4A7D6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.forum_outlined,
                              size: 64, color: Color(0xFFB4A7D6)),
                        ),
                        const SizedBox(height: 24),
                        const Text('No posts yet!',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142))),
                        const SizedBox(height: 8),
                        Text('Be the first to share something',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 120),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    return TweenAnimationBuilder(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) =>
                          Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      ),
                      child: UserPost(post: doc),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 1500),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          final bounce = (value < 0.5 ? value * 2 : (1 - value) * 2);
          return Transform.translate(
            offset: Offset(0, -10 * bounce),
            child: child,
          );
        },
        onEnd: () {
          if (mounted) setState(() {});
        },
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostSheet,
          backgroundColor: const Color(0xFFB4A7D6),
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text('Post'),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _appBarIcon(IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, color: iconColor),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFFF6B6B)),
            SizedBox(width: 12),
            Text('Logout?'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _moderationService.cancelWarmUpSequence();
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
