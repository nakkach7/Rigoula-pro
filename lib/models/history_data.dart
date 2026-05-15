class DayHistory {
  final String date;
  final double tempMax;
  final double tempMin;
  final double humMax;
  final double humMin;
  final double soilMax;
  final double soilMin;

  final int pumpCount;
  final int pumpDuration; 
  final int evCount;
  final int evDuration; 

  DayHistory({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humMax,
    required this.humMin,
    required this.soilMax,
    required this.soilMin,
    required this.pumpCount,
    required this.pumpDuration,
    required this.evCount,
    required this.evDuration,
  });

  factory DayHistory.fromMap(String date, Map<dynamic, dynamic> map) {
    return DayHistory(
      date:         date,
      tempMax:      (map['temp_max']  as num?)?.toDouble() ?? 0.0,
      tempMin:      (map['temp_min']  as num?)?.toDouble() ?? 0.0,
      humMax:       (map['hum_max']   as num?)?.toDouble() ?? 0.0,
      humMin:       (map['hum_min']   as num?)?.toDouble() ?? 0.0,
      soilMax:      (map['soil_max']  as num?)?.toDouble() ?? 0.0,
      soilMin:      (map['soil_min']  as num?)?.toDouble() ?? 0.0,
      pumpCount:    (map['pump_count'] as num?)?.toInt()
                    ?? (map['pompe_count'] as num?)?.toInt()
                    ?? 0,
      pumpDuration: (map['pump_duration'] as num?)?.toInt() ?? 0,
      evCount:      (map['ev_count']   as num?)?.toInt()
                    ?? (map['ev_open_count'] as num?)?.toInt()
                    ?? 0,
      evDuration:   (map['ev_duration'] as num?)?.toInt() ?? 0,
    );
  }
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m} min';
    return '${m} min ${s}s';
  }
}