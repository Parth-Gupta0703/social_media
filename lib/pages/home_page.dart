// lib/pages/home_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/components/user_post.dart';
import 'package:social_media/services/moderation_service.dart';
import 'package:social_media/services/rate_limit_service.dart';
import 'package:social_media/services/social_notification_service.dart';

import 'create_post_sheet.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _user = FirebaseAuth.instance.currentUser!;
  final _textController = TextEditingController();
  final _moderationService = ModerationService();
  final _rateLimitService = RateLimitService.instance;
  final _socialNotifService = SocialNotificationService.instance;

  late AnimationController _fabController;
  bool _isSubmittingPost = false;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    unawaited(_moderationService.startWarmUpSequence());
    _socialNotifService.startListening(); // Start inbox listener for this user.
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _socialNotifService.stopListening();
    _moderationService.dispose();
    _fabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ── Cooldown timer ───────────────────────────────────────────────────────────

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = _rateLimitService.secondsUntilNextAllowed();
    if (_cooldownSeconds <= 0) return;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  // ── Post submission ──────────────────────────────────────────────────────────

  Future<void> _postMessage(BuildContext sheetContext) async {
    final postText = _textController.text.trim();
    if (postText.isEmpty || _isSubmittingPost) return;

    // Layer 1 — rate limit check (instant, no network).
    final rl = _rateLimitService.canCreatePost();
    if (!rl.allowed) {
      _startCooldownTimer();
      _showErrorSnackBar(rl.reason ?? 'Please wait before posting again.');
      return;
    }

    setState(() => _isSubmittingPost = true);

    try {
      // Layer 2 — AI content moderation.
      final mod = await _moderationService.moderatePost(postText);
      if (!mounted) return;

      if (mod.action == 'allow') {
        // Layer 3 — Firestore write.
        // COLLECTION NAME: 'UserPosts' (no space — required for Firestore rules).
        final docRef = await FirebaseFirestore.instance
            .collection('UserPosts')
            .add({
              'UserEmail': _user.email,
              'UserId': _user.uid,
              'Message': postText,
              'TimeStamp': Timestamp.now(),
              'Likes': [],
            });

        _rateLimitService.recordPost();

        // Notify all other users about the new post.
        unawaited(
          _socialNotifService.notifyAllOnNewPost(
            postId: docRef.id,
            postPreview: postText,
          ),
        );

        _textController.clear();
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

      // Flagged by moderation — store for review.
      // COLLECTION NAME: 'ModeratedPosts' (no space).
      await FirebaseFirestore.instance.collection('ModeratedPosts').add({
        'UserEmail': _user.email,
        'UserId': _user.uid,
        'Message': postText,
        'Reason': mod.reason,
        'MatchedCount': mod.matchedCount,
        'TimeStamp': Timestamp.now(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Post removed'),
          content: Text(
            mod.reason.isNotEmpty
                ? mod.reason
                : 'This post violated our community guidelines.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Unable to submit post right now. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmittingPost = false);
    }
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────

  void _showCreatePostSheet() {
    final rl = _rateLimitService.canCreatePost();
    if (!rl.allowed) {
      _startCooldownTimer();
      _showErrorSnackBar(rl.reason ?? 'Please wait before posting again.');
      return;
    }
    CreatePostSheet.show(
      context,
      controller: _textController,
      isSubmitting: _isSubmittingPost,
      onPost: () => _postMessage(context),
      onCancel: () => Navigator.pop(context),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
              child: const Icon(Icons.shield, color: Colors.white, size: 20),
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
              MaterialPageRoute(builder: (_) => ProfilePage(user: _user)),
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
            // COLLECTION NAME: 'UserPosts' (no space).
            stream: FirebaseFirestore.instance
                .collection('UserPosts')
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
                        child: const Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: Color(0xFFB4A7D6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No posts yet!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share something',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostSheet,
        backgroundColor: _cooldownSeconds > 0
            ? const Color(0xFFB4A7D6).withOpacity(0.55)
            : const Color(0xFFB4A7D6),
        elevation: 4,
        icon: _cooldownSeconds > 0
            ? const Icon(Icons.timer_outlined)
            : const Icon(Icons.add),
        label: Text(
          _cooldownSeconds > 0 ? 'Wait ${_cooldownSeconds}s' : 'Post',
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _appBarIcon(IconData icon, Color color) {
    return Container(
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
      child: Icon(icon, color: color),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _moderationService.cancelWarmUpSequence();
              _rateLimitService.reset();
              _socialNotifService.stopListening();
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
