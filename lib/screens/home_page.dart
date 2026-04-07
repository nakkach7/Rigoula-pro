import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/sensor_data.dart';
import '../models/soil_sensor_data.dart';
import '../models/threshold_config.dart';
import '../widgets/vegetable_slider.dart';
import '../widgets/alert_banner.dart';
import 'settings_page.dart';
import 'historique_page.dart';
import '../services/voice_service.dart';
import '../services/firebase_messaging_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Color> _vegetableColors = [
    const Color(0xFFE74C3C),
    const Color(0xFF9B59B6),
    const Color(0xFF27AE60),
    const Color(0xFF2ECC71),
  ];

  SensorData sensorData = SensorData.initial();
  SoilSensorData soilData = SoilSensorData.initial();
  bool isConnected = false;
  bool _wasConnected = false;
  final ThresholdConfig thresholdConfig = ThresholdConfig();
  bool alertShown = false;
  bool _pumpLoading = false;
  int _currentVegetableIndex = 0;
  bool isAutoMode = true;
  DateTime? _lastModeChange;
  bool _isListening = false;
  String _voiceStatus = '';
  late PageController _externalPageController;

  Color get _activeColor => _vegetableColors[_currentVegetableIndex];

  @override
  void initState() {
    super.initState();
    _externalPageController = PageController();

    VoiceService.initialize().then((_) {
      _startContinuousWakeWordListening();
    });

    _listenToFirebase();
    _testFirebaseConnection();
  }

  void _testFirebaseConnection() async {
    await FirebaseService.testConnection();
  }

  void _listenToFirebase() {
    FirebaseService.getSensorDataStream().listen(
      (event) {
        final data = FirebaseService.parseSensorData(event.snapshot);
        if (data != null) {
          setState(() {
            if (!isConnected && _wasConnected) {
              NotificationService.showConnectionRestoredNotification();
            }
            sensorData = SensorData.fromMap(data);
            soilData = SoilSensorData(
              moisture: data['soil_percent'] ?? 45.0,
              isPumpActive: data['pump']?.toString() == 'ON',
            );
            if (_lastModeChange == null) {
              isAutoMode = (data['mode']?.toString() ?? 'AUTO') == 'AUTO';
            }
            isConnected = true;
            _wasConnected = true;
          });
          FirebaseService.saveToHistory(data);
          _checkAlert();
        }
      },
      onError: (error) {
        setState(() {
          if (isConnected) NotificationService.showConnectionLostNotification();
          isConnected = false;
        });
      },
    );
  }

  // ==================== WAKE WORD CONTINU (mains-libres) ====================
  void _startContinuousWakeWordListening() {
    VoiceService.startContinuousListening(
      onWakeWord: (text) {
        setState(() => _isListening = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎤 Je vous écoute ! Parlez maintenant'),
            backgroundColor: _activeColor,
            duration: const Duration(seconds: 2),
          ),
        );
        _startCommandListeningSession();
      },
      onCommand:  (_) {},
    );
  }

  void _startCommandListeningSession() {
  // === CORRECTION IMPORTANTE ===
  // On arrête d'abord l'écoute continue (wake word)
  VoiceService.stopContinuousListening();

  setState(() => _isListening = true);

  VoiceService.startListening(
    onResult: (commandText) {
      setState(() => _isListening = false);

      final lower = commandText.toLowerCase().trim();

      // Commandes pour terminer la session
      if (lower.contains('arrête') ||
          lower.contains('stop') ||
          lower.contains('fin') ||
          lower.contains('merci rigoula') ||
          lower.contains('c\'est bon') ||
          lower.contains('ça suffit')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Session terminée'),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(milliseconds: 600),
            _startContinuousWakeWordListening);
        return;
      }

      _handleVoiceCommand(commandText);

      // On redémarre l'écoute continue après la commande
      Future.delayed(const Duration(milliseconds: 800),
          _startContinuousWakeWordListening);
    },
  );

  // Timeout de sécurité (12 secondes max pour parler)
  Future.delayed(const Duration(seconds: 12), () {
    if (_isListening && mounted) {
      setState(() => _isListening = false);
      VoiceService.stopListening();
      _startContinuousWakeWordListening();
    }
  });
}
  void _checkAlert() {
    final bool tempOut = !thresholdConfig.isTemperatureInRange(sensorData.temperature);
    final bool humOut = !thresholdConfig.isHumidityInRange(sensorData.humidity);
    final bool outOfRange = tempOut || humOut;

    if (outOfRange && !alertShown) {
      setState(() => alertShown = true);
      List<String> alerts = [];
      if (tempOut) {
        alerts.add('🌡️ Température: ${sensorData.temperature.toStringAsFixed(1)}°C');
        NotificationService.showTemperatureAlert(
          temperature: sensorData.temperature,
          min: thresholdConfig.tempMin,
          max: thresholdConfig.tempMax,
        );
      }
      if (humOut) {
        alerts.add('💧 Humidité: ${sensorData.humidity.toStringAsFixed(1)}%');
        NotificationService.showHumidityAlert(
          humidity: sensorData.humidity,
          min: thresholdConfig.humMin,
          max: thresholdConfig.humMax,
        );
      }
      if (alerts.length > 1) {
        NotificationService.showMultipleAlertsNotification(alerts: alerts);
      }
    } else if (!outOfRange && alertShown) {
      setState(() => alertShown = false);
    }
  }

  void _toggleMode() async {
    final newMode = isAutoMode ? "MANUEL" : "AUTO";
    final success = await FirebaseService.setMode(newMode);
    if (!mounted) return;
    if (success) {
      setState(() {
        isAutoMode = !isAutoMode;
        _lastModeChange = isAutoMode ? null : DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAutoMode ? '🤖 Mode AUTO activé' : '🕹️ Mode MANUEL activé'),
          backgroundColor: isAutoMode ? Colors.blue : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _togglePump() async {
    if (_pumpLoading || isAutoMode) return;
    setState(() => _pumpLoading = true);
    final newState = !soilData.isPumpActive;
    final success = await FirebaseService.setPumpCommand(newState);
    if (!mounted) return;
    if (success) {
      if (newState) FirebaseService.incrementPompeCount();
      NotificationService.showPumpNotification(isPumpActive: newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? '💧 Pompe ON' : '⛔ Pompe OFF'),
          backgroundColor: newState ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erreur envoi commande'), backgroundColor: Colors.orange),
      );
    }
    setState(() => _pumpLoading = false);
  }

  void _openSettings() async {
    await VoiceService.stopContinuousListening();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          currentConfig: thresholdConfig,
          onConfigSaved: (newConfig) {
            setState(() {
              thresholdConfig.tempMin = newConfig.tempMin;
              thresholdConfig.tempMax = newConfig.tempMax;
              thresholdConfig.humMin = newConfig.humMin;
              thresholdConfig.humMax = newConfig.humMax;
            });
            _checkAlert();
          },
        ),
      ),
    );
    if (mounted) _startContinuousWakeWordListening();
  }

  Future<void> _handleVoiceCommand(String text) async {
    final command = VoiceService.parseCommand(text);
    switch (command) {
      case VoiceCommand.pumpOn:
        if (!isAutoMode) _togglePump();
        _showVoiceSnack('💧 Pompe activée');
        break;
      case VoiceCommand.pumpOff:
        if (!isAutoMode) _togglePump();
        _showVoiceSnack('⛔ Pompe désactivée');
        break;
      case VoiceCommand.modeAuto:
        if (!isAutoMode) _toggleMode();
        _showVoiceSnack('🤖 Mode AUTO');
        break;
      case VoiceCommand.modeManuel:
        if (isAutoMode) _toggleMode();
        _showVoiceSnack('🕹️ Mode MANUEL');
        break;
      case VoiceCommand.openHistorique:
        Navigator.of(context).popUntil((route) => route.isFirst);
        await VoiceService.stopContinuousListening();
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriquePage()));
        if (mounted) _startContinuousWakeWordListening();
        break;
      case VoiceCommand.openSettings:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _openSettings();
        break;
      case VoiceCommand.slideTomate:
        _externalPageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🍅 Tomate');
        break;
      
      case VoiceCommand.slideAubergine:
        _externalPageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🍆 Aubergine');
        break;
      case VoiceCommand.slidePoivron:
        _externalPageController.animateToPage(2, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🫑 Poivron');
        break;
      case VoiceCommand.slideConcombre:
        _externalPageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        _showVoiceSnack('🥒 Concombre');
        break;
      case VoiceCommand.slideNext:
        final next = (_currentVegetableIndex + 1) % 4;
        _externalPageController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        break;
      case VoiceCommand.slidePrev:
        final prev = (_currentVegetableIndex - 1 + 4) % 4;
        _externalPageController.animateToPage(prev, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        break;
      case VoiceCommand.returnHome:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showVoiceSnack('🏠 Retour à la page d\'accueil');
      break;
      case VoiceCommand.unknown:
        _showVoiceSnack('❓ Non reconnue : "$text"');
        break;
    }
  }

  void _showVoiceSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), backgroundColor: _activeColor),
    );
  }

  @override
  void dispose() {
    VoiceService.stopContinuousListening();
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
                    Text("Rigoula", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                    const Text("Smart Farming", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Indicateur discret quand Rigoula écoute
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
                    Text("ÉCOUTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),

            // Bouton AUTO/MAN (inchangé)
            GestureDetector(
              onTap: _toggleMode,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _activeColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isAutoMode ? Icons.smart_toy : Icons.pan_tool, size: 12, color: _activeColor),
                    const SizedBox(width: 3),
                    Text(isAutoMode ? "AUTO" : "MAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _activeColor)),
                  ],
                ),
              ),
            ),

            // Bouton Historique (restauré)
            IconButton(
              icon: Icon(Icons.history, color: _activeColor, size: 22),
              onPressed: () async {
                await VoiceService.stopContinuousListening();
                if (!mounted) return;
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriquePage()));
                if (mounted) _startContinuousWakeWordListening();
              },
              tooltip: 'Historique',
            ),

            // Bouton Paramètres (restauré)
            IconButton(
              icon: Icon(Icons.settings, color: _activeColor, size: 22),
              onPressed: _openSettings,
              tooltip: 'Paramètres',
            ),

            // Statut ONLINE (inchangé)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isConnected ? Colors.green : Colors.red, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: isConnected ? Colors.green : Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Text(isConnected ? "ON" : "OFF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isConnected ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildModeBanner(),
              const SizedBox(height: 8),
              Expanded(
                child: VegetableSlider(
                  sensorData: sensorData,
                  soilData: soilData,
                  thresholdConfig: thresholdConfig,
                  onPumpToggle: (!isAutoMode && !_pumpLoading) ? _togglePump : () {},
                  onPageChanged: (index) => setState(() => _currentVegetableIndex = index),
                  isAutoMode: isAutoMode,
                  externalController: _externalPageController,
                ),
              ),
              if (alertShown) ...[
                const SizedBox(height: 12),
                const AlertBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _activeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isAutoMode ? Icons.smart_toy : Icons.pan_tool, color: _activeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAutoMode ? 'Mode AUTO — ESP32 gère la pompe' : 'Mode MANUEL — Vous contrôlez la pompe',
              style: TextStyle(fontSize: 12, color: _activeColor, fontWeight: FontWeight.w500),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: !isAutoMode,
              onChanged: (_) => _toggleMode(),
              activeColor: Colors.orange,
              inactiveThumbColor: _activeColor,
              inactiveTrackColor: _activeColor.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}