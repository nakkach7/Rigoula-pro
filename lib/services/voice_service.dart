import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static bool _isInitialized = false;
  static bool _continuousMode = false;
  static Function(String)? _onWakeWordCallback;
  static Function(String)? _onCommandCallback;
  static bool _isRestarting = false;

  static Future<bool> initialize() async {
    if (kIsWeb) return false; // Pas de reconnaissance vocale sur web
    if (_isInitialized) return true;

    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('❌ Erreur vocale: $error');
        _handleSpeechError(error);
      },
      onStatus: (status) {
        debugPrint('🎤 Status: $status');
        if (_continuousMode &&
            (status == 'done' || status == 'notListening') &&
            !_isRestarting) {
          _isRestarting = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            _isRestarting = false;
            _restartContinuousListening();
          });
        }
      },
    );
    return _isInitialized;
  }

  static bool get isListening => kIsWeb ? false : _speech.isListening;

  static Future<void> startContinuousListening({
    required Function(String) onWakeWord,
    required Function(String) onCommand,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await initialize();

    _continuousMode = true;
    _onWakeWordCallback = onWakeWord;
    _onCommandCallback = onCommand;

    await _listenForWakeWord();
  }

  static Future<void> _listenForWakeWord() async {
    if (kIsWeb || !_isInitialized) return;
    if (_speech.isListening) return; // ✅ Évite le double start

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.toLowerCase().trim();
          debugPrint('🎤 Entendu (continuous): "$text"');

          if (text.contains('bonjour rigoula') ||
              text.contains('salut rigoula') ||
              text.contains('rigoula') ||
              text.contains('salut')) {
            debugPrint('✅ Wake word détecté !');
            _onWakeWordCallback?.call(text);
          } else if (text.isNotEmpty && _onCommandCallback != null) {
            _onCommandCallback!.call(text);
          }
        }
      },
      localeId: 'fr_FR',
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: false,
    );
  }

  static void _restartContinuousListening() {
    if (kIsWeb || !_continuousMode || !_isInitialized) return;
    if (_speech.isListening) return; // ✅ Évite le double start
    debugPrint('🔄 Redémarrage automatique de l\'écoute continue...');
    _listenForWakeWord();
  }

  static void _handleSpeechError(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('error_no_match') && _continuousMode && !_isRestarting) {
      _isRestarting = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        _isRestarting = false;
        _restartContinuousListening();
      });
    }
  }

  static Future<void> startListening({
    required Function(String) onResult,
  }) async {
    if (kIsWeb || !_isInitialized) return;
    if (_speech.isListening) await _speech.stop();

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.toLowerCase().trim();
          debugPrint('🎤 Commande reçue : "$text"');
          onResult(text);
        }
      },
      localeId: 'fr_FR',
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      partialResults: false,
    );
  }

  static Future<void> stopListening() async {
    if (kIsWeb) return;
    await _speech.stop();
  }

  static Future<void> stopContinuousListening() async {
    if (kIsWeb) return;
    _continuousMode = false;
    _isRestarting = false;
    await _speech.stop();
  }

  static VoiceCommand parseCommand(String text) {
    debugPrint('🎤 Analyse commande: "$text"');
    text = text.toLowerCase();

    if (text.contains('pompe') || text.contains('pump')) {
      if (text.contains('activ') || text.contains('on') ||
          text.contains('marche') || text.contains('démarre')) {
        return VoiceCommand.pumpOn;
      }
      if (text.contains('désactiv') || text.contains('off') ||
          text.contains('arrêt') || text.contains('stop')) {
        return VoiceCommand.pumpOff;
      }
    }
    if (text.contains('auto') || text.contains('automatique')) {
      return VoiceCommand.modeAuto;
    }
    if (text.contains('manuel')) return VoiceCommand.modeManuel;
    if (text.contains('histori')) return VoiceCommand.openHistorique;
    if (text.contains('paramètre') || text.contains('setting') ||
        text.contains('config')) return VoiceCommand.openSettings;
    if (text.contains('tomate') || text.contains('home') ||
        text.contains('acceuil')) return VoiceCommand.slideTomate;
    if (text.contains('aubergine')) return VoiceCommand.slideAubergine;
    if (text.contains('poivron')) return VoiceCommand.slidePoivron;
    if (text.contains('concombre')) return VoiceCommand.slideConcombre;
    if (text.contains('suivant') || text.contains('prochain')) {
      return VoiceCommand.slideNext;
    }
    if (text.contains('précédent')) return VoiceCommand.slidePrev;
    if (text.contains('retour') || text.contains('accueil') ||
        text.contains('principale')) return VoiceCommand.returnHome;

    return VoiceCommand.unknown;
  }
}

enum VoiceCommand {
  pumpOn, pumpOff, modeAuto, modeManuel,
  openHistorique, openSettings,
  slideTomate, slideAubergine, slidePoivron, slideConcombre,
  slideNext, slidePrev, returnHome, unknown,
}