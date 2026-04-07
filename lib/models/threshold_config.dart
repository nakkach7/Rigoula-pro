class ThresholdConfig {
  double tempMin;
  double tempMax;
  double humMin;
  double humMax;

  ThresholdConfig({
    this.tempMin = 20.0,
    this.tempMax = 30.0,
    this.humMin = 30.0,
    this.humMax = 60.0,
  });

  bool isTemperatureInRange(double temperature) {
    return temperature >= tempMin && temperature <= tempMax;
  }

  bool isHumidityInRange(double humidity) {
    return humidity >= humMin && humidity <= humMax;
  }

  bool areValuesInRange(double temperature, double humidity) {
    return isTemperatureInRange(temperature) && isHumidityInRange(humidity);
  }
}