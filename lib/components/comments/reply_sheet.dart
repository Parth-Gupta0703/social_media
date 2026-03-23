import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/services/moderation_service.dart';

// Reply composer bottom sheet.
class ReplySheet extends StatefulWidget {
  final DocumentReference commentRef;
  final User user;
  final String postId;

  const ReplySheet({
    super.key,
    required this.commentRef,
    required this.user,
    required this.postId,
  });

  @override
  State<ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<ReplySheet> {
  // Local controller for the reply field.
  final replyController = TextEditingController();
  final ModerationService _moderationService = ModerationService();
  bool _isSubmittingReply = false;

  @override
  void initState() {
    super.initState();
    unawaited(_moderationService.warmUpBackend());
  }

  @override
  void dispose() {
    _moderationService.dispose();
    replyController.dispose();
    super.dispose();
  }

  // Persist reply then close the sheet.
  Future<void> submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty || _isSubmittingReply) return;

    setState(() => _isSubmittingReply = true);

    try {
      final moderationResult = await _moderationService.moderatePost(text);
      if (!mounted) return;

      if (moderationResult.action == 'allow') {
        await widget.commentRef.collection('Replies').add({
          'UserEmail': widget.user.email,
          'UserId': widget.user.uid,
          'Text': text,
          'Time': Timestamp.now(),
          'Likes': <String>[],
        });

        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      await FirebaseFirestore.instance.collection('Moderated Comments').add({
        'UserEmail': widget.user.email,
        'UserId': widget.user.uid,
        'PostId': widget.postId,
        'CommentPath': widget.commentRef.path,
        'Type': 'reply',
        'Text': text,
        'Reason': moderationResult.reason,
        'MatchedCount': moderationResult.matchedCount,
        'TimeStamp': Timestamp.now(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reply removed'),
          content: Text(
            moderationResult.reason.isNotEmpty
                ? moderationResult.reason
                : 'This reply violated moderation rules.',
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
          content: Text('Unable to add reply right now'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write a reply',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyController,
                decoration: const InputDecoration(
                  hintText: "Reply...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSubmittingReply ? null : submitReply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB6C1),
                  ),
                  child: _isSubmittingReply
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Reply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
