// lib/services/voice_service.dart
//
// Redesigned VoiceService:
//  • Initialises speech_to_text ONCE — avoids the beep caused by re-init.
//  • Session-based active mode: wake word → ACTIVE → commands → "stop"
//  • Auto-restarts listening only when session is active (no infinite loops).
//  • Lifecycle-aware: call VoiceService.pause() / resume() from
//    WidgetsBindingObserver in HomePage.
//  • Tunisian dialect commands added alongside French ones.

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:speech_to_text/speech_to_text.dart';

// ─── Public callback types ────────────────────────────────────────────────────
typedef OnSessionStarted = void Function();
typedef OnCommandReceived = void Function(VoiceCommand command, String raw);
typedef OnSessionEnded = void Function();

class VoiceService {
  VoiceService._(); // static-only — never instantiated

  // ── Singleton STT engine ──────────────────────────────────────────────────
  static final SpeechToText _speech = SpeechToText();
  static bool _isInitialized = false;

  // ── Session state ─────────────────────────────────────────────────────────
  /// True while the assistant is in "active command" mode.
  static bool _sessionActive = false;

  /// Prevents re-entrant restarts.
  static bool _isRestarting = false;

  /// Set to true when the app goes to background/paused — blocks restarts.
  static bool _appPaused = false;

