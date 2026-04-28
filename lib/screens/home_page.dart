// ══════════════════════════════════════════════════════════════════════════════
// PATCH for home_page.dart
// Replace ONLY the sections marked ← CHANGED.
// Everything else (Firebase, pump, settings, etc.) stays identical.
// ══════════════════════════════════════════════════════════════════════════════

// 1. Add WidgetsBindingObserver to the State class declaration:
//
//   class _HomePageState extends State<HomePage>
//       with WidgetsObserverMixin            // ← CHANGED (see mixin below)
//
// Because Dart doesn't allow multiple `with` clauses mixing State mixins
// easily, the cleanest pattern is to implement WidgetsBindingObserver directly:

/*
──────────────────────────────────────────────────────────────────────────────
STEP A — change the class signature
──────────────────────────────────────────────────────────────────────────────
BEFORE:
  class _HomePageState extends State<HomePage> {

AFTER:
  class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
*/

/*
──────────────────────────────────────────────────────────────────────────────
STEP B — register / unregister the observer in initState / dispose
──────────────────────────────────────────────────────────────────────────────
In initState(), ADD at the very top:
  WidgetsBinding.instance.addObserver(this);

In dispose(), ADD before super.dispose():
  WidgetsBinding.instance.removeObserver(this);
*/

/*
──────────────────────────────────────────────────────────────────────────────
STEP C — override didChangeAppLifecycleState
──────────────────────────────────────────────────────────────────────────────
Add this method to _HomePageState:

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:        // Flutter 3.13+
        VoiceService.pause();               // stops mic immediately
        break;
      case AppLifecycleState.resumed:
        VoiceService.resume();              // restarts correct loop
        break;
      case AppLifecycleState.inactive:
        break;                              // short interruption — do nothing
    }
  }
*/

/*
──────────────────────────────────────────────────────────────────────────────
STEP D — replace _startContinuousWakeWordListening() and related voice methods
──────────────────────────────────────────────────────────────────────────────
Remove the old methods:
  • _startContinuousWakeWordListening()
  • _startCommandListeningSession()

Replace with:
*/

// ── Voice setup ──────────────────────────────────────────────────────────────
//
//   void _setupVoice() {
//     // Assign callbacks BEFORE calling initialize so they are ready
//     // when the engine fires its first status event.
//     VoiceService.onSessionStarted = () {
//       if (!mounted) return;
//       setState(() => _isListening = true);
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: const Text('🎤 Rigoula à votre écoute !'),
//         backgroundColor: _activeColor,
//         duration: const Duration(seconds: 2),
//       ));
//     };
//
//     VoiceService.onCommandReceived = (command, raw) {
//       if (!mounted) return;
//       _handleVoiceCommand(command, raw);
//     };
//
//     VoiceService.onSessionEnded = () {
//       if (!mounted) return;
//       setState(() => _isListening = false);
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('🔇 Session vocale terminée'),
//         backgroundColor: Colors.grey,
//         duration: Duration(seconds: 2),
//       ));
//     };
//
//     VoiceService.initialize().then((_) => VoiceService.startIdleListening());
//   }

/*
──────────────────────────────────────────────────────────────────────────────
STEP E — update _handleVoiceCommand signature
──────────────────────────────────────────────────────────────────────────────
BEFORE:
  Future<void> _handleVoiceCommand(String text) async {
    final command = VoiceService.parseCommand(text);
    switch (command) { ... }
  }

AFTER:
  Future<void> _handleVoiceCommand(VoiceCommand command, String raw) async {
    switch (command) { ... }   // same body, no parseCommand call needed
  }
*/

/*
──────────────────────────────────────────────────────────────────────────────
STEP F — update _openSettings / _openHistorique
──────────────────────────────────────────────────────────────────────────────
BEFORE:
  await VoiceService.stopContinuousListening();
  ...
  if (mounted) _startContinuousWakeWordListening();

AFTER:
  await VoiceService.stopSession();
  ...
  if (mounted) VoiceService.startIdleListening();
*/

/*
──────────────────────────────────────────────────────────────────────────────
STEP G — update dispose()
──────────────────────────────────────────────────────────────────────────────
BEFORE:
  VoiceService.stopContinuousListening();

AFTER:
  VoiceService.pause();   // stops mic without clearing session flag
*/

