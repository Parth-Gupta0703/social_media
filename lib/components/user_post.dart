import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'comments/comments_sheet.dart';

class UserPost extends StatefulWidget {
  final QueryDocumentSnapshot post;
  const UserPost({super.key, required this.post});

  @override
  State<UserPost> createState() => _UserPostState();
}

class _UserPostState extends State<UserPost> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;
  late AnimationController _likeController;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void toggleLike() {
    final likes = List<String>.from(widget.post['Likes']);
    final postRef = widget.post.reference;

    if (likes.contains(user.uid)) {
      postRef.update({'Likes': FieldValue.arrayRemove([user.uid])});
    } else {
      postRef.update({'Likes': FieldValue.arrayUnion([user.uid])});
      _likeController.forward().then((_) => _likeController.reverse());
      
      _showHeartParticles();
    }
  }
  
  void _showHeartParticles() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (context.mounted) Navigator.of(context).pop();
        });
        
        return Center(
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1000),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, -100 * value),
                child: Opacity(
                  opacity: 1 - value,
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF6B6B),
                    size: 60,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void deletePost(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.post.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Post deleted'),
                    ],
                  ),
                  backgroundColor: const Color(0xFFFF6B6B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: widget.post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(widget.post['Likes']);
    final isLiked = likes.contains(user.uid);
    final userEmail = widget.post['UserEmail'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB6C1), Color(0xFFFFDAB9)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0x1AFFB6C1),
                        child: Text(
                          userEmail[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB6C1),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userEmail.split('@')[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(widget.post['TimeStamp'].toDate()),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.post['UserId'] == user.uid)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0x1AFF6B6B),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFFF6B6B),
                          size: 20,
                        ),
                        onPressed: () => deletePost(context),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),


              Text(
                widget.post['Message'],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF2D3142),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                height: 1,
                color: Colors.grey[200],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  InkWell(
                    onTap: toggleLike,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isLiked
                            ? const Color(0x1AFF6B6B) 
                            : Colors.grey[100],
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                              CurvedAnimation(
                                parent: _likeController,
                                curve: Curves.elasticOut,
                              ),
                            ),
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          if (likes.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              likes.length.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isLiked
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  InkWell(
                    onTap: () => showComments(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFB6C1), 
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            color: const Color(0xFFFFB6C1),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('User Posts')
                                .doc(widget.post.id)
                                .collection('Comments')
                                .snapshots(),
                            builder: (context, snapshot) {
                              int count = snapshot.hasData
                                  ? snapshot.data!.docs.length
                                  : 0;
                              if (count == 0) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                count.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFB6C1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
