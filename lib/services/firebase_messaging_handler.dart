import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📬 Notification reçue en arrière-plan : ${message.notification?.title}");

  // On affiche la notification même si l'app est fermée
  await NotificationService.showNotificationFromBackground(
    title: message.notification?.title ?? "Alerte Rigoula",
    body: message.notification?.body ?? "",
  );
}