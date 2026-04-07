import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_page.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_messaging_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

 

  // Gestion des notifications en arrière-plan
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();
  await FirebaseService.initialize();

  // ✅ CORRECTION : S'abonner au topic FCM pour recevoir les alertes du backend Python
  await FirebaseMessaging.instance.subscribeToTopic('rigoula_alerts');
  debugPrint('✅ Abonné au topic FCM: rigoula_alerts');

  // ✅ Demander la permission de notifications (Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rigoula Farme',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}