  // ── Callbacks (set by HomePage) ───────────────────────────────────────────
  static OnSessionStarted? onSessionStarted;
  static OnCommandReceived? onCommandReceived;
  static OnSessionEnded?   onSessionEnded;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALISATION — called once from HomePage.initState()
  // ─────────────────────────────────────────────────────────────────────────
  /// Initialises the STT engine exactly once.
  /// Subsequent calls are no-ops, which prevents the Android "beep" that
  /// occurs when SpeechToText.initialize() is called repeatedly.
  static Future<bool> initialize() async {
    if (kIsWeb) return false;
    if (_isInitialized) return true; // ← single-init guard

    _isInitialized = await _speech.initialize(
      onError: _onError,
      onStatus: _onStatus,
      // debugLogging: false keeps the engine quiet
    );
    debugPrint(_isInitialized
        ? '🎤 VoiceService initialisé'
        : '❌ VoiceService: échec initialisation');
    return _isInitialized;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE HOOKS — called from WidgetsBindingObserver in HomePage
  // ─────────────────────────────────────────────────────────────────────────

  /// Call when AppLifecycleState becomes paused or detached.
  /// Stops the microphone immediately and blocks auto-restart.
  static Future<void> pause() async {
    if (kIsWeb) return;
    _appPaused = true;
    _isRestarting = false;
    if (_speech.isListening) {
      await _speech.stop();
      debugPrint('🔇 Micro arrêté (app en arrière-plan)');
    }
  }

  /// Call when AppLifecycleState becomes resumed.
  /// Resumes continuous listening only if a session was active before pause.
  static Future<void> resume() async {
    if (kIsWeb) return;
    _appPaused = false;
    debugPrint('🔊 App revenue au premier plan');
    if (_sessionActive) {
      await _startListening(); // resume active session
    } else {
      await _listenForWakeWord(); // resume idle wake-word scanning
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION CONTROL
  // ─────────────────────────────────────────────────────────────────────────

  /// Start idle wake-word scanning.
  /// The engine listens continuously; only the wake word triggers a session.
  static Future<void> startIdleListening() async {
    if (kIsWeb || !_isInitialized || _appPaused) return;
    _sessionActive = false;
    await _listenForWakeWord();
  }

  /// Called internally when the wake word is detected.
  static void _activateSession() {
    if (_sessionActive) return;
    _sessionActive = true;
    debugPrint('✅ Session vocale ACTIVE');
    onSessionStarted?.call();
  }

  /// Called internally when "stop / arrête" is heard inside a session.
  static Future<void> _deactivateSession() async {
    _sessionActive = false;
    _isRestarting = false;
    if (_speech.isListening) await _speech.stop();
    debugPrint('🔇 Session vocale TERMINÉE');
    onSessionEnded?.call();
    // Go back to idle wake-word scanning
    await Future.delayed(const Duration(milliseconds: 400));
    await _listenForWakeWord();
  }

  /// External stop — e.g. when navigating away or user taps stop button.
  static Future<void> stopSession() async {
    if (kIsWeb) return;
    await _deactivateSession();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNAL LISTENING LOOPS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _listenForWakeWord() async {
    if (kIsWeb || !_isInitialized || _appPaused) return;
    if (_speech.isListening) return;

    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final text = result.recognizedWords.toLowerCase().trim();
        if (text.isEmpty) return;
        debugPrint('👂 (idle) "$text"');

        if (_isWakeWord(text)) {
          _activateSession();
          // Don't stop — immediately process in active mode
          _restartIfNeeded();
        }
      },
      localeId: 'fr_FR',
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: false,
    );
  }

  static Future<void> _startListening() async {
    if (kIsWeb || !_isInitialized || _appPaused) return;
    if (_speech.isListening) return;

    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final text = result.recognizedWords.toLowerCase().trim();
        if (text.isEmpty) return;
        debugPrint('🎙️ (active) "$text"');

        // Stop command — highest priority
        if (_isStopCommand(text)) {
          _deactivateSession();
          return;
        }

        // Wake word mid-session — just confirm and keep going
        if (_isWakeWord(text)) {
          _restartIfNeeded();
          return;
        }

        // Parse and dispatch the command
        final cmd = parseCommand(text);
        onCommandReceived?.call(cmd, text);
        _restartIfNeeded();
      },
      localeId: 'fr_FR',
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STT ENGINE CALLBACKS
  // ─────────────────────────────────────────────────────────────────────────

  static void _onStatus(String status) {
    debugPrint('🔵 STT status: $status');
    // When the engine goes idle, restart the appropriate loop
    if (status == 'done' || status == 'notListening') {
      _restartIfNeeded();
    }
  }

  static void _onError(dynamic error) {
    final msg = error.toString().toLowerCase();
    debugPrint('❌ STT erreur: $msg');
    // error_no_match = silence timeout → restart normally
    if (msg.contains('error_no_match') || msg.contains('error_speech_timeout')) {
      _restartIfNeeded();
    }
    // error_recognizer_busy → wait a bit longer
    if (msg.contains('error_recognizer_busy')) {
      Future.delayed(const Duration(milliseconds: 1000), _restartIfNeeded);
    }
  }

  // Debounced restart — prevents concurrent restarts
  static void _restartIfNeeded() {
    if (_appPaused || _isRestarting) return;
    _isRestarting = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _isRestarting = false;
      if (_appPaused || _speech.isListening) return;
      if (_sessionActive) {
        _startListening();
      } else {
        _listenForWakeWord();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KEYWORD MATCHERS
  // ─────────────────────────────────────────────────────────────────────────

  static bool _isWakeWord(String text) {
    return text.contains('rigoula') ||
        text.contains('salut rigoula') ||
        text.contains('bonjour rigoula') ||
        text.contains('start') ||
        text.contains('démarre') ||
        text.contains('هيا') || // Tunisian: "yalla"
        text.contains('yalla');
  }

  static bool _isStopCommand(String text) {
    return text.contains('stop') ||
        text.contains('arrête') ||
        text.contains('arrete') ||
        text.contains('fin') ||
        text.contains('merci rigoula') ||
        text.contains('c\'est bon') ||
        text.contains('wqef') || // Tunisian: "stop/halt"
        text.contains('barcha');  // Tunisian: "enough"
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMAND PARSER
  // Supports French + Tunisian dialect keywords
  // ─────────────────────────────────────────────────────────────────────────
  static VoiceCommand parseCommand(String text) {
    text = text.toLowerCase().trim();
    debugPrint('🔍 Parse: "$text"');

    // ── PUMP ON ─────────────────────────────────────────────────────────────
    // French: "démarre la pompe", "activer la pompe", "pompe on"
    // Tunisian: "khadem lpompe", "chaghel lpompe"
    if (text.contains('khadem') ||       // TN: run / activate
        text.contains('chaghel') ||      // TN: operate / start
        text.contains('chaghal') ||
        (text.contains('pompe') &&
            (text.contains('activ') ||
             text.contains('on') ||
             text.contains('marche') ||
             text.contains('démarre') ||
             text.contains('start')))) {
      return VoiceCommand.pumpOn;
    }

    // ── PUMP OFF ────────────────────────────────────────────────────────────
    // French: "arrête la pompe", "désactiver la pompe", "pompe off"
    // Tunisian: "saker lpompe", "oqef lpompe"
    if (text.contains('saker') ||        // TN: close/stop
        text.contains('sakker') ||
        text.contains('oqef') ||         // TN: stop/halt
        text.contains('wqef') ||
        (text.contains('pompe') &&
            (text.contains('désactiv') ||
             text.contains('off') ||
             text.contains('arrêt') ||
             text.contains('coupe')))) {
      return VoiceCommand.pumpOff;
    }

    // ── MODES ────────────────────────────────────────────────────────────────
    if (text.contains('auto') || text.contains('automatique')) {
      return VoiceCommand.modeAuto;
    }
    if (text.contains('manuel') || text.contains('yadawi')) { // TN: manual
      return VoiceCommand.modeManuel;
    }

    // ── NAVIGATION ───────────────────────────────────────────────────────────
    if (text.contains('histori') || text.contains('historique')) {
      return VoiceCommand.openHistorique;
    }
    if (text.contains('paramètre') ||
        text.contains('setting') ||
        text.contains('config') ||
        text.contains('idadet')) { // TN: settings
      return VoiceCommand.openSettings;
    }

    // ── SLIDES ───────────────────────────────────────────────────────────────
    if (text.contains('tomate') || text.contains('accueil') || text.contains('home')) {
      return VoiceCommand.slideTomate;
    }
    if (text.contains('cerise')) return VoiceCommand.slideTomate; // tomate cerise = slide 1
    if (text.contains('suivant') || text.contains('prochain') || text.contains('li baad')) {
      return VoiceCommand.slideNext;
    }
    if (text.contains('précédent') || text.contains('retour') || text.contains('li qbal')) {
      return VoiceCommand.slidePrev;
    }

    return VoiceCommand.unknown;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────
  static bool get isListening   => kIsWeb ? false : _speech.isListening;
  static bool get isSessionActive => _sessionActive;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMANDS ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum VoiceCommand {
  pumpOn,
  pumpOff,
  modeAuto,
  modeManuel,
  openHistorique,
  openSettings,
  slideTomate,
  slidecerise,
  slideNext,
  slidePrev,
  returnHome,
  unknown,
}