// ══════════════════════════════════════════════════════════════════════════════
// COMPLETE MINIMAL home_page.dart DIFF (copy-paste ready)
// ══════════════════════════════════════════════════════════════════════════════
//
// Only the voice-related lines change; everything else is identical to your
// original file.  Lines marked [+] are new; lines marked [-] are removed.
//
// class _HomePageState extends State<HomePage> {          [-]
// class _HomePageState extends State<HomePage>            [+]
//     with WidgetsBindingObserver {                       [+]
//
// initState() {
//   [+] WidgetsBinding.instance.addObserver(this);
//   ...
//   [-] VoiceService.initialize().then((_) => _startContinuousWakeWordListening());
//   [+] _setupVoice();
// }
//
// dispose() {
//   [-] VoiceService.stopContinuousListening();
//   [+] WidgetsBinding.instance.removeObserver(this);
//   [+] VoiceService.pause();
//   ...
// }
//
// [+] @override
// [+] void didChangeAppLifecycleState(AppLifecycleState state) { ... }
//
// [+] void _setupVoice() { ... }
//
// [-] void _startContinuousWakeWordListening() { ... }
// [-] void _startCommandListeningSession()    { ... }
//
// [-] Future<void> _handleVoiceCommand(String text) async {
// [-]   final command = VoiceService.parseCommand(text);
// [+] Future<void> _handleVoiceCommand(VoiceCommand command, String raw) async {
//
// ══════════════════════════════════════════════════════════════════════════════
// FULL PATCHED home_page.dart (voice sections only, rest unchanged)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/notification_router.dart';
import '../models/sensor_data.dart';
import '../models/soil_sensor_data.dart';
import '../models/threshold_config.dart';
import '../models/alert_payload.dart';
import '../widgets/vegetable_slider.dart';
import '../widgets/alert_banner.dart';
import 'settings_page.dart';
import 'historique_page.dart';
import '../services/voice_service.dart';

class HomePage extends StatefulWidget {
  final AlertPayload? initialAlert;
  const HomePage({super.key, this.initialAlert});

  @override
  State<HomePage> createState() => _HomePageState();
}

