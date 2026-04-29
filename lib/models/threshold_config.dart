// lib/models/threshold_config.dart
// v2 — ajout solMin / solMax (manquants dans v1)

class ThresholdConfig {
  double tempMin;
  double tempMax;
  double humMin;
  double humMax;
  double solMin;   // ← NOUVEAU
  double solMax;   // ← NOUVEAU

  ThresholdConfig({
    this.tempMin = 18.0,
    this.tempMax = 30.0,
    this.humMin  = 40.0,
    this.humMax  = 80.0,
    this.solMin  = 30.0,
    this.solMax  = 70.0,
  });

  factory ThresholdConfig.fromMap(Map<String, double> m) => ThresholdConfig(
    tempMin: m['temp_min'] ?? 18.0,
    tempMax: m['temp_max'] ?? 30.0,
    humMin:  m['hum_min']  ?? 40.0,
    humMax:  m['hum_max']  ?? 80.0,
    solMin:  m['soil_min'] ?? 30.0,
    solMax:  m['soil_max'] ?? 70.0,
  );

  Map<String, double> toMap() => {
    'temp_min': tempMin,
    'temp_max': tempMax,
    'hum_min':  humMin,
    'hum_max':  humMax,
    'soil_min': solMin,
    'soil_max': solMax,
  };

  bool isTemperatureInRange(double v) => v >= tempMin && v <= tempMax;
  bool isHumidityInRange(double v)    => v >= humMin  && v <= humMax;
  bool isSoilInRange(double v)        => v >= solMin  && v <= solMax;

  bool areAllInRange(double temp, double hum, double soil) =>
      isTemperatureInRange(temp) &&
      isHumidityInRange(hum)    &&
      isSoilInRange(soil);
}