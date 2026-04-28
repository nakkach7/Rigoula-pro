// lib/widgets/vegetable_slider.dart
//
// Changes from previous version:
//  • Accepts activeAlert (AlertPayload?) — when non-null and matches this
//    serre, shows AnomalyBanner and highlights the affected sensor row in red.
//  • _buildSensorRow gains an `isHighlighted` flag that adds a red pulsing
//    border and red background tint.
//  • Each card uses a ScrollController so we can auto-scroll to the
//    highlighted sensor after the frame renders.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/sensor_data.dart';
import '../models/soil_sensor_data.dart';
import '../models/threshold_config.dart';
import '../models/alert_payload.dart';     // ← NEW
import 'anomaly_banner.dart';              // ← NEW

// ─── Serre descriptor ────────────────────────────────────────────────────────
class SerreData {
  final String name;
  final String emoji;
  final Color color;
  final String serreId;

  const SerreData({
    required this.name,
    required this.emoji,
    required this.color,
    required this.serreId,
  });
}

// ─── Widget ──────────────────────────────────────────────────────────────────
class VegetableSlider extends StatefulWidget {
  final Map<String, SensorData> sensorDataMap;
  final Map<String, SoilSensorData> soilDataMap;
  final Map<String, ThresholdConfig> thresholdConfigMap;
  final Map<String, bool> autoModeMap;
  final Map<String, bool> pumpLoadingMap;

  final void Function(String serreId) onPumpToggle;
  final void Function(String serreId) onModeToggle;
  final void Function(String serreId) onOpenSettings;
  final void Function(String serreId) onOpenHistorique;

  final Function(int)? onPageChanged;
  final PageController? externalController;

  /// When non-null, the matching serre card shows the anomaly banner and
  /// highlights the affected sensor row.
  final AlertPayload? activeAlert; // NEW

  /// Called when the user dismisses the banner.
  final VoidCallback? onAlertDismissed; // NEW

  const VegetableSlider({
    super.key,
    required this.sensorDataMap,
    required this.soilDataMap,
    required this.thresholdConfigMap,
    required this.autoModeMap,
    required this.pumpLoadingMap,
    required this.onPumpToggle,
    required this.onModeToggle,
    required this.onOpenSettings,
    required this.onOpenHistorique,
    this.onPageChanged,
    this.externalController,
    this.activeAlert,
    this.onAlertDismissed,
  });

  @override
  State<VegetableSlider> createState() => _VegetableSliderState();
}

class _VegetableSliderState extends State<VegetableSlider> {
  late final PageController _pageController;
  int _currentPage = 0;

  // One ScrollController per serre card for auto-scroll
  final Map<String, ScrollController> _scrollControllers = {};

  // GlobalKeys for each sensor section — used to compute scroll offset
  final Map<String, GlobalKey> _tempKeys = {};
  final Map<String, GlobalKey> _humKeys = {};
  final Map<String, GlobalKey> _soilKeys = {};

