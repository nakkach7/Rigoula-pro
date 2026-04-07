class SoilSensorData {
  final double moisture; // Humidité du sol en %
  final bool isPumpActive;

  SoilSensorData({
    required this.moisture,
    required this.isPumpActive,
  });

  factory SoilSensorData.initial() {
    return SoilSensorData(
      moisture: 0.0,
      isPumpActive: false,
    );
  }

  bool isMoistureInRange(double min, double max) {
    return moisture >= min && moisture <= max;
  }

  @override
  String toString() {
    return 'Moisture: ${moisture}%, Pump: ${isPumpActive ? "ON" : "OFF"}';
  }
}
