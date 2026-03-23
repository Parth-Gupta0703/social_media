import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:social_media/main.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  Future<void> init() async {
    print("Notification service initialized");

    await requestPermission();
    await getToken();

    // 🔥 Foreground notification (app open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground notification received");
      print("Title: ${message.notification?.title}");
      print("Body: ${message.notification?.body}");
    });

    // 🔥 When user clicks notification (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("User clicked notification");

      String? postId = message.data['postId'];

      if (postId != null) {
        navigatorKey.currentState?.pushNamed('/post', arguments: postId);
      }
    });

    // 🔥 When app opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print("App opened from terminated state");

        String? postId = message.data['postId'];
        print("Open post: $postId");
      }
    });
  }

  // 🔐 Request permission
  Future<void> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission();

    print("Permission status: ${settings.authorizationStatus}");
  }

  // 📱 Get device token
  Future<void> getToken() async {
    String? token = await _fcm.getToken();

    if (token != null) {
      print("FCM Token: $token");
    } else {
      print("Failed to get FCM token");
    }
  }
}