// ← CHANGED: add WidgetsBindingObserver
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // ── Serre colors ──────────────────────────────────────────────────────────
  final Map<String, Color> _serreColors = {
    SerreId.tomate: const Color(0xFFE74C3C),
    SerreId.tomate_cerise: const Color(0xFFC0392B),
  };

  // ── Per-serre state ───────────────────────────────────────────────────────
  final Map<String, SensorData> _sensorDataMap = {
    SerreId.tomate: SensorData.initial(),
    SerreId.tomate_cerise: SensorData.initial(),
  };
  final Map<String, SoilSensorData> _soilDataMap = {
    SerreId.tomate: SoilSensorData.initial(),
    SerreId.tomate_cerise: SoilSensorData.initial(),
  };
  final Map<String, ThresholdConfig> _thresholdMap = {
    SerreId.tomate: ThresholdConfig(),
    SerreId.tomate_cerise: ThresholdConfig(),
  };
  final Map<String, bool> _autoModeMap = {
    SerreId.tomate: true,
    SerreId.tomate_cerise: true,
  };
  final Map<String, bool> _pumpLoadingMap = {
    SerreId.tomate: false,
    SerreId.tomate_cerise: false,
  };
  final Map<String, bool> _connectedMap = {
    SerreId.tomate: false,
    SerreId.tomate_cerise: false,
  };

  int _currentVegetableIndex = 0;
  bool _isListening = false;
  late PageController _externalPageController;

  AlertPayload? _activeAlert;
  StreamSubscription<AlertPayload>? _alertSub;

  String get _currentSerreId =>
      _currentVegetableIndex == 0 ? SerreId.tomate : SerreId.tomate_cerise;
  Color get _activeColor => _serreColors[_currentSerreId]!;
  bool get isConnected =>
      (_connectedMap[SerreId.tomate] ?? false) ||
      (_connectedMap[SerreId.tomate_cerise] ?? false);

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ← CHANGED

    _externalPageController = PageController();

    if (widget.initialAlert != null) _activeAlert = widget.initialAlert;

    _alertSub = NotificationRouter.onAlert.listen((payload) {
      setState(() => _activeAlert = payload);
    });

    for (final serreId in SerreId.all) {
      _listenToFirebase(serreId);
      _loadConfig(serreId);
    }

    if (_activeAlert == null) _checkLastAlertFromFirebase();

    _setupVoice(); // ← CHANGED: replaces VoiceService.initialize().then(...)
    FirebaseService.testConnection();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE — app goes background / foreground                    ← CHANGED
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: // Flutter 3.13+
        VoiceService.pause(); // stops mic immediately
        if (mounted) setState(() => _isListening = false);
        break;
      case AppLifecycleState.resumed:
        VoiceService.resume(); // restarts correct loop
        break;
      case AppLifecycleState.inactive:
        break; // brief interruption (phone call overlay etc.) — do nothing
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOICE SETUP — called once from initState                        ← CHANGED
  // ─────────────────────────────────────────────────────────────────────────
  void _setupVoice() {
    // Wire callbacks BEFORE initialize so they're ready when STT fires.
    VoiceService.onSessionStarted = () {
      if (!mounted) return;
      setState(() => _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('🎤 Rigoula à votre écoute !'),
        backgroundColor: _activeColor,
        duration: const Duration(seconds: 2),
      ));
    };

    VoiceService.onCommandReceived = (command, raw) {
      if (!mounted) return;
      _handleVoiceCommand(command, raw);
    };

    VoiceService.onSessionEnded = () {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🔇 Session vocale terminée'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ));
    };

    VoiceService.initialize().then((_) => VoiceService.startIdleListening());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIREBASE (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _checkLastAlertFromFirebase() async {
    for (final serreId in SerreId.all) {
      try {
        final ref = FirebaseDatabase.instance.ref("serres/$serreId/last_alert");
        final snapshot = await ref.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
          final payload = AlertPayload.fromLastAlert(serreId, data);
          final ageSeconds =
              DateTime.now().millisecondsSinceEpoch ~/ 1000 - payload.timestamp;
          if (ageSeconds < 3600 && payload.alertType != AlertType.unknown) {
            if (mounted) setState(() => _activeAlert = payload);
            break;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadConfig(String serreId) async {
    final config = await FirebaseService.loadConfig(serreId);
    if (config != null && mounted) {
      setState(() {
        _thresholdMap[serreId] = ThresholdConfig(
          tempMin: config['temp_min']!,
          tempMax: config['temp_max']!,
          humMin: config['hum_min']!,
          humMax: config['hum_max']!,
        );
      });
    }
  }

  void _listenToFirebase(String serreId) {
    FirebaseService.getSensorDataStream(serreId).listen(
      (event) {
        final data = FirebaseService.parseSensorData(event.snapshot);
        if (data != null && mounted) {
          setState(() {
            _sensorDataMap[serreId] = SensorData.fromMap(data);
            _soilDataMap[serreId] = SoilSensorData(
              moisture: (data['soil_percent'] as num?)?.toDouble() ?? 45.0,
              isPumpActive: data['pump']?.toString() == 'ON',
            );
            _autoModeMap[serreId] ??=
                (data['mode']?.toString() ?? 'AUTO') == 'AUTO';
            _connectedMap[serreId] = true;
          });
          FirebaseService.saveToHistory(serreId, data);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _connectedMap[serreId] = false);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUMP / MODE (unchanged logic)
  // ─────────────────────────────────────────────────────────────────────────
  void _toggleMode(String serreId) async {
    final currentAuto = _autoModeMap[serreId] ?? true;
    final newMode = currentAuto ? "MANUEL" : "AUTO";
    final success = await FirebaseService.setMode(serreId, newMode);
    if (!mounted) return;
    if (success) {
      setState(() => _autoModeMap[serreId] = !currentAuto);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!currentAuto ? '🤖 Mode AUTO activé' : '🕹️ Mode MANUEL activé'),
        backgroundColor: !currentAuto ? Colors.blue : Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _togglePump(String serreId) async {
    if ((_pumpLoadingMap[serreId] ?? false) || (_autoModeMap[serreId] ?? true)) return;
    setState(() => _pumpLoadingMap[serreId] = true);

    final currentSoil = _soilDataMap[serreId] ?? SoilSensorData.initial();
    final newState = !currentSoil.isPumpActive;
    final success = await FirebaseService.setPumpCommand(serreId, newState);

    if (!mounted) return;
    if (success) {
      if (newState) FirebaseService.incrementPompeCount(serreId);
      NotificationService.showPumpNotification(isPumpActive: newState);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newState ? '💧 Pompe ON' : '⛔ Pompe OFF'),
        backgroundColor: newState ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ Erreur envoi commande'),
        backgroundColor: Colors.orange,
      ));
    }
    setState(() => _pumpLoadingMap[serreId] = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION — updated to use new VoiceService API              ← CHANGED
  // ─────────────────────────────────────────────────────────────────────────
  void _openSettings(String serreId) async {
    await VoiceService.stopSession(); // ← CHANGED
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          serreId: serreId,
          currentConfig: _thresholdMap[serreId]!,
          onConfigSaved: (newConfig) {
            setState(() => _thresholdMap[serreId] = newConfig);
          },
        ),
      ),
    );
    if (mounted) VoiceService.startIdleListening(); // ← CHANGED
  }

  void _openHistorique(String serreId) async {
    await VoiceService.stopSession(); // ← CHANGED
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoriquePage(serreId: serreId)),
    );
    if (mounted) VoiceService.startIdleListening(); // ← CHANGED
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOICE COMMAND HANDLER — new signature                          ← CHANGED
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleVoiceCommand(VoiceCommand command, String raw) async {
    // ← CHANGED: command already parsed by VoiceService, no need to re-parse
    switch (command) {
      case VoiceCommand.pumpOn:
        if (!(_autoModeMap[_currentSerreId] ?? true)) _togglePump(_currentSerreId);
        _showVoiceSnack('💧 Pompe activée');
        break;
      case VoiceCommand.pumpOff:
        if (!(_autoModeMap[_currentSerreId] ?? true)) _togglePump(_currentSerreId);
        _showVoiceSnack('⛔ Pompe désactivée');
        break;
      case VoiceCommand.modeAuto:
        if (!(_autoModeMap[_currentSerreId] ?? true)) _toggleMode(_currentSerreId);
        _showVoiceSnack('🤖 Mode AUTO');
        break;
      case VoiceCommand.modeManuel:
        if (_autoModeMap[_currentSerreId] ?? true) _toggleMode(_currentSerreId);
        _showVoiceSnack('🕹️ Mode MANUEL');
        break;
      case VoiceCommand.openHistorique:
        _openHistorique(_currentSerreId);
        break;
      case VoiceCommand.openSettings:
        _openSettings(_currentSerreId);
        break;
      case VoiceCommand.slideTomate:
        _externalPageController.animateToPage(0,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🍅 Tomate');
        break;
      case VoiceCommand.slidecerise:
        _externalPageController.animateToPage(1,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🍒 Tomate Cerise');
        break;
      case VoiceCommand.slideNext:
        _externalPageController.animateToPage(
            (_currentVegetableIndex + 1) % 2,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
        break;
      case VoiceCommand.slidePrev:
        _externalPageController.animateToPage(
            (_currentVegetableIndex - 1 + 2) % 2,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
        break;
      
      case VoiceCommand.returnHome:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showVoiceSnack('🏠 Retour accueil');
        break;
      case VoiceCommand.unknown:
        _showVoiceSnack('❓ Non reconnue : "$raw"');
        break;
    }
  }

  void _showVoiceSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      backgroundColor: _activeColor,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ← CHANGED
    _alertSub?.cancel();
    VoiceService.pause(); // ← CHANGED: stops mic without clearing session
    _externalPageController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_activeColor.withOpacity(0.12), Colors.white],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: _activeColor.withOpacity(0.15),
          elevation: 2,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: _activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  image: const DecorationImage(
                    image: AssetImage('assets/rigoula.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Rigoula",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32))),
                    const Text("Smart Farming",
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_isListening)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic, color: Colors.red, size: 18),
                    SizedBox(width: 4),
                    Text("ÉCOUTE",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isConnected ? Colors.green : Colors.red, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text(isConnected ? "ON" : "OFF",
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isConnected ? Colors.green : Colors.red)),
              ]),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: VegetableSlider(
                  sensorDataMap: _sensorDataMap,
                  soilDataMap: _soilDataMap,
                  thresholdConfigMap: _thresholdMap,
                  autoModeMap: _autoModeMap,
                  pumpLoadingMap: _pumpLoadingMap,
                  onPumpToggle: _togglePump,
                  onModeToggle: _toggleMode,
                  onOpenSettings: _openSettings,
                  onOpenHistorique: _openHistorique,
                  onPageChanged: (index) =>
                      setState(() => _currentVegetableIndex = index),
                  externalController: _externalPageController,
                  activeAlert: _activeAlert,
                  onAlertDismissed: () => setState(() => _activeAlert = null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}