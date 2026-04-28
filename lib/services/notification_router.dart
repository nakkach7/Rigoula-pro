// lib/services/notification_router.dart
//
// Central service that:
//  1. Wires up all three FCM states (foreground / background-tap / terminated-tap)
//  2. Exposes a Stream<AlertPayload> that the UI listens to
//  3. Stores the "pending" payload so HomePage can read it after first build
//
// IMPORTANT: Call NotificationRouter.initialize() from main() BEFORE runApp().

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_payload.dart';

class NotificationRouter {
  NotificationRouter._(); // singleton — no instances

  // Stream that HomePage subscribes to for real-time taps
  static final StreamController<AlertPayload> _controller =
      StreamController<AlertPayload>.broadcast();

  static Stream<AlertPayload> get onAlert => _controller.stream;

  // Stores a payload that arrived before the widget tree was ready
  // (terminated state). HomePage reads this in initState.
  static AlertPayload? pendingPayload;

  // ─── Call once from main() after Firebase.initializeApp() ────────────────
  static Future<void> initialize() async {
    if (kIsWeb) return; // FCM not supported on web

    // ── 1. TERMINATED STATE ─────────────────────────────────────────────────
    // getInitialMessage() returns the notification that launched the app.
    // It is only non-null when the app was fully closed.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.containsKey('serre')) {
      pendingPayload = AlertPayload.fromFcmData(
        Map<String, dynamic>.from(initial.data),
      );
      debugPrint('📬 [TERMINATED] payload: ${pendingPayload}');
    }

    // ── 2. BACKGROUND TAP ───────────────────────────────────────────────────
    // onMessageOpenedApp fires when the user taps a notification while the
    // app is in the background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.containsKey('serre')) {
        final payload = AlertPayload.fromFcmData(
          Map<String, dynamic>.from(message.data),
        );
        debugPrint('📬 [BACKGROUND TAP] payload: $payload');
        _controller.add(payload);
      }
    });

    // ── 3. FOREGROUND ───────────────────────────────────────────────────────
    // onMessage fires when a notification arrives while the app is open.
    // FCM does NOT show a system banner in foreground on Android by default,
    // so we push the payload to the stream and let the UI show an in-app
    // banner (AlertBanner / SnackBar).
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