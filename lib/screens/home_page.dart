import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_router.dart';
import '../models/sensor_data.dart';
import '../models/threshold_config.dart';
import '../models/alert_payload.dart';
import '../models/Hydraulic_data.dart';
import '../widgets/vegetable_slider.dart';
import 'settings_page.dart';
import 'historique_page.dart';
import '../services/voice_service.dart';

class HomePage extends StatefulWidget {
  final AlertPayload? initialAlert;
  const HomePage({super.key, this.initialAlert});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Map<String, Color> _serreColors = {
    SerreId.tomate:        const Color(0xFFE74C3C),
    SerreId.tomate_cerise: const Color(0xFFC0392B),
  };

  final Map<String, SensorData>     _sensorDataMap = {
    SerreId.tomate:        SensorData.initial(),
    SerreId.tomate_cerise: SensorData.initial(),
  };
  final Map<String, SoilSensorData> _soilDataMap = {
    SerreId.tomate:        SoilSensorData.initial(),
    SerreId.tomate_cerise: SoilSensorData.initial(),
  };
  final Map<String, ThresholdConfig> _thresholdMap = {
    SerreId.tomate:        ThresholdConfig(),
    SerreId.tomate_cerise: ThresholdConfig(),
  };

  final Map<String, bool> _autoEVMap = {
    SerreId.tomate:        true,
    SerreId.tomate_cerise: true,
  };
  final Map<String, bool> _evStateMap = {
    SerreId.tomate:        false,
    SerreId.tomate_cerise: false,
  };
  final Map<String, bool> _evLoadingMap = {
    SerreId.tomate:        false,
    SerreId.tomate_cerise: false,
  };
  final Map<String, bool> _pumpLoadingMap = {
    SerreId.tomate:        false,
    SerreId.tomate_cerise: false,
  };
  final Map<String, bool> _connectedMap = {
    SerreId.tomate:        false,
    SerreId.tomate_cerise: false,
  };

  HydraulicData _hydraulicData    = HydraulicData.initial();
  bool          _mainPumpLoading  = false;
  bool          _mainModeLoading  = false;
  StreamSubscription<DatabaseEvent>? _hydResSub;
  StreamSubscription<DatabaseEvent>? _hydPumpSub;
  Map<dynamic, dynamic>? _hydResSnap;
  Map<dynamic, dynamic>? _hydPumpSnap;

  int           _currentVegetableIndex = 0;
  bool          _isListening           = false;
  late PageController _externalPageController;
  AlertPayload? _activeAlert;
  StreamSubscription<AlertPayload>? _alertSub;

  String get _currentSerreId =>
      _currentVegetableIndex == 0 ? SerreId.tomate : SerreId.tomate_cerise;
  Color get _activeColor => _serreColors[_currentSerreId]!;
  bool get isConnected =>
      (_connectedMap[SerreId.tomate] ?? false) ||
      (_connectedMap[SerreId.tomate_cerise] ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _externalPageController = PageController();
    if (widget.initialAlert != null) _activeAlert = widget.initialAlert;
    _alertSub = NotificationRouter.onAlert.listen(
        (p) => setState(() => _activeAlert = p));
    for (final id in SerreId.all) {
      _listenToFirebase(id);
      _loadConfig(id);
    }
    _listenHydraulic();
    if (_activeAlert == null) _checkLastAlertFromFirebase();
    _setupVoice();
    FirebaseService.testConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        VoiceService.pause();
        if (mounted) setState(() => _isListening = false);
        break;
      case AppLifecycleState.resumed:
        VoiceService.resume();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _setupVoice() {
    VoiceService.onSessionStarted = () {
      if (!mounted) return;
      setState(() => _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Rigoula a votre ecoute'),
        backgroundColor: _activeColor,
        duration: const Duration(seconds: 2),
      ));
    };
    VoiceService.onCommandReceived = (cmd, raw) {
      if (!mounted) return;
      _handleVoiceCommand(cmd, raw);
    };
    VoiceService.onSessionEnded = () {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Session vocale terminee'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ));
    };
    VoiceService.initialize().then((_) => VoiceService.startIdleListening());
  }

