import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/soil_sensor_data.dart';
import '../models/threshold_config.dart';

class CompleteSensorSlide extends StatelessWidget {
  final SensorData sensorData;
  final SoilSensorData soilData;
  final ThresholdConfig thresholdConfig;
  final VoidCallback onPumpToggle;

  const CompleteSensorSlide({
    super.key,
    required this.sensorData,
    required this.soilData,
    required this.thresholdConfig,
    required this.onPumpToggle,
  });

  Color _getValueColor(double value, double min, double max) {
    return (value < min || value > max) ? Colors.red : Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titre
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.dashboard, color: Colors.blue, size: 36),
                      const SizedBox(width: 12),
                      const Text(
                        "Tableau de bord",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Température et Humidité
                  Row(
                    children: [
                      // Température
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.thermostat,
                                  size: 48, color: Colors.orange.shade700),
                              const SizedBox(height: 10),
                              const Text(
                                "Température",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${sensorData.temperature.toStringAsFixed(1)}°C",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _getValueColor(
                                    sensorData.temperature,
                                    thresholdConfig.tempMin,
                                    thresholdConfig.tempMax,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Humidité
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.water_drop,
                                  size: 48, color: Colors.blue.shade700),
                              const SizedBox(height: 10),
                              const Text(
                                "Humidité",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${sensorData.humidity.toStringAsFixed(1)}%",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _getValueColor(
                                    sensorData.humidity,
                                    thresholdConfig.humMin,
                                    thresholdConfig.humMax,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Capteur de sol
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.brown.shade200,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grass,
                            size: 48, color: Colors.brown.shade700),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Humidité du sol",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${soilData.moisture.toStringAsFixed(1)}%",
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _getValueColor(
                                    soilData.moisture,
                                    30.0,
                                    70.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Indicateur visuel
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Colors.brown.shade300,
                              width: 3,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 80,
                                height: 80 * (soilData.moisture / 100),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade400,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(37),
                                    bottomRight: Radius.circular(37),
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  "${soilData.moisture.toInt()}%",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: soilData.moisture > 50
                                        ? Colors.white
                                        : Colors.brown.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton pompe
                  Container(
                    width: double.infinity,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: soilData.isPumpActive
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          // ✅ withValues() remplace withOpacity() (deprecated)
                          color: (soilData.isPumpActive
                                  ? Colors.red
                                  : Colors.green)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPumpToggle,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                soilData.isPumpActive
                                    ? Icons.power_settings_new
                                    : Icons.water_drop,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                soilData.isPumpActive
                                    ? "ARRÊTER LA POMPE"
                                    : "DÉMARRER LA POMPE",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
