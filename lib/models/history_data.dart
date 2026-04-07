class DayHistory {
  final String date;
  final double tempMax;
  final double tempMin;
  final double humMax;
  final double humMin;
  final double soilMax;
  final double soilMin;
  final int pompeCount;

  DayHistory({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humMax,
    required this.humMin,
    required this.soilMax,
    required this.soilMin,
    required this.pompeCount,
  });

  factory DayHistory.fromMap(String date, Map<dynamic, dynamic> map) {
    return DayHistory(
      date: date,
      tempMax: (map['temp_max'] as num?)?.toDouble() ?? 0.0,
      tempMin: (map['temp_min'] as num?)?.toDouble() ?? 0.0,
      humMax: (map['hum_max'] as num?)?.toDouble() ?? 0.0,
      humMin: (map['hum_min'] as num?)?.toDouble() ?? 0.0,
      soilMax: (map['soil_max'] as num?)?.toDouble() ?? 0.0,
      soilMin: (map['soil_min'] as num?)?.toDouble() ?? 0.0,
      pompeCount: (map['pompe_count'] as num?)?.toInt() ?? 0,
    );
  }
}