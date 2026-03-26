// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:social_media/auth/auth.dart';
import 'package:social_media/pages/post_page.dart';
import 'package:social_media/services/notification_service.dart';

import 'firebase_options.dart';

// Global navigator key — lets NotificationService navigate on notification tap
// from background/terminated state without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1 — Firebase must be first, everything depends on it.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Step 2 — Set up FCM: request permissions, get device token, create
  // Android notification channel, register background handler.
  // NOTE: SocialNotificationService.startListening() is intentionally NOT
  // called here — it needs a signed-in user, so it runs in HomePage.initState().
  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeSpot',
      navigatorKey: navigatorKey,
      routes: {'/post': (context) => PostPage()},
      home: const Auth(),
    );
  }
}
