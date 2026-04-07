import 'package:flutter/material.dart';
import 'dart:math';
import '../models/sensor_data.dart';
import '../models/soil_sensor_data.dart';
import '../models/threshold_config.dart';

class VegetableSlider extends StatefulWidget {
  final SensorData sensorData;
  final SoilSensorData soilData;
  final ThresholdConfig thresholdConfig;
  final VoidCallback onPumpToggle;
  final bool isAutoMode;
  final Function(int)? onPageChanged;
  final PageController? externalController;

  const VegetableSlider({
    super.key,
    required this.sensorData,
    required this.soilData,
    required this.thresholdConfig,
    required this.onPumpToggle,
    this.isAutoMode = true,
    this.onPageChanged,
    this.externalController,
  });

  @override
  State<VegetableSlider> createState() => _VegetableSliderState();
}

class _VegetableSliderState extends State<VegetableSlider> {
  late final PageController _pageController;
  int _currentPage = 0;

  final List<VegetableData> vegetables = [
    VegetableData(name: "Tomate", emoji: "🍅", color: const Color(0xFFE74C3C)),
    VegetableData(name: "Aubergine", emoji: "🍆", color: const Color(0xFF9B59B6)),
    VegetableData(name: "Poivron", emoji: "🫑", color: const Color(0xFF27AE60)),
    VegetableData(name: "Concombre", emoji: "🥒", color: const Color(0xFF2ECC71)),
  ];

  Color _getValueColor(double value, double min, double max) {
    if (value < min || value > max) return Colors.red;
    return Colors.green.shade700;
  }

  @override
  void initState() {
    super.initState();
    _pageController = widget.externalController ?? PageController();
  }

  @override
  void dispose() {
    if (widget.externalController == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Header ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                      image: const DecorationImage(
                        image: AssetImage('assets/rigoula.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Surveillance",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_currentPage + 1}/${vegetables.length}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── PageView — prend tout l'espace disponible ───
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: vegetables.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) {
              final isRealData = index == 0;
              return _buildVegetableCard(vegetables[index], isRealData);
            },
          ),
        ),

        // ─── Indicateurs de page ───
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              vegetables.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? vegetables[index].color
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVegetableCard(VegetableData veg, bool isRealData) {
    // ─── Card qui remplit toute la hauteur disponible ───
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                veg.color.withOpacity(0.08),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── En-tête légume ───
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: veg.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          veg.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            veg.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: veg.color,
                            ),
                          ),
                          const Text(
                            "Rigoula",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRealData
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isRealData ? "RÉEL" : "SIMU",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isRealData
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Capteurs ───
                _buildSensorRow(
                  icon: Icons.thermostat,
                  color: Colors.orange,
                  label: "Température",
                  value: isRealData
                      ? widget.sensorData.temperature
                      : 20.0 + Random().nextDouble() * 10,
                  unit: "°C",
                  min: widget.thresholdConfig.tempMin,
                  max: widget.thresholdConfig.tempMax,
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  label: "Humidité air",
                  value: isRealData
                      ? widget.sensorData.humidity
                      : 50.0 + Random().nextDouble() * 30,
                  unit: "%",
                  min: widget.thresholdConfig.humMin,
                  max: widget.thresholdConfig.humMax,
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  icon: Icons.grass,
                  color: Colors.brown,
                  label: "Humidité sol",
                  value: isRealData
                      ? widget.sensorData.soilPercent
                      : 30.0 + Random().nextDouble() * 40,
                  unit: "%",
                  min: 30.0,
                  max: 70.0,
                ),

                // ─── Bouton pompe (slide 1 seulement) ───
                if (isRealData) ...[
                  const SizedBox(height: 14),
                  _buildPumpButton(
                    widget.soilData.isPumpActive,
                    widget.onPumpToggle,
                    widget.isAutoMode,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          widget.sensorData.time,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.soilData.isPumpActive
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.water,
                              size: 10,
                              color: widget.soilData.isPumpActive
                                  ? Colors.green
                                  : Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            widget.soilData.isPumpActive ? "ON" : "OFF",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.soilData.isPumpActive
                                  ? Colors.green
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  if (widget.sensorData.soilRaw > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Icon(Icons.sensors,
                            size: 10, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(
                          "Brut: ${widget.sensorData.soilRaw}",
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorRow({
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
  }) {
    final statusColor = _getValueColor(value, min, max);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Row(children: [
                Flexible(
                  child: Text(
                    "${value.toStringAsFixed(1)}$unit",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 9, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildPumpButton(
      bool isActive, VoidCallback onTap, bool isAutoMode) {
    final isDisabled = isAutoMode;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDisabled
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : isActive
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.green.shade400, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (isDisabled
                        ? Colors.grey
                        : isActive
                            ? Colors.red
                            : Colors.green)
                    .withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDisabled
                    ? Icons.smart_toy
                    : isActive
                        ? Icons.power_settings_new
                        : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isDisabled
                    ? "GÉRÉ AUTOMATIQUEMENT"
                    : isActive
                        ? "POMPE ACTIVE"
                        : "DÉMARRER",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VegetableData {
  final String name;
  final String emoji;
  final Color color;

  const VegetableData({
    required this.name,
    required this.emoji,
    required this.color,
  });
}