  Future<void> _checkLastAlertFromFirebase() async {
    for (final serreId in SerreId.all) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref("serres/$serreId/last_alert")
            .get();
        if (snap.exists && snap.value != null) {
          final data    = Map<dynamic, dynamic>.from(snap.value as Map);
          final payload = AlertPayload.fromLastAlert(serreId, data);
          final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
              payload.timestamp;
          if (age < 3600 && payload.alertType != AlertType.unknown) {
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
      setState(() => _thresholdMap[serreId] = ThresholdConfig.fromMap(config));
    }
  }

  void _listenToFirebase(String serreId) {
    FirebaseService.getSensorDataStream(serreId).listen(
      (event) {
        final data = FirebaseService.parseSensorData(event.snapshot);
        if (data != null && mounted) {
          setState(() {
            _sensorDataMap[serreId] = SensorData.fromMap(data);
            _soilDataMap[serreId]   = SoilSensorData(
              moisture:     (data['soil_percent'] as num?)?.toDouble() ?? 0.0,
              isPumpActive: data['pump']?.toString() == 'ON',
            );
            _autoEVMap[serreId]  =
                (data['mode_ev']?.toString() ?? 'AUTO') == 'AUTO';
            _evStateMap[serreId] = data['ev']?.toString() == 'OPEN';
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

  void _listenHydraulic() {
    void rebuild() {
      if (!mounted) return;
      setState(() => _hydraulicData =
          HydraulicData.fromFirebase(_hydResSnap, _hydPumpSnap));
    }

    _hydResSub = FirebaseService.getHydraulicReservoirStream().listen((e) {
      _hydResSnap = e.snapshot.value != null
          ? Map<dynamic, dynamic>.from(e.snapshot.value as Map)
          : null;
      rebuild();
    });
    _hydPumpSub = FirebaseService.getHydraulicPumpStream().listen((e) {
      _hydPumpSnap = e.snapshot.value != null
          ? Map<dynamic, dynamic>.from(e.snapshot.value as Map)
          : null;
      rebuild();
    });
  }

  Future<void> _toggleEV(String serreId) async {
    if (_evLoadingMap[serreId] ?? false) return;
    if (_autoEVMap[serreId] ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mode AUTO — passez en MANUEL pour controler l\'EV'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    setState(() => _evLoadingMap[serreId] = true);
    final open = !(_evStateMap[serreId] ?? false);
    final ok = await FirebaseService.setEVCommand(serreId, open);
    if (!mounted) return;
    setState(() {
      _evLoadingMap[serreId] = false;
      if (ok) _evStateMap[serreId] = open;
    });
    if (ok) {
      if (open) FirebaseService.incrementEVCount(serreId);
      FirebaseService.logAction(
        serreId: serreId,
        type:    open ? 'ev_open' : 'ev_close',
        source:  'flutter_manual',
      );
      final label = serreId == SerreId.tomate ? 'Tomate' : 'Tomate Cerise';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(open
            ? 'EV $label OUVERTE — irrigation demarree'
            : 'EV $label FERMEE'),
        backgroundColor: open ? Colors.blue : Colors.grey.shade700,
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur commande electrovanne'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Future<void> _toggleEVMode(String serreId) async {
    final currentAuto = _autoEVMap[serreId] ?? true;
    final newMode = currentAuto ? 'MANUEL' : 'AUTO';
    final ok = await FirebaseService.setEVMode(serreId, newMode);
    if (!mounted || !ok) return;
    setState(() => _autoEVMap[serreId] = !currentAuto);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(!currentAuto ? 'EV — Mode AUTO' : 'EV — Mode MANUEL'),
      backgroundColor: !currentAuto ? Colors.blue : Colors.orange,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _toggleMainPump() async {
    if (_mainPumpLoading) return;
    if (_hydraulicData.mode == HydraulicMode.auto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mode AUTO — passez en MANUEL pour controler la pompe'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    if (_hydraulicData.levelHigh && _hydraulicData.pumpState == PumpState.off) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Pompe bloquee — citerne deja pleine'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    setState(() => _mainPumpLoading = true);
    final turnOn = _hydraulicData.pumpState == PumpState.off;
    final ok = await FirebaseService.setHydraulicPumpCmd(turnOn);
    if (!mounted) return;
    setState(() => _mainPumpLoading = false);
    if (ok) {
      if (turnOn) FirebaseService.incrementPumpCount(SerreId.tomate);
      FirebaseService.logAction(
        serreId: 'hydraulique',
        type:    turnOn ? 'pump_on' : 'pump_off',
        source:  'flutter_manual',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (turnOn ? 'Pompe principale ON' : 'Pompe principale OFF')
          : 'Erreur commande pompe'),
      backgroundColor: ok ? (turnOn ? Colors.green : Colors.red) : Colors.orange,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _toggleMainMode() async {
    if (_mainModeLoading) return;
    setState(() => _mainModeLoading = true);
    final newMode =
        _hydraulicData.mode == HydraulicMode.auto ? 'MANUEL' : 'AUTO';
    final ok = await FirebaseService.setHydraulicMode(newMode);
    if (!mounted) return;
    setState(() => _mainModeLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newMode == 'AUTO'
            ? 'Pompe principale — Mode AUTO'
            : 'Pompe principale — Mode MANUEL'),
        backgroundColor: newMode == 'AUTO' ? Colors.blue : Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _openSettings(String serreId) async {
    await VoiceService.stopSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          serreId:       serreId,
          currentConfig: _thresholdMap[serreId]!,
          onConfigSaved: (c) => setState(() => _thresholdMap[serreId] = c),
        ),
      ),
    );
    if (mounted) VoiceService.startIdleListening();
  }

  void _openHistorique(String serreId) async {
    await VoiceService.stopSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoriquePage(serreId: serreId)),
    );
    if (mounted) VoiceService.startIdleListening();
  }

  Future<void> _handleVoiceCommand(VoiceCommand command, String raw) async {
    switch (command) {
      case VoiceCommand.pumpOn:
        _toggleMainPump();
        break;
      case VoiceCommand.pumpOff:
        _toggleMainPump();
        break;
      case VoiceCommand.evOpen:
        _toggleEV(_currentSerreId);
        break;
      case VoiceCommand.evClose:
        _toggleEV(_currentSerreId);
        break;
      case VoiceCommand.modeAuto:
        if (!(_autoEVMap[_currentSerreId] ?? true)) {
          _toggleEVMode(_currentSerreId);
        }
        _showVoiceSnack('Mode EV AUTO');
        break;
      case VoiceCommand.modeManuel:
        if (_autoEVMap[_currentSerreId] ?? true) {
          _toggleEVMode(_currentSerreId);
        }
        _showVoiceSnack('Mode EV MANUEL');
        break;
      case VoiceCommand.openHistorique:
        _openHistorique(_currentSerreId);
        break;
      case VoiceCommand.openSettings:
        _openSettings(_currentSerreId);
        break;
      case VoiceCommand.slideTomate:
        _externalPageController.animateToPage(0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
        _showVoiceSnack('Tomate');
        break;
      case VoiceCommand.slidecerise:
        _externalPageController.animateToPage(1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
        _showVoiceSnack('Tomate Cerise');
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
        Navigator.of(context).popUntil((r) => r.isFirst);
        _showVoiceSnack('Retour accueil');
        break;
      case VoiceCommand.unknown:
        _showVoiceSnack('Non reconnue : "$raw"');
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertSub?.cancel();
    _hydResSub?.cancel();
    _hydPumpSub?.cancel();
    VoiceService.pause();
    _externalPageController.dispose();
    super.dispose();
  }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.mic, color: Colors.red, size: 18),
                  SizedBox(width: 4),
                  Text("ECOUTE",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                ]),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isConnected ? Colors.green : Colors.red,
                    width: 1.5),
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Expanded(
                child: VegetableSlider(
                  sensorDataMap:     _sensorDataMap,
                  soilDataMap:       _soilDataMap,
                  thresholdConfigMap: _thresholdMap,
                  autoEVMap:         _autoEVMap,
                  pumpLoadingMap:    _pumpLoadingMap,
                  evStateMap:        _evStateMap,
                  evLoadingMap:      _evLoadingMap,
                  onEVToggle:        _toggleEV,
                  onEVModeToggle:    _toggleEVMode,
                  onOpenSettings:    _openSettings,
                  onOpenHistorique:  _openHistorique,
                  onPageChanged: (i) =>
                      setState(() => _currentVegetableIndex = i),
                  externalController: _externalPageController,
                  activeAlert:        _activeAlert,
                  onAlertDismissed: () =>
                      setState(() => _activeAlert = null),
                ),
              ),
              _buildMainPumpSection(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPumpSection() {
    final isAuto     = _hydraulicData.mode == HydraulicMode.auto;
    final isOn       = _hydraulicData.pumpState == PumpState.on;
    final isAlert    = _hydraulicData.isAlert;
    final pct        = (_hydraulicData.fillPercent / 100).clamp(0.0, 1.0);
    final levelColor = pct < 0.2
        ? Colors.red
        : pct < 0.5
            ? Colors.orange
            : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : Colors.blue.shade100,
          width: isAlert ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAlert ? Colors.red : Colors.blue).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(isAlert ? '!' : '', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pompe Principale',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  Row(children: [
                    Text(
                      '${_hydraulicData.fillPercent.toStringAsFixed(0)}%  —  ${_hydraulicData.fillLabel}',
                      style: TextStyle(fontSize: 10, color: levelColor),
                    ),
                    const SizedBox(width: 8),
                    _dot(_hydraulicData.levelLow, Colors.red),
                    const SizedBox(width: 2),
                    Text('MIN',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    _dot(_hydraulicData.levelHigh, Colors.green),
                    const SizedBox(width: 2),
                    Text('MAX',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500)),
                  ]),
                ],
              ),
            ),
            GestureDetector(
              onTap: _mainModeLoading ? null : _toggleMainMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isAuto
                      ? Colors.blue.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAuto
                        ? Colors.blue.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: _mainModeLoading
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isAuto
                                ? Colors.blue.shade700
                                : Colors.orange.shade700))
                    : Text(
                        isAuto ? 'AUTO' : 'MANUEL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAuto
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          _buildMainPumpButton(isAuto, isOn),
        ],
      ),
    );
  }

  Widget _dot(bool active, Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color : Colors.grey.shade300,
          boxShadow: active
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
              : [],
        ),
      );

  Widget _buildMainPumpButton(bool isAuto, bool isOn) {
    final blocked  = _hydraulicData.levelHigh && !isOn;
    final disabled = isAuto || _mainPumpLoading || blocked;
    final Color btnColor = isAuto
        ? Colors.blue
        : _mainPumpLoading || blocked
            ? Colors.grey
            : isOn
                ? Colors.red
                : Colors.green;
    final String btnLabel = _mainPumpLoading
        ? 'EN COURS...'
        : isAuto
            ? 'GERE AUTOMATIQUEMENT'
            : blocked
                ? 'CITERNE PLEINE — POMPE BLOQUEE'
                : isOn
                    ? 'ARRETER LA POMPE'
                    : 'DEMARRER LA POMPE';
    final IconData btnIcon = isAuto
        ? Icons.smart_toy
        : blocked
            ? Icons.water_drop
            : isOn
                ? Icons.power_settings_new
                : Icons.play_arrow_rounded;

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: InkWell(
        onTap: disabled ? null : _toggleMainPump,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [btnColor.withOpacity(0.85), btnColor]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: btnColor.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_mainPumpLoading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
              else
                Icon(btnIcon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(btnLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}