  static const List<SerreData> serres = [
    SerreData(name: "Tomate",       emoji: "🍅", color: Color(0xFFE74C3C), serreId: "tomate"),
    SerreData(name: "Tomate Cerise",emoji: "🍒", color: Color(0xFFC0392B), serreId: "tomate_cerise"),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = widget.externalController ?? PageController();
    for (final s in serres) {
      _scrollControllers[s.serreId] = ScrollController();
      _tempKeys[s.serreId] = GlobalKey();
      _humKeys[s.serreId] = GlobalKey();
      _soilKeys[s.serreId] = GlobalKey();
    }
    // If an alert is already set at build time (terminated state), jump to it
    if (widget.activeAlert != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _jumpToAlertSerre(widget.activeAlert!);
      });
    }
  }

  // When activeAlert changes (background tap / foreground), jump to serre
  @override
  void didUpdateWidget(VegetableSlider old) {
    super.didUpdateWidget(old);
    final alert = widget.activeAlert;
    if (alert != null && alert != old.activeAlert) {
      _jumpToAlertSerre(alert);
    }
  }

  void _jumpToAlertSerre(AlertPayload alert) {
    // 1. Animate PageView to the correct serre
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        alert.pageIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    // 2. After page animation completes, scroll to the highlighted sensor
    Future.delayed(const Duration(milliseconds: 650), () {
      _scrollToHighlightedSensor(alert);
    });
  }

  void _scrollToHighlightedSensor(AlertPayload alert) {
    final scrollCtrl = _scrollControllers[alert.serreId];
    if (scrollCtrl == null || !scrollCtrl.hasClients) return;

    GlobalKey? targetKey;
    switch (alert.affectedSensor) {
      case 'temperature':
        targetKey = _tempKeys[alert.serreId];
        break;
      case 'humidity':
        targetKey = _humKeys[alert.serreId];
        break;
      case 'soil':
        targetKey = _soilKeys[alert.serreId];
        break;
    }

    if (targetKey?.currentContext == null) return;
    final box = targetKey!.currentContext!.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero).dy;
    final targetScroll = scrollCtrl.offset + offset - 160;
    scrollCtrl.animateTo(
      targetScroll.clamp(0.0, scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    if (widget.externalController == null) _pageController.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color _getValueColor(double value, double min, double max) =>
      (value < min || value > max) ? Colors.red : Colors.green.shade700;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Surveillance des serres",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_currentPage + 1}/${serres.length}",
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

        // PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: serres.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) {
              return _buildSerreCard(serres[index]);
            },
          ),
        ),

        // Page dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              serres.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? serres[index].color
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

  // ─── Serre card ──────────────────────────────────────────────────────────
  Widget _buildSerreCard(SerreData serre) {
    final sensor = widget.sensorDataMap[serre.serreId] ?? SensorData.initial();
    final soil = widget.soilDataMap[serre.serreId] ?? SoilSensorData.initial();
    final config = widget.thresholdConfigMap[serre.serreId] ?? ThresholdConfig();
    final isAuto = widget.autoModeMap[serre.serreId] ?? true;
    final pumpLoading = widget.pumpLoadingMap[serre.serreId] ?? false;

    final alert = widget.activeAlert;
    final hasAlert = alert != null && alert.serreId == serre.serreId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: hasAlert ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: hasAlert
              ? BorderSide(color: Colors.red.shade400, width: 2)
              : BorderSide.none,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [serre.color.withOpacity(0.08), Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            controller: _scrollControllers[serre.serreId],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: serre.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(serre.emoji,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(serre.name,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: serre.color)),
                          const Text("Rigoula · Serre indépendante",
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.history, color: serre.color, size: 20),
                      tooltip: 'Historique ${serre.name}',
                      onPressed: () => widget.onOpenHistorique(serre.serreId),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: serre.color, size: 20),
                      tooltip: 'Paramètres ${serre.name}',
                      onPressed: () => widget.onOpenSettings(serre.serreId),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ANOMALY BANNER — only for this serre's alert
                if (hasAlert)
                  AnomalyBanner(
                    key: ValueKey('banner_${alert.serreId}_${alert.timestamp}'),
                    payload: alert!,
                    onDismiss: () => widget.onAlertDismissed?.call(),
                  ),

                // Mode banner
                GestureDetector(
                  onTap: () => widget.onModeToggle(serre.serreId),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: serre.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: serre.color.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAuto ? Icons.smart_toy : Icons.pan_tool,
                          color: serre.color,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isAuto
                                ? 'AUTO — ESP32 gère la pompe'
                                : 'MANUEL — Vous contrôlez la pompe',
                            style: TextStyle(
                                fontSize: 11,
                                color: serre.color,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: !isAuto,
                            onChanged: (_) =>
                                widget.onModeToggle(serre.serreId),
                            activeColor: Colors.orange,
                            inactiveThumbColor: serre.color,
                            inactiveTrackColor:
                                serre.color.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Sensor rows
                _buildSensorRow(
                  rowKey: _tempKeys[serre.serreId]!,
                  icon: Icons.thermostat,
                  color: Colors.orange,
                  label: "Température",
                  value: sensor.temperature,
                  unit: "°C",
                  min: config.tempMin,
                  max: config.tempMax,
                  isHighlighted:
                      hasAlert && alert!.affectedSensor == 'temperature',
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  rowKey: _humKeys[serre.serreId]!,
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  label: "Humidité air",
                  value: sensor.humidity,
                  unit: "%",
                  min: config.humMin,
                  max: config.humMax,
                  isHighlighted:
                      hasAlert && alert!.affectedSensor == 'humidity',
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  rowKey: _soilKeys[serre.serreId]!,
                  icon: Icons.grass,
                  color: Colors.brown,
                  label: "Humidité sol",
                  value: sensor.soilPercent,
                  unit: "%",
                  min: 30.0,
                  max: 70.0,
                  isHighlighted:
                      hasAlert && alert!.affectedSensor == 'soil',
                ),

                const SizedBox(height: 14),

                // Pump button
                _buildPumpButton(
                  isActive: soil.isPumpActive,
                  isAutoMode: isAuto,
                  pumpLoading: pumpLoading,
                  onTap: () => widget.onPumpToggle(serre.serreId),
                ),

                const SizedBox(height: 10),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(sensor.time,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: soil.isPumpActive
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.water,
                            size: 10,
                            color: soil.isPumpActive
                                ? Colors.green
                                : Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          soil.isPumpActive ? "ON" : "OFF",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: soil.isPumpActive
                                  ? Colors.green
                                  : Colors.grey.shade700),
                        ),
                      ]),
                    ),
                  ],
                ),

                if (sensor.soilRaw > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.sensors,
                          size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text("Brut: ${sensor.soilRaw}",
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sensor row with highlight ────────────────────────────────────────────
  Widget _buildSensorRow({
    required GlobalKey rowKey,
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    bool isHighlighted = false,
  }) {
    final outOfRange = value < min || value > max;
    final statusColor = outOfRange ? Colors.red : Colors.green.shade700;

    return AnimatedContainer(
      key: rowKey,
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isHighlighted
            ? Border.all(color: Colors.red.shade400, width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.red.withOpacity(0.15)
                : color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: isHighlighted ? Colors.red : color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  if (isHighlighted) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⚠ ALERTE',
                        style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              Row(children: [
                Flexible(
                  child: Text(
                    "${value.toStringAsFixed(1)}$unit",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
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

  // ─── Pump button ──────────────────────────────────────────────────────────
  Widget _buildPumpButton({
    required bool isActive,
    required bool isAutoMode,
    required bool pumpLoading,
    required VoidCallback onTap,
  }) {
    final isDisabled = isAutoMode || pumpLoading;
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
                        : isActive ? Colors.red : Colors.green)
                    .withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pumpLoading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                Icon(
                  isAutoMode
                      ? Icons.smart_toy
                      : isActive
                          ? Icons.power_settings_new
                          : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                pumpLoading
                    ? "EN COURS..."
                    : isAutoMode
                        ? "GÉRÉ AUTOMATIQUEMENT"
                        : isActive
                            ? "POMPE ACTIVE"
                            : "DÉMARRER",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}