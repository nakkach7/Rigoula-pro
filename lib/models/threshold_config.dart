class ThresholdConfig {
  double tempMin;
  double tempMax;
  double humMin;
  double humMax;
  double solMin;
  double solMax;

  ThresholdConfig({
    this.tempMin = 15.0,
    this.tempMax = 35.0,
    this.humMin  = 30.0,
    this.humMax  = 80.0,
    this.solMin  = 30.0,
    this.solMax  = 70.0,
  });

  factory ThresholdConfig.fromMap(Map<String, double> map) {
    return ThresholdConfig(
      tempMin: map['temp_min'] ?? 15.0,
      tempMax: map['temp_max'] ?? 35.0,
      humMin:  map['hum_min']  ?? 30.0,
      humMax:  map['hum_max']  ?? 80.0,
      solMin:  map['soil_min'] ?? 30.0,
      solMax:  map['soil_max'] ?? 70.0,
    );
  }

  bool isTemperatureInRange(double value) => value >= tempMin && value <= tempMax;
  bool isHumidityInRange(double value)    => value >= humMin  && value <= humMax;
  bool isSoilInRange(double value)        => value >= solMin  && value <= solMax;
}