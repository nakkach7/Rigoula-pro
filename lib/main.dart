import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_router.dart';         
import 'models/alert_payload.dart';                


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 [BG ISOLATE] ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await FirebaseService.initialize();


  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('rigoula_alerts');
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await NotificationRouter.initialize();
  }

  runApp(MyApp(initialAlert: NotificationRouter.pendingPayload));
}

class MyApp extends StatelessWidget {
  final AlertPayload? initialAlert;

  const MyApp({super.key, this.initialAlert});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rigoula Farming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: SplashScreen(initialAlert: initialAlert),
    );
  }
}