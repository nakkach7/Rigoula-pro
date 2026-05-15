enum PumpState    { on, off }
enum FillState    { unknown, low, filling, full, normal }
enum HydraulicMode { auto, manuel }

class HydraulicData {
  final PumpState     pumpState;
  final FillState     fillState;
  final HydraulicMode mode;
  final bool          canRun;
  final bool          levelLow;
  final bool          levelHigh;
  final double        fillPercent;
  final String        time;

  const HydraulicData({
    this.pumpState   = PumpState.off,
    this.fillState   = FillState.normal,
    this.mode        = HydraulicMode.auto,
    this.canRun      = true,
    this.levelLow    = false,
    this.levelHigh   = false,
    this.fillPercent = 50.0,
    this.time        = '--:--',
  });

  factory HydraulicData.initial() => const HydraulicData();

  factory HydraulicData.fromFirebase(
    Map<dynamic, dynamic>? res,
    Map<dynamic, dynamic>? pump,
  ) {
    final r = res  ?? {};
    final p = pump ?? {};
    final combined = {...r, ...p};

    final String modeStr = (p['mode'] ?? 'AUTO').toString().toUpperCase();
    final HydraulicMode hMode =
        modeStr == 'MANUEL' ? HydraulicMode.manuel : HydraulicMode.auto;

    final String pumpRaw;
    if (hMode == HydraulicMode.manuel) {
      pumpRaw = (p['cmd'] ?? p['state'] ?? p['pump'] ?? 'OFF')
          .toString()
          .toUpperCase();
    } else {
      pumpRaw = (p['state'] ?? p['pump'] ?? 'OFF')
          .toString()
          .toUpperCase();
    }
    final PumpState pState = pumpRaw == 'ON' ? PumpState.on : PumpState.off;

    final bool levelLow  = _parseBool(combined['level_low'])  ||
                           _parseBool(combined['low_level']);
    final bool levelHigh = _parseBool(combined['level_high']) ||
                           _parseBool(combined['high_level']);

final bool canRun = !levelHigh;
    final int fillInt = (combined['fill_state'] as num?)?.toInt() ?? 4;
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
      canRun:      canRun,
      levelLow:    levelLow,
      levelHigh:   levelHigh,
      fillPercent: (combined['fill_percent'] as num?)?.toDouble() ?? 50.0,
      time:        combined['time']?.toString() ?? '--:--',
    );
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int)  return value != 0;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return defaultValue;
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