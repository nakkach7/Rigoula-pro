import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/threshold_config.dart';

class VerificationDialog extends StatelessWidget {
  final SensorData sensorData;
  final ThresholdConfig thresholdConfig;

  const VerificationDialog({
    super.key,
    required this.sensorData,
    required this.thresholdConfig,
  });

  Widget _buildVerificationRow(
    String label,
    double value,
    double min,
    double max,
    String unit,
    bool isOk,
  ) {
    return Row(
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.cancel,
          color: isOk ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} $unit (limite: ${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)})',
                style: TextStyle(
                  fontSize: 12,
                  color: isOk ? Colors.grey.shade700 : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool tempOk = thresholdConfig.isTemperatureInRange(sensorData.temperature);
    final bool humOk = thresholdConfig.isHumidityInRange(sensorData.humidity);
    final bool allOk = tempOk && humOk;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            allOk ? Icons.check_circle : Icons.warning,
            color: allOk ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Text('Vérification'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerificationRow(
            'Température',
            sensorData.temperature,
            thresholdConfig.tempMin,
            thresholdConfig.tempMax,
            '°C',
            tempOk,
          ),
          const SizedBox(height: 12),
          _buildVerificationRow(
            'Humidité',
            sensorData.humidity,
            thresholdConfig.humMin,
            thresholdConfig.humMax,
            '%',
            humOk,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allOk ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  allOk ? Icons.check_circle : Icons.info,
                  color: allOk ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allOk
                        ? 'Toutes les valeurs sont normales'
                        : 'Certaines valeurs sont hors limites',
                    style: TextStyle(
                      color: allOk ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
