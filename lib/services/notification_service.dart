import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static DateTime? _lastNotificationTime;
  static const int _minNotificationInterval = 60;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _isInitialized = true;
      debugPrint('✅ Notifications initialisées');
      await _requestPermissions();
    } catch (e) {
      debugPrint('❌ Erreur initialisation notifications: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('📱 Notification cliquée: ${response.payload}');
  }

  static bool _canSendNotification() {
    if (_lastNotificationTime == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_lastNotificationTime!).inSeconds;
    return difference >= _minNotificationInterval;
  }

  static Future<void> showTemperatureAlert({
    required double temperature,
    required double min,
    required double max,
  }) async {
    if (!_isInitialized || !_canSendNotification()) return;

    String message;
    if (temperature < min) {
      message = '🥶 Température trop basse: ${temperature.toStringAsFixed(1)}°C';
    } else {
      message = '🔥 Température trop élevée: ${temperature.toStringAsFixed(1)}°C';
    }

    await _showNotification(
      id: 1,
      title: '⚠️ Alerte Température',
      body: message,
      color: temperature < min ? 0xFF2196F3 : 0xFFFF5722,
    );
  }

  static Future<void> showHumidityAlert({
    required double humidity,
    required double min,
    required double max,
  }) async {
    if (!_isInitialized || !_canSendNotification()) return;

    String message;
    if (humidity < min) {
      message = '💨 Humidité trop basse: ${humidity.toStringAsFixed(1)}%';
    } else {
      message = '💧 Humidité trop élevée: ${humidity.toStringAsFixed(1)}%';
    }

    await _showNotification(
      id: 2,
      title: '⚠️ Alerte Humidité',
      body: message,
      color: 0xFF03A9F4,
    );
  }

  static Future<void> showSoilMoistureAlert({
    required double moisture,
    required double min,
    required double max,
  }) async {
    if (!_isInitialized || !_canSendNotification()) return;

    String message;
    String emoji;

    if (moisture < min) {
      message = 'Sol trop sec: ${moisture.toStringAsFixed(1)}%';
      emoji = '🏜️';
    } else {
      message = 'Sol trop humide: ${moisture.toStringAsFixed(1)}%';
      emoji = '🌊';
    }

    await _showNotification(
      id: 3,
      title: '$emoji Alerte Humidité du Sol',
      body: message,
      color: 0xFF795548,
    );
  }

  static Future<void> showMultipleAlertsNotification({
    required List<String> alerts,
  }) async {
    if (!_isInitialized || !_canSendNotification() || alerts.isEmpty) return;

    await _showNotification(
      id: 0,
      title: '⚠️ Alertes Multiples (${alerts.length})',
      body: alerts.join('\n'),
      color: 0xFFF44336,
    );
  }

  static Future<void> showPumpNotification({
    required bool isPumpActive,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: 4,
      title: isPumpActive ? '💧 Pompe Activée' : '⛔ Pompe Désactivée',
      body: isPumpActive
          ? 'La pompe d\'irrigation a été activée'
          : 'La pompe d\'irrigation a été désactivée',
      color: isPumpActive ? 0xFF4CAF50 : 0xFF9E9E9E,
    );
  }

  static Future<void> showConnectionLostNotification() async {
    if (!_isInitialized) return;

    await _showNotification(
      id: 5,
      title: '📡 Connexion Perdue',
      body: 'La connexion au capteur a été perdue',
      color: 0xFFFF9800,
    );
  }

  static Future<void> showConnectionRestoredNotification() async {
    if (!_isInitialized) return;

    await _showNotification(
      id: 6,
      title: '✅ Connexion Rétablie',
      body: 'La connexion au capteur a été rétablie',
      color: 0xFF4CAF50,
    );
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required int color,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'sensor_alerts',
        'Alertes Capteurs',
        channelDescription: 'Notifications pour les alertes des capteurs',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(color),
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: 'sensor_alert_$id',
      );

      _lastNotificationTime = DateTime.now();
      debugPrint('📱 Notification envoyée: $title');
    } catch (e) {
      debugPrint('❌ Erreur envoi notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ Toutes les notifications annulées');
  }

  static Future<void> testNotification() async {
    if (!_isInitialized) return;
    await _showNotification(
      id: 999,
      title: '🧪 Test',
      body: 'Les notifications fonctionnent!',
      color: 0xFF9C27B0,
    );
  }
    // === NOUVEAU : Méthode pour les notifications en arrière-plan ===
  static Future<void> showNotificationFromBackground({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sensor_alerts',
      'Alertes Capteurs',
      channelDescription: 'Notifications pour les alertes des capteurs',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(999, title, body, details);
  }
}