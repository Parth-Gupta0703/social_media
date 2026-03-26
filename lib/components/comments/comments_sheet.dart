// lib/pages/comments/comments_sheet.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/services/moderation_service.dart';
import 'package:social_media/services/social_notification_service.dart';

import 'comment_item.dart';
import 'reply_sheet.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final controller = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  final _moderationService = ModerationService();
  final _socialNotifService = SocialNotificationService.instance;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    unawaited(_moderationService.warmUpBackend());
  }

  @override
  void dispose() {
    _moderationService.dispose();
    controller.dispose();
    super.dispose();
  }

  // ── Add comment ──────────────────────────────────────────────────────────────

  Future<void> addComment() async {
    final text = controller.text.trim();
    if (text.isEmpty || _isSubmittingComment) return;

    setState(() => _isSubmittingComment = true);

    try {
      final mod = await _moderationService.moderatePost(text);
      if (!mounted) return;

      if (mod.action == 'allow') {
        // COLLECTION NAME: 'UserPosts' (no space).
        await FirebaseFirestore.instance
            .collection('UserPosts')
            .doc(widget.postId)
            .collection('Comments')
            .add({
              'UserEmail': user.email,
              'UserId': user.uid,
              'Text': text,
              'Time': Timestamp.now(),
              'Likes': <String>[],
            });

        controller.clear();

        // Notify the post owner that someone commented.
        unawaited(
          _socialNotifService.notifyOnComment(
            postOwnerId: widget.postOwnerId,
            postId: widget.postId,
            commentPreview: text,
          ),
        );
        return;
      }

      // Flagged — store for review.
      // COLLECTION NAME: 'ModeratedComments' (no space).
      await FirebaseFirestore.instance.collection('ModeratedComments').add({
        'UserEmail': user.email,
        'UserId': user.uid,
        'PostId': widget.postId,
        'Type': 'comment',
        'Text': text,
        'Reason': mod.reason,
        'MatchedCount': mod.matchedCount,
        'TimeStamp': Timestamp.now(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Comment removed'),
          content: Text(
            mod.reason.isNotEmpty
                ? mod.reason
                : 'This comment violated moderation rules.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add comment right now'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  // ── Like toggle ──────────────────────────────────────────────────────────────

  void toggleCommentLike(
    DocumentReference commentRef,
    List<String> likes,
    String commentOwnerId,
  ) {
    if (likes.contains(user.uid)) {
      commentRef.update({
        'Likes': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      commentRef.update({
        'Likes': FieldValue.arrayUnion([user.uid]),
      });
      unawaited(
        _socialNotifService.notifyOnCommentLike(
          commentOwnerId: commentOwnerId,
          postId: widget.postId,
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool _isOwner(Map<String, dynamic> data) {
    return data['UserId'] == user.uid || data['UserEmail'] == user.email;
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required String label,
    required Future<void> Function() onDelete,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $label'),
        content: Text('Are you sure you want to delete this $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes != true) return;
    await onDelete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('$label deleted'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteCommentWithReplies(DocumentReference commentRef) async {
    final repliesSnap = await commentRef.collection('Replies').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final reply in repliesSnap.docs) {
      batch.delete(reply.reference);
    }
    batch.delete(commentRef);
    await batch.commit();
  }

  void showReplySheet(DocumentReference commentRef, String commentOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReplySheet(
        commentRef: commentRef,
        user: user,
        postId: widget.postId,
        commentOwnerId: commentOwnerId,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFB6C1),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.comment,
                    color: Color(0xFFFFB6C1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey[200]),

          // Comments list
          Expanded(
            child: SafeArea(
              top: false,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                // COLLECTION NAME: 'UserPosts' (no space).
                stream: FirebaseFirestore.instance
                    .collection('UserPosts')
                    .doc(widget.postId)
                    .collection('Comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load comments',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFB6C1),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs.toList() ?? [];
                  docs.sort((a, b) {
                    final aT = a.data()['Time'];
                    final bT = b.data()['Time'];
                    final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
                    final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
                    return bMs.compareTo(aMs);
                  });

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to comment!',
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final commentData = doc.data();
                      final likesVal = commentData['Likes'];
                      final commentLikes = likesVal is Iterable
                          ? List<String>.from(likesVal)
                          : <String>[];
                      final commentOwnerId =
                          commentData['UserId'] as String? ?? '';

                      return CommentItem(
                        commentRef: doc.reference,
                        commentData: commentData,
                        commentLikes: commentLikes,
                        isCommentLiked: commentLikes.contains(user.uid),
                        isCommentOwner: _isOwner(commentData),
                        currentUserId: user.uid,
                        isOwner: _isOwner,
                        onToggleLike: (ref, likes) =>
                            toggleCommentLike(ref, likes, commentOwnerId),
                        onReply: () =>
                            showReplySheet(doc.reference, commentOwnerId),
                        onDeleteComment: () => _confirmDelete(
                          context: context,
                          label: 'Comment',
                          onDelete: () =>
                              _deleteCommentWithReplies(doc.reference),
                        ),
                        onDeleteReply: (replyRef) => _confirmDelete(
                          context: context,
                          label: 'Reply',
                          onDelete: () => replyRef.delete(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB6C1), Color(0xFFFFDAB9)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSubmittingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSubmittingComment ? null : addComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
