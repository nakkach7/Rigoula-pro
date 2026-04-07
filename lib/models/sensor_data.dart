class SensorData {
  final double temperature;
  final double humidity;
  final double soilPercent;
  final int soilRaw;
  final String time;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.soilPercent,
    required this.soilRaw,
    required this.time,
  });

  factory SensorData.fromMap(Map<String, dynamic> map) {
    return SensorData(
      temperature: map['temperature']?.toDouble() ?? 0.0,
      humidity: map['humidity']?.toDouble() ?? 0.0,
      soilPercent: map['soil_percent']?.toDouble() ?? 0.0,
      soilRaw: map['soil_raw']?.toInt() ?? 0,
      time: map['time']?.toString() ?? "--:--",
    );
  }

  factory SensorData.initial() {
    return SensorData(
      temperature: 0.0,
      humidity: 0.0,
      soilPercent: 0.0,
      soilRaw: 0,
      time: "--:--",
    );
  }

  @override
  String toString() {
    return 'Temp: ${temperature.toStringAsFixed(1)}°C, Hum: ${humidity.toStringAsFixed(1)}%, Sol: ${soilPercent.toStringAsFixed(1)}%, Heure: $time';
  }
}