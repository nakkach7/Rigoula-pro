// lib/models/alert_payload.dart
//
// Represents a decoded FCM notification payload.
// Passed around the app to drive navigation and UI highlighting.

/// The type of sensor anomaly reported by the backend.
enum AlertType {
  tempHigh,   // temperature above max
  tempLow,    // temperature below min
  humHigh,    // air humidity above max
  humLow,     // air humidity below min
  soilHigh,   // soil moisture above max
  soilLow,    // soil moisture below min
  unknown,
}

class AlertPayload {
  /// Firebase/serre key: "tomate" | "tomate_cerise"
  final String serreId;

  /// Decoded anomaly type
  final AlertType alertType;

  /// Human-readable message from backend
  final String message;

  /// Unix timestamp sent by backend (optional, 0 if missing)
  final int timestamp;

  const AlertPayload({
    required this.serreId,
    required this.alertType,
    required this.message,
    this.timestamp = 0,
  });

  // ─── PageView index for this serre ──────────────────────────────────────
  int get pageIndex => serreId == 'tomate' ? 0 : 1;

  // ─── Which sensor key is anomalous ──────────────────────────────────────
  /// Returns the field name that should be highlighted in the UI.
  String get affectedSensor {
    switch (alertType) {
      case AlertType.tempHigh:
      case AlertType.tempLow:
        return 'temperature';
      case AlertType.humHigh:
      case AlertType.humLow:
        return 'humidity';
      case AlertType.soilHigh:
      case AlertType.soilLow:
        return 'soil';
      case AlertType.unknown:
        return '';
    }
  }

  // ─── Parse FCM data map ─────────────────────────────────────────────────
  factory AlertPayload.fromFcmData(Map<String, dynamic> data) {
    final serreId = (data['serre'] as String?) ?? 'tomate';
    final typeStr = (data['type'] as String?) ?? '';
    final message = (data['message'] as String?) ?? 'Anomalie détectée';
    final timestamp = int.tryParse(data['timestamp']?.toString() ?? '0') ?? 0;

    return AlertPayload(
      serreId: serreId,
      alertType: _parseType(typeStr),
      message: message,
      timestamp: timestamp,
    );
  }

  // ─── Parse Firebase /last_alert map ─────────────────────────────────────
  factory AlertPayload.fromLastAlert(String serreId, Map<dynamic, dynamic> data) {
    // last_alert stores the raw alert list written by the Python backend.
    // We derive alertType from the first alert string heuristically.
    final alerts = data['alerts'];
    String firstAlert = '';
    if (alerts is List && alerts.isNotEmpty) {
      firstAlert = alerts.first.toString().toLowerCase();
    }

    final message = (data['message'] as String?) ?? firstAlert;

    return AlertPayload(
      serreId: serreId,
      alertType: _inferTypeFromText(firstAlert),
      message: message,
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  static AlertType _parseType(String raw) {
    switch (raw) {
      case 'temp_high':    return AlertType.tempHigh;
      case 'temp_low':     return AlertType.tempLow;
      case 'humidity_high':return AlertType.humHigh;
      case 'humidity_low': return AlertType.humLow;
      case 'soil_high':    return AlertType.soilHigh;
      case 'soil_low':     return AlertType.soilLow;
      default:             return AlertType.unknown;
    }
  }

  static AlertType _inferTypeFromText(String text) {
    if (text.contains('temp') && text.contains('élev')) return AlertType.tempHigh;
    if (text.contains('temp') && text.contains('basse')) return AlertType.tempLow;
    if (text.contains('humidité') && text.contains('élev')) return AlertType.humHigh;
    if (text.contains('humidité') && text.contains('basse')) return AlertType.humLow;
    if (text.contains('sol') && text.contains('humide')) return AlertType.soilHigh;
    if (text.contains('sol') && text.contains('sec')) return AlertType.soilLow;
    return AlertType.unknown;
  }

  // ─── UI helpers ─────────────────────────────────────────────────────────
  String get alertIcon {
    switch (alertType) {
      case AlertType.tempHigh:   return '🔥';
      case AlertType.tempLow:    return '🥶';
      case AlertType.humHigh:    return '💧';
      case AlertType.humLow:     return '💨';
      case AlertType.soilHigh:   return '🌊';
      case AlertType.soilLow:    return '🏜️';
      case AlertType.unknown:    return '⚠️';
    }
  }

  String get alertLabel {
    switch (alertType) {
      case AlertType.tempHigh:   return 'Température trop élevée';
      case AlertType.tempLow:    return 'Température trop basse';
      case AlertType.humHigh:    return 'Humidité trop élevée';
      case AlertType.humLow:     return 'Humidité trop basse';
      case AlertType.soilHigh:   return 'Sol trop humide';
      case AlertType.soilLow:    return 'Sol trop sec';
      case AlertType.unknown:    return 'Anomalie détectée';
    }
  }

  @override
  String toString() =>
      'AlertPayload(serre: $serreId, type: $alertType, msg: $message)';
}