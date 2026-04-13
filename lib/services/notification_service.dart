// notification_service.dart
// ✅ Plus besoin de flutter_local_notifications
// Les notifications sont gérées par Firebase FCM (backend Python)

import 'package:flutter/foundation.dart';

class NotificationService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ NotificationService initialisé (FCM only)');
  }

  // Ces méthodes sont gardées vides pour ne pas casser le code existant
  static Future<void> showTemperatureAlert({
    required double temperature,
    required double min,
    required double max,
  }) async {}

  static Future<void> showHumidityAlert({
    required double humidity,
    required double min,
    required double max,
  }) async {}

  static Future<void> showSoilMoistureAlert({
    required double moisture,
    required double min,
    required double max,
  }) async {}

  static Future<void> showMultipleAlertsNotification({
    required List<String> alerts,
  }) async {}

  static Future<void> showPumpNotification({
    required bool isPumpActive,
  }) async {}

  static Future<void> showConnectionLostNotification() async {}

  static Future<void> showConnectionRestoredNotification() async {}

  static Future<void> cancelAll() async {}

  static Future<void> testNotification() async {}

  static Future<void> showNotificationFromBackground({
    required String title,
    required String body,
  }) async {
    debugPrint('📬 Background notification: $title — $body');
  }
}