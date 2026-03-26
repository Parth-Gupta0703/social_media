// lib/services/notification_service.dart
//
// Handles everything FCM-related on the device side:
//   • Requesting notification permissions (Android 13+ / iOS)
//   • Retrieving and saving the FCM device token to Firestore
//   • Creating the Android notification channel
//   • Showing local notifications when app is in foreground
//   • Handling notification taps from background and terminated states

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:social_media/main.dart'; // navigatorKey

// Must be a top-level function — FCM calls this in a separate isolate
// when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

const String _kChannelId = 'safespot_high_importance';
const String _kChannelName = 'SafeSpot Alerts';
const String _kChannelDesc = 'High-importance notifications for SafeSpot.';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // ── init ────────────────────────────────────────────────────────────────────
  // Call once from main.dart immediately after Firebase.initializeApp().

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestPermissions();
    await _initLocalNotifications();
    await _initFcmToken();
    _fcm.onTokenRefresh.listen(_onTokenRefresh);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped);
    await _handleTerminatedLaunch();
    debugPrint('[FCM] NotificationService ready.');
  }

  // ── Permissions ──────────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ── Local notifications ───────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Android 8+ needs an explicit channel — must match _kChannelId everywhere.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            description: _kChannelDesc,
            importance: Importance.high,
            enableLights: true,
            enableVibration: true,
            playSound: true,
          ),
        );
  }

  // ── Token ─────────────────────────────────────────────────────────────────────

  Future<void> _initFcmToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      debugPrint('[FCM] Token: $_fcmToken');
      await _saveToken(_fcmToken);
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  void _onTokenRefresh(String newToken) {
    _fcmToken = newToken;
    debugPrint('[FCM] Token refreshed: $newToken');
    _saveToken(newToken);
  }

  // Saves the token to the user's Firestore doc so other devices can target them.
  Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return; // Not signed in yet — skipped, refreshed after login.
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved to Firestore for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  // ── Message handlers ──────────────────────────────────────────────────────────

  // App is OPEN — FCM won't show a system notification automatically on Android,
  // so we display one manually using flutter_local_notifications.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _localNotifications.show(
      message.hashCode,
      n.title ?? 'SafeSpot',
      n.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
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
      payload: message.data['route'],
    );
  }

  // App is in BACKGROUND — user tapped the system notification.
  void _onNotificationTapped(RemoteMessage message) {
    debugPrint('[FCM] Background tap: ${message.messageId}');
    _navigateTo(message.data['route']);
  }

  // Foreground local notification tapped.
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] Local tap. Payload: ${response.payload}');
    _navigateTo(response.payload);
  }

  // App was TERMINATED — user tapped the notification to open the app.
  Future<void> _handleTerminatedLaunch() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      debugPrint('[FCM] Launched from terminated: ${message.messageId}');
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateTo(message.data['route']);
      });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void _navigateTo(String? route) {
    if (route == null || route.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Supports route format: 'post:<postId>'
    if (route.startsWith('post:')) {
      navigator.pushNamed('/post', arguments: route.substring(5));
    } else {
      navigator.pushNamed(route);
    }
  }
}
