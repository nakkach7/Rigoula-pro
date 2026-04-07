import 'package:flutter/material.dart';
import '../models/threshold_config.dart';

class ThresholdConfigCard extends StatefulWidget {
  final ThresholdConfig thresholdConfig;
  final Function(ThresholdConfig) onConfigChanged;
  final VoidCallback onVerify;

  const ThresholdConfigCard({
    super.key,
    required this.thresholdConfig,
    required this.onConfigChanged,
    required this.onVerify,
  });

  @override
  State<ThresholdConfigCard> createState() => _ThresholdConfigCardState();
}

class _ThresholdConfigCardState extends State<ThresholdConfigCard> {
  late ThresholdConfig _config;

  @override
  void initState() {
    super.initState();
    _config = ThresholdConfig(
      tempMin: widget.thresholdConfig.tempMin,
      tempMax: widget.thresholdConfig.tempMax,
      humMin: widget.thresholdConfig.humMin,
      humMax: widget.thresholdConfig.humMax,
    );
  }

  Widget _buildThresholdInput(
    String label,
    double currentValue,
    Function(String) onChanged,
  ) {
    return Expanded(
      child: TextField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: currentValue.toStringAsFixed(1),
        ),
        onChanged: (value) {
          onChanged(value);
          widget.onConfigChanged(_config);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Configuration des seuils",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Temperature thresholds
            const Text(
              "Température (°C)",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThresholdInput(
                  "Min",
                  _config.tempMin,
                  (v) => setState(
                      () => _config.tempMin = double.tryParse(v) ?? _config.tempMin),
                ),
                const SizedBox(width: 12),
                _buildThresholdInput(
                  "Max",
                  _config.tempMax,
                  (v) => setState(
                      () => _config.tempMax = double.tryParse(v) ?? _config.tempMax),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Humidity thresholds
            const Text(
              "Humidité (%)",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThresholdInput(
                  "Min",
                  _config.humMin,
                  (v) => setState(
                      () => _config.humMin = double.tryParse(v) ?? _config.humMin),
                ),
                const SizedBox(width: 12),
                _buildThresholdInput(
                  "Max",
                  _config.humMax,
                  (v) => setState(
                      () => _config.humMax = double.tryParse(v) ?? _config.humMax),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Verify Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onVerify,
                icon: const Icon(Icons.verified),
                label: const Text(
                  'Vérifier les valeurs',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
