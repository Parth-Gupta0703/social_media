// Shows a draggable bottom sheet displaying the parent post and/or parent comment
// for a flagged comment or reply. Provides full conversational context to the admin.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'moderation_utils.dart';
import 'moderation_widgets.dart';

/// Opens the context bottom-sheet for a flagged [doc].
/// Fetches parent post (via [PostId]) and parent comment (via [CommentPath]).
Future<void> showModerationContext(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final data = doc.data();
  final postId = data['PostId'] as String?;
  final commentPath = data['CommentPath'] as String?;
  final contentType = readFirst(data, ['Type'], fallback: 'comment');

  if (postId == null && commentPath == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parent context available for this item.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  String? parentPostText;
  String? parentCommentText;
  String? parentPostEmail;
  String? parentCommentEmail;

  try {
    if (postId != null) {
      final snap = await FirebaseFirestore.instance
          .collection('User Posts')
          .doc(postId)
          .get();
      if (snap.exists) {
        final d = snap.data()!;
        parentPostText = d['Message'] as String?;
        parentPostEmail = d['UserEmail'] as String?;
      }
    }
    if (commentPath != null && commentPath.isNotEmpty) {
      final snap =
          await FirebaseFirestore.instance.doc(commentPath).get();
      if (snap.exists) {
        final d = snap.data();
        parentCommentText = d?['Text'] as String?;
        parentCommentEmail = d?['UserEmail'] as String?;
      }
    }
  } catch (_) {}

  if (!context.mounted) return;

  final flaggedText = extractMessage(data);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_rounded,
                      color: Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Content Thread Context',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3142)),
                  ),
                  const Spacer(),
                  TypeChip(
                      text: contentType == 'reply' ? 'Reply' : 'Comment'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Showing the parent post and comment that this '
                '${contentType == 'reply' ? 'reply' : 'comment'} was made in.',
                style:
                    const TextStyle(color: Color(0xFF9CACCF), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (parentPostText != null) ...[
                    ContextBlock(
                      label: '📄 Parent Post',
                      color: const Color(0xFF6C63FF),
                      text: parentPostText,
                      email: parentPostEmail,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (parentCommentText != null) ...[
                    ContextBlock(
                      label: '💬 Parent Comment',
                      color: const Color(0xFF00B4D8),
                      text: parentCommentText,
                      email: parentCommentEmail,
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ── Flagged content ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag_rounded,
                                color: Color(0xFFFF6B6B), size: 14),
                            SizedBox(width: 6),
                            Text('FLAGGED CONTENT',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF6B6B),
                                    letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(flaggedText,
                            style: const TextStyle(
                                color: Color(0xFF3C4659),
                                fontSize: 13,
                                height: 1.5)),
                      ],
                    ),
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
