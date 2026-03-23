import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'reply_item.dart';

class CommentItem extends StatelessWidget {
  final DocumentReference commentRef;
  final Map<String, dynamic> commentData;
  final List<String> commentLikes;
  final bool isCommentLiked;
  final bool isCommentOwner;
  final String currentUserId;
  final bool Function(Map<String, dynamic>) isOwner;
  final void Function(DocumentReference, List<String>) onToggleLike;
  final VoidCallback onReply;
  final VoidCallback? onDeleteComment;
  final void Function(DocumentReference) onDeleteReply;

  const CommentItem({
    super.key,
    required this.commentRef,
    required this.commentData,
    required this.commentLikes,
    required this.isCommentLiked,
    required this.isCommentOwner,
    required this.currentUserId,
    required this.isOwner,
    required this.onToggleLike,
    required this.onReply,
    required this.onDeleteComment,
    required this.onDeleteReply,
  });

  String _formatTime(dynamic timeValue) {
    if (timeValue is Timestamp) {
      return timeago.format(timeValue.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final commentEmail = (commentData['UserEmail'] as String?) ?? 'user';
    final commentText = (commentData['Text'] as String?) ?? '';
    final timeText = _formatTime(commentData['Time']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0x1AFFB6C1),
            child: Text(
              commentEmail[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFB6C1),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          commentEmail.split('@')[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                      ),
                      if (isCommentOwner && onDeleteComment != null)
                        IconButton(
                          onPressed: onDeleteComment,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFFF6B6B),
                          ),
                          splashRadius: 18,
                          tooltip: 'Delete comment',
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    commentText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2D3142),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (timeText.isNotEmpty) ...[
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      InkWell(
                        onTap: () => onToggleLike(commentRef, commentLikes),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCommentLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: isCommentLiked
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.grey[600],
                              ),
                              if (commentLikes.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  commentLikes.length.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isCommentLiked
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.reply,
                                size: 14,
                                color: Color(0xFFFFB6C1),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFB6C1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Delete is shown in the header (username row).
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Replies for this comment.
                  StreamBuilder(
                    stream: commentRef
                        .collection('Replies')
                        .orderBy('Time', descending: false)
                        .snapshots(),
                    builder: (context, replySnap) {
                      if (!replySnap.hasData || replySnap.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: replySnap.data!.docs.map((r) {
                          final replyData = r.data();
                          final replyLikes = List<String>.from(
                            replyData['Likes'] ?? [],
                          );
                          final isReplyLiked = replyLikes.contains(
                            currentUserId,
                          );
                          final isReplyOwner = isOwner(replyData);

                          return ReplyItem(
                            replyData: replyData,
                            replyRef: r.reference,
                            replyLikes: replyLikes,
                            isReplyLiked: isReplyLiked,
                            isReplyOwner: isReplyOwner,
                            onToggleLike: onToggleLike,
                            onDelete: isReplyOwner
                                ? () => onDeleteReply(r.reference)
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
