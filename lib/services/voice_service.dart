
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:speech_to_text/speech_to_text.dart';

typedef OnSessionStarted  = void Function();
typedef OnCommandReceived = void Function(VoiceCommand command, String raw);
typedef OnSessionEnded    = void Function();

class VoiceService {
  VoiceService._();

  static final SpeechToText _speech = SpeechToText();
  static bool _isInitialized  = false;
  static bool _sessionActive  = false;
  static bool _isRestarting   = false;
  static bool _appPaused      = false;

  static OnSessionStarted?  onSessionStarted;
  static OnCommandReceived? onCommandReceived;
  static OnSessionEnded?    onSessionEnded;

  static Future<bool> initialize() async {
    if (kIsWeb) return false;
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError:  _onError,
      onStatus: _onStatus,
    );
    debugPrint(_isInitialized
        ? '🎤 VoiceService initialisé'
        : '❌ VoiceService: échec initialisation');
    return _isInitialized;
  }

  static Future<void> pause() async {
    if (kIsWeb) return;
    _appPaused    = true;
    _isRestarting = false;
    if (_speech.isListening) await _speech.stop();
  }

  static Future<void> resume() async {
    if (kIsWeb) return;
    _appPaused = false;
    if (_sessionActive) {
      await _startListening();
    } else {
      await _listenForWakeWord();
    }
  }

  static Future<void> startIdleListening() async {
    if (kIsWeb || !_isInitialized || _appPaused) return;
    _sessionActive = false;
    await _listenForWakeWord();
  }

  static void _activateSession() {
    if (_sessionActive) return;
    _sessionActive = true;
    onSessionStarted?.call();
  }

  static Future<void> _deactivateSession() async {
    _sessionActive = false;
    _isRestarting  = false;
    if (_speech.isListening) await _speech.stop();
    onSessionEnded?.call();
    await Future.delayed(const Duration(milliseconds: 400));
    await _listenForWakeWord();
  }

  static Future<void> stopSession() async {
    if (kIsWeb) return;
    await _deactivateSession();
  }

  static Future<void> _listenForWakeWord() async {
    if (kIsWeb || !_isInitialized || _appPaused) return;
    if (_speech.isListening) return;
    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final text = result.recognizedWords.toLowerCase().trim();
        if (text.isEmpty) return;
        if (_isWakeWord(text)) {
          _activateSession();
          _restartIfNeeded();
        }
      },
      localeId:      'fr_FR',
      listenMode:    ListenMode.dictation,
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
        if (_isStopCommand(text)) { _deactivateSession(); return; }
        if (_isWakeWord(text))    { _restartIfNeeded();   return; }
        final cmd = parseCommand(text);
        onCommandReceived?.call(cmd, text);
        _restartIfNeeded();
      },
      localeId:      'fr_FR',
      listenMode:    ListenMode.dictation,
      cancelOnError: false,
      partialResults: false,
    );
  }

  static void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') _restartIfNeeded();
  }

  static void _onError(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('error_no_match') || msg.contains('error_speech_timeout')) {
      _restartIfNeeded();
    }
    if (msg.contains('error_recognizer_busy')) {
      Future.delayed(const Duration(milliseconds: 1000), _restartIfNeeded);
    }
  }

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

  static bool _isWakeWord(String text) {
    return text.contains('rigolo')  || text.contains('rigola')  ||  text.contains('rigoula') || text.contains('salut rigoula') || text.contains('bonjour rigoula') || text.contains('start') ||
           text.contains('démarre');
  }

  static bool _isStopCommand(String text) {
    return text.contains('stop') || text.contains('arrête') || text.contains('arrete') || text.contains('fin') || text.contains('merci rigoula') || text.contains('c\'est bon') ;
  }
  static VoiceCommand parseCommand(String text) {
    text = text.toLowerCase().trim();
    debugPrint('Parse: "$text"');

    if ( (text.contains('pompe') &&
            (text.contains('démarre')||text.contains('activ')  || text.contains('on') || text.contains('marche') || text.contains('démarre')|| text.contains('start')))) {
      return VoiceCommand.pumpOn;
    }

    if (text.contains('saker')  ||
        text.contains('sakker') ||
        text.contains('oqef')   ||
        text.contains('wqef')   ||
        (text.contains('pompe') &&
            (text.contains('désactiv') ||
             text.contains('off')      ||
             text.contains('arrêt')    ||
             text.contains('coupe')))) {
      return VoiceCommand.pumpOff;
    }
    if (text.contains('hel') || (text.contains('ev') || text.contains('électrovanne') || text.contains('electrovanne')) && (text.contains('ouvr')  || text.contains('on') || text.contains('activ') || text.contains('démarre'))) {
  return VoiceCommand.evOpen;
    }
    if (text.contains('sakker') ||  text.contains('saker') ||(text.contains('ev') || text.contains('électrovanne') || text.contains('electrovanne')) && (text.contains('ferm')  ||
         text.contains('off') ||
         text.contains('arrêt') ||
         text.contains('coupe'))) {
  return VoiceCommand.evClose;
}

    if (text.contains('auto') || text.contains('automatique')) {
      return VoiceCommand.modeAuto;
    }
    if (text.contains('manuel') || text.contains('yadawi')) {
      return VoiceCommand.modeManuel;
    }

    if (text.contains('histori') || text.contains('historique')) {
      return VoiceCommand.openHistorique;
    }
    if (text.contains('paramètre') ||
        text.contains('setting')   ||
        text.contains('config')    ||
        text.contains('idadet')) {
      return VoiceCommand.openSettings;
    }

    if (text.contains('accueil') || text.contains('home')) {
      return VoiceCommand.returnHome;
    }

    if (text.contains('cerise')) {
      return VoiceCommand.slidecerise;             
    }
    if (text.contains('tomate')) {
      return VoiceCommand.slideTomate;
    }

    if (text.contains('suivant') ||
        text.contains('prochain') ||
        text.contains('li baad')) {
      return VoiceCommand.slideNext;
    }
    if (text.contains('précédent') ||
        text.contains('retour')    ||
        text.contains('li qbal')) {
      return VoiceCommand.slidePrev;
    }

    return VoiceCommand.unknown;
  }

  static bool get isListening    => kIsWeb ? false : _speech.isListening;
  static bool get isSessionActive => _sessionActive;
}

enum VoiceCommand {
  pumpOn,
  pumpOff,
  modeAuto,
  modeManuel,
  evOpen,     
  evClose,
  openHistorique,
  openSettings,
  slideTomate,
  slidecerise,
  slideNext,
  slidePrev,
  returnHome,
  unknown,
}