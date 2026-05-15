import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_payload.dart';

class NotificationRouter {
  NotificationRouter._(); 

  static final StreamController<AlertPayload> _controller =
      StreamController<AlertPayload>.broadcast();

  static Stream<AlertPayload> get onAlert => _controller.stream;

  static AlertPayload? pendingPayload;

  static Future<void> initialize() async {
    if (kIsWeb) return; 

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.containsKey('serre')) {
      pendingPayload = AlertPayload.fromFcmData(
        Map<String, dynamic>.from(initial.data),
      );
      debugPrint('📬 [TERMINATED] payload: ${pendingPayload}');
    }
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.containsKey('serre')) {
        final payload = AlertPayload.fromFcmData(
          Map<String, dynamic>.from(message.data),
        );
        debugPrint('📬 [BACKGROUND TAP] payload: $payload');
        _controller.add(payload);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (message.data.containsKey('serre')) {
        final payload = AlertPayload.fromFcmData(
          Map<String, dynamic>.from(message.data),
        );
        debugPrint('📬 [FOREGROUND] payload: $payload');
        _controller.add(payload);
      }
    });
  }

  static void dispose() {
    _controller.close();
  }
}