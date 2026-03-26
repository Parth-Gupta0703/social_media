// lib/services/social_notification_service.dart
//
// Instagram-style social notifications — fully Spark-compatible, no Cloud Functions.
//
// How it works:
//   1. When a user does something (posts, likes, comments, replies),
//      their device writes a notification doc to Firestore:
//      notifications/{targetUserId}/items/{docId}
//   2. Every signed-in user's device listens to their OWN subcollection.
//   3. When a new doc appears, we show a local notification immediately.
//
// Collection used: notifications/{userId}/items/{itemId}
// Fields: type, fromUserId, fromEmail, postId, message, read, createdAt

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String _kChannelId = 'safespot_high_importance';
const String _kChannelName = 'SafeSpot Alerts';

class SocialNotificationService {
  SocialNotificationService._internal();
  static final SocialNotificationService instance =
      SocialNotificationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription? _subscription;

  // ── Listening ─────────────────────────────────────────────────────────────────

  /// Start listening for incoming notifications for the current user.
  /// Call from HomePage.initState() after confirming the user is signed in.
  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _subscription?.cancel();

    // isFirstSnapshot skips docs that already exist when the stream opens —
    // we only want to fire local notifications for NEW incoming docs.
    bool isFirstSnapshot = true;

    _subscription = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
          if (isFirstSnapshot) {
            isFirstSnapshot = false;
            return; // Skip existing unread docs on first load.
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;

            final data = change.doc.data();
            if (data == null) continue;
            if (data['fromUserId'] == uid) continue; // Never notify yourself.

            _showLocalNotification(
              id: change.doc.id.hashCode,
              title: _buildTitle(data),
              body: data['message'] ?? '',
            );

            debugPrint(
              '[SocialNotif] Received: ${data['type']} from ${data['fromEmail']}',
            );
          }
        });

    debugPrint('[SocialNotif] Listening for user $uid');
  }

  /// Stop listening — call on logout.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('[SocialNotif] Stopped.');
  }

  // ── Write notifications ───────────────────────────────────────────────────────
  // These are called by the ACTING user's device to notify the TARGET user.

  /// New post — notifies ALL other users in the Users collection.
  Future<void> notifyAllOnNewPost({
    required String postId,
    required String postPreview,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null) return;

    final usersSnapshot = await _firestore.collection('Users').get();
    if (usersSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final userDoc in usersSnapshot.docs) {
      if (userDoc.id == actor.uid) continue; // Don't notify yourself.

      final ref = _firestore
          .collection('notifications')
          .doc(userDoc.id)
          .collection('items')
          .doc();

      batch.set(ref, {
        'type': 'post',
        'fromUserId': actor.uid,
        'fromEmail': actor.email ?? 'Someone',
        'postId': postId,
        'message': postPreview.length > 60
            ? '${postPreview.substring(0, 60)}…'
            : postPreview,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint(
      '[SocialNotif] Post notifications sent to ${usersSnapshot.docs.length - 1} users.',
    );
  }

  /// Post liked — notifies the post owner.
  Future<void> notifyOnLike({
    required String postOwnerId,
    required String postId,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null || actor.uid == postOwnerId) return;

    await _write(
      targetUserId: postOwnerId,
      type: 'like',
      postId: postId,
      message: '${_name(actor.email)} liked your post.',
    );
  }

  /// Comment liked — notifies the comment owner.
  Future<void> notifyOnCommentLike({
    required String commentOwnerId,
    required String postId,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null || actor.uid == commentOwnerId) return;

    await _write(
      targetUserId: commentOwnerId,
      type: 'like',
      postId: postId,
      message: '${_name(actor.email)} liked your comment.',
    );
  }

  /// Comment added — notifies the post owner.
  Future<void> notifyOnComment({
    required String postOwnerId,
    required String postId,
    required String commentPreview,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null || actor.uid == postOwnerId) return;

    await _write(
      targetUserId: postOwnerId,
      type: 'comment',
      postId: postId,
      message: '${_name(actor.email)} commented: "$commentPreview"',
    );
  }

  /// Reply added — notifies the comment owner.
  Future<void> notifyOnReply({
    required String commentOwnerId,
    required String postId,
    required String replyPreview,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null || actor.uid == commentOwnerId) return;

    await _write(
      targetUserId: commentOwnerId,
      type: 'reply',
      postId: postId,
      message: '${_name(actor.email)} replied: "$replyPreview"',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Future<void> _write({
    required String targetUserId,
    required String type,
    required String postId,
    required String message,
  }) async {
    final actor = _auth.currentUser!;
    await _firestore
        .collection('notifications')
        .doc(targetUserId)
        .collection('items')
        .add({
          'type': type,
          'fromUserId': actor.uid,
          'fromEmail': actor.email ?? 'Someone',
          'postId': postId,
          'message': message,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  String _buildTitle(Map<String, dynamic> data) {
    final from = _name(data['fromEmail']);
    switch (data['type']) {
      case 'post':
        return '📢 New post from $from';
      case 'like':
        return '❤️ $from liked your post';
      case 'comment':
        return '💬 $from commented';
      case 'reply':
        return '↩️ $from replied to you';
      default:
        return 'SafeSpot';
    }
  }

  /// "john.doe@gmail.com" → "john.doe"
  String _name(String? email) => email?.split('@').first ?? 'Someone';
}
