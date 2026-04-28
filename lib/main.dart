// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/notification_router.dart';         // ← NEW
import 'services/firebase_messaging_handler.dart';
import 'models/alert_payload.dart';                 // ← NEW

// ─── Background handler (must be top-level) ──────────────────────────────────
// Registered before runApp so the isolate can find it when the app is killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the OS in the background isolate.
  // We only need to log here; the system tray notification is shown automatically.
  debugPrint('📬 [BG ISOLATE] ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Register background handler BEFORE Firebase.initializeApp ────────────
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ── Firebase & notification setup ─────────────────────────────────────────
  await FirebaseService.initialize();
  await NotificationService.initialize();

  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('rigoula_alerts');
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── NotificationRouter MUST be called after Firebase init ────────────
    // It calls getInitialMessage() internally and stores pendingPayload.
    await NotificationRouter.initialize();
  }

  runApp(MyApp(initialAlert: NotificationRouter.pendingPayload));
}

// ─── Root widget ──────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  /// Non-null when the app was launched by tapping a terminated-state notification.
  final AlertPayload? initialAlert;

  const MyApp({super.key, this.initialAlert});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rigoula Farming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // Pass the payload through SplashScreen so HomePage receives it
      // after the splash animation completes.
      home: SplashScreen(initialAlert: initialAlert),
    );
  }
}