// The expandable moderation card shown in the admin queue list.
// Handles Delete (permanent) and Dismiss (queue-only) actions with audit logging.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'moderation_context_view.dart';
import 'moderation_dialogs.dart';
import 'moderation_utils.dart';
import 'moderation_widgets.dart';

class ModerationCard extends StatefulWidget {
  const ModerationCard({super.key, required this.doc, required this.icon});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final IconData icon;

  @override
  State<ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<ModerationCard> {
  bool _loading = false;
  bool _expanded = false;

  // ── Reason styling helpers ────────────────────────────────────────────────

  Color _reasonColor(String reason) {
    final t = reason.toLowerCase();
    if (t.contains('spam')) return const Color(0xFF9B59B6);
    if (t.contains('hate') || t.contains('abuse'))
      return const Color(0xFFFF6B6B);
    if (t.contains('violence') || t.contains('threat'))
      return const Color(0xFFEE5A24);
    if (t.contains('explicit') || t.contains('adult'))
      return const Color(0xFFFF9F43);
    if (t.contains('misinform')) return const Color(0xFF00B4D8);
    return const Color(0xFF6C63FF);
  }

  IconData _reasonIcon(String reason) {
    final t = reason.toLowerCase();
    if (t.contains('spam')) return Icons.mark_email_unread_rounded;
    if (t.contains('hate') || t.contains('abuse'))
      return Icons.sentiment_very_dissatisfied_rounded;
    if (t.contains('violence') || t.contains('threat'))
      return Icons.dangerous_rounded;
    if (t.contains('explicit') || t.contains('adult'))
      return Icons.no_adult_content_rounded;
    if (t.contains('misinform')) return Icons.info_outline_rounded;
    return Icons.flag_rounded;
  }

  // ── Delete: permanently removes live content + clears ticket ─────────────

  Future<void> _onDelete() async {
    final data = widget.doc.data();
    final userEmail = extractEmail(data);

    final reason = await pickCannedReason(context);
    if (reason == null || !mounted) return;

    final confirmed = await showModerationConfirmDialog(
      context,
      title: 'Permanently delete content?',
      body:
          'This will:\n• Remove the content from the app for all users\n• Clear the report from the queue\n\nReason: $reason',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Delete live post + its comments/replies (admin-flagged content)
      final originalPostId = data['OriginalPostId'] as String?;
      if (originalPostId != null && originalPostId.isNotEmpty) {
        final postRef = db.collection('UserPosts').doc(originalPostId);
        final commentsSnap = await postRef.collection('Comments').get();
        for (final comment in commentsSnap.docs) {
          final repliesSnap = await comment.reference
              .collection('Replies')
              .get();
          for (final reply in repliesSnap.docs) {
            batch.delete(reply.reference);
          }
          batch.delete(comment.reference);
        }
        batch.delete(postRef);
      }

      // Delete a live comment/reply if CommentPath is set
      final commentPath = data['CommentPath'] as String?;
      if (commentPath != null && commentPath.isNotEmpty) {
        final commentRef = db.doc(commentPath);
        final repliesSnap = await commentRef.collection('Replies').get();
        for (final reply in repliesSnap.docs) {
          batch.delete(reply.reference);
        }
        batch.delete(commentRef);
      }

      // Always delete the moderation ticket
      batch.delete(widget.doc.reference);
      await batch.commit();

      // Audit log
      await db.collection('Admin Activity').add({
        'Action': 'delete',
        'AdminEmail':
            FirebaseAuth.instance.currentUser?.email ?? 'unknown_admin',
        'TargetId': widget.doc.id,
        'TargetEmail': userEmail,
        'OriginalPostId': originalPostId,
        'Reason': reason,
        'Count': 1,
        'Timestamp': Timestamp.now(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  // ── Dismiss: only removes the report ticket, content stays live ──────────

  Future<void> _onDismiss() async {
    final data = widget.doc.data();
    final userEmail = extractEmail(data);

    final confirmed = await showModerationConfirmDialog(
      context,
      title: 'Dismiss this report?',
      body:
          'The report is a false alarm. The content stays live and the report is removed from the queue.',
      confirmLabel: 'Dismiss',
      danger: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);

    try {
      await widget.doc.reference.delete();

      await FirebaseFirestore.instance.collection('Admin Activity').add({
        'Action': 'dismiss',
        'AdminEmail':
            FirebaseAuth.instance.currentUser?.email ?? 'unknown_admin',
        'TargetId': widget.doc.id,
        'TargetEmail': userEmail,
        'Reason': 'False positive / dismissed',
        'Count': 1,
        'Timestamp': Timestamp.now(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final message = extractMessage(data);
    final reason = extractReason(data);
    final userEmail = extractEmail(data);
    final itemType = extractType(data);
    final timestamp = data['TimeStamp'] ?? data['Time'];
    final flaggedBy = data['FlaggedBy'] as String?;
    final hasOriginalPost =
        (data['OriginalPostId'] as String?)?.isNotEmpty == true;
    final hasParentContext =
        (data['PostId'] as String?)?.isNotEmpty == true ||
        (data['CommentPath'] as String?)?.isNotEmpty == true;

    final color = _reasonColor(reason);
    final reasonIcon = _reasonIcon(reason);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Collapsed header ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(reasonIcon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ReasonChip(reason: reason, color: color),
                            TypeChip(text: itemType),
                            if (flaggedBy == 'admin')
                              const TypeChip(
                                text: 'Admin Flagged',
                                borderColor: Color(0xFF6C63FF),
                                textColor: Color(0xFF6C63FF),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFF677489),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF677489),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail panel ────────────────────────────────────────
          if (_expanded)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTENT',
                    style: TextStyle(
                      color: Color(0xFF7D8A9C),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF3C4659),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Color(0xFF677489),
                      fontSize: 12,
                    ),
                  ),
                  if (timeAgo(timestamp).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeAgo(timestamp),
                      style: const TextStyle(
                        color: Color(0xFF7D8A9C),
                        fontSize: 11,
                      ),
                    ),
                  ],

                  // View parent thread context button
                  if (hasParentContext) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      icon: const Icon(
                        Icons.account_tree_rounded,
                        color: Color(0xFF6C63FF),
                        size: 15,
                      ),
                      label: const Text(
                        'View Parent Thread Context',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () =>
                          showModerationContext(context, widget.doc),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Warning banner for admin-flagged live posts
                  if (hasOriginalPost)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFFF9F43),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Delete will permanently remove the live post & all its comments from the app.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB05A00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFFF6B6B),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  color: Color(0xFFFF6B6B),
                                  size: 16,
                                ),
                                label: const Text(
                                  'Delete Content',
                                  style: TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: _onDelete,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loading
                            ? const SizedBox.shrink()
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C49A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: _onDismiss,
                              ),
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
