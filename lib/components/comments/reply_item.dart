import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

// Single reply row in a comment thread.
class ReplyItem extends StatelessWidget {
  final Map<String, dynamic> replyData;
  final DocumentReference replyRef;
  final List<String> replyLikes;
  final bool isReplyLiked;
  final bool isReplyOwner;
  final void Function(DocumentReference, List<String>) onToggleLike;
  final VoidCallback? onDelete;

  const ReplyItem({
    super.key,
    required this.replyData,
    required this.replyRef,
    required this.replyLikes,
    required this.isReplyLiked,
    required this.isReplyOwner,
    required this.onToggleLike,
    required this.onDelete,
  });

  String _formatTime(dynamic timeValue) {
    if (timeValue is Timestamp) {
      return timeago.format(timeValue.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final replyEmail = (replyData['UserEmail'] as String?) ?? 'user';
    final replyText = (replyData['Text'] as String?) ?? '';
    final timeText = _formatTime(replyData['Time']);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0x1AFFB6C1),
            child: Text(
              replyEmail[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFB6C1),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyEmail.split('@')[0],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    replyText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3142),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (timeText.isNotEmpty) const SizedBox(width: 6),
                      InkWell(
                        onTap: () => onToggleLike(replyRef, replyLikes),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isReplyLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 12,
                                color: isReplyLiked
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.grey[600],
                              ),
                              if (replyLikes.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  replyLikes.length.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isReplyLiked
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (isReplyOwner && onDelete != null) ...[
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.delete_outline,
                                  size: 12,
                                  color: Color(0xFFFF6B6B),
                                ),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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
