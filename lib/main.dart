import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart'; 
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_messaging_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // notifications en arrière-plan (mobile)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await FirebaseService.initialize();
  await NotificationService.initialize();

  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('rigoula_alerts');
    debugPrint('✅ Abonné au topic FCM: rigoula_alerts');

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      
      title: 'Rigoula Farme',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const SplashScreen(), // ✅ Démarre avec le splash screen
    );
  }
}