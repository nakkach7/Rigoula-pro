// lib/models/hydraulic_data.dart
// Représente l'état du système hydraulique central

enum PumpState  { on, off }
enum FillState  { unknown, low, filling, full, normal }
enum HydraulicMode { auto, manuel }

class HydraulicData {
  final PumpState  pumpState;
  final FillState  fillState;
  final HydraulicMode mode;
  final bool       canRun;
  final bool       levelLow;
  final bool       levelHigh;
  final double     fillPercent;
  final String     time;

  const HydraulicData({
    this.pumpState   = PumpState.off,
    this.fillState   = FillState.normal,
    this.mode        = HydraulicMode.auto,
    this.canRun      = true,
    this.levelLow    = false,
    this.levelHigh   = false,
    this.fillPercent = 50.0,
    this.time        = "--:--",
  });

  factory HydraulicData.initial() => const HydraulicData();

  factory HydraulicData.fromFirebase(Map<dynamic, dynamic>? res, Map<dynamic, dynamic>? pump) {
    final r = res   ?? {};
    final p = pump  ?? {};

    // Compatibilité v1 : ancienne structure hydraulique/hydraulique
    final combined = {...r, ...p};

    bool levelLow  = combined['level_low']  ?? combined['low_level']  ?? false;
    bool levelHigh = combined['level_high'] ?? combined['high_level'] ?? false;

    PumpState pState = (combined['state'] ?? combined['pump']) == 'ON'
        ? PumpState.on : PumpState.off;

    String modeStr = (combined['mode'] ?? 'AUTO').toString().toUpperCase();
    HydraulicMode hMode = modeStr == 'MANUEL'
        ? HydraulicMode.manuel : HydraulicMode.auto;

    // fill_state entier → enum
    int fillInt = (combined['fill_state'] as num?)?.toInt() ?? 4;
    FillState fill = _fillFromInt(fillInt);
    if (fill == FillState.unknown) {
      if (levelLow && !levelHigh) fill = FillState.low;
      else if (levelHigh)         fill = FillState.full;
      else                        fill = FillState.normal;
    }

    return HydraulicData(
      pumpState:   pState,
      fillState:   fill,
      mode:        hMode,
      canRun:      combined['can_run'] as bool? ?? true,
      levelLow:    levelLow,
      levelHigh:   levelHigh,
      fillPercent: (combined['fill_percent'] as num?)?.toDouble() ?? 50.0,
      time:        combined['time']?.toString() ?? "--:--",
    );
  }

  static FillState _fillFromInt(int v) {
    switch (v) {
      case 1: return FillState.low;
      case 2: return FillState.filling;
      case 3: return FillState.full;
      case 4: return FillState.normal;
      default: return FillState.unknown;
    }
  }

  // ── UI helpers ─────────────────────────────────────────────────────────
  String get fillLabel {
    switch (fillState) {
      case FillState.low:     return 'Réservoir bas';
      case FillState.filling: return 'Remplissage en cours';
      case FillState.full:    return 'Réservoir plein';
      case FillState.normal:  return 'Niveau normal';
      case FillState.unknown: return 'Inconnu';
    }
  }

  String get fillEmoji {
    switch (fillState) {
      case FillState.low:     return '🔴';
      case FillState.filling: return '🔵';
      case FillState.full:    return '🟢';
      case FillState.normal:  return '🟡';
      case FillState.unknown: return '⚪';
    }
  }

  bool get isAlert => fillState == FillState.low || !canRun;
}