enum AlertType {
  tempHigh,   
  tempLow,    
  humHigh,    
  humLow,     
  soilHigh,   
  soilLow,    
  unknown,
}

class AlertPayload {
  final String serreId;
  final AlertType alertType;
  final String message;
  final int timestamp;
  const AlertPayload({
    required this.serreId,
    required this.alertType,
    required this.message,
    this.timestamp = 0,
  });

  int get pageIndex => serreId == 'tomate' ? 0 : 1;

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

  // FCM map 
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

  factory AlertPayload.fromLastAlert(String serreId, Map<dynamic, dynamic> data) {
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