// firebase_messaging_handler.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Notification reçue en arrière-plan : ${message.notification?.title}');
  // FCM affiche automatiquement la notification — rien à faire ici
}