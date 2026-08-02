import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SttHelper {
  static final SpeechToText _speech = SpeechToText();
  static bool _isInitialized = false;
  static VoidCallback? _activeOnDone;
  static Function(String)? _activeOnResult;
  static VoidCallback? _activeOnListening;
  static String _lastRecognizedWords = "";
  static bool _isResultSent = false;

  /// Ses tanıma motorunu başlatır
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Durum: $status');
          if (status == 'listening') {
            _activeOnListening?.call();
          } else if (status == 'done' || status == 'notListening') {
            _finalizeRecognition();
          }
        },
        onError: (error) {
          debugPrint('STT Hata: $error');
          _finalizeRecognition();
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('STT Başlatma Hatası: $e');
      return false;
    }
  }

  /// Dinlemeyi bitirir ve sonucu kesinleştirir
  static void _finalizeRecognition() {
    if (!_isResultSent && _lastRecognizedWords.isNotEmpty && _activeOnResult != null) {
      _activeOnResult!(_lastRecognizedWords);
      _isResultSent = true;
    }

    if (_activeOnDone != null) {
      _activeOnDone!();
      _activeOnDone = null;
    }
    _activeOnListening = null;
  }

  /// Dinlemeyi başlatır
  static Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onDone,
    VoidCallback? onListeningStarted,
  }) async {
    bool ready = await initialize();
    if (!ready) {
      onDone();
      return;
    }

    _activeOnDone = onDone;
    _activeOnResult = onResult;
    _activeOnListening = onListeningStarted;
    _lastRecognizedWords = "";
    _isResultSent = false;

    await _speech.listen(
      onResult: (result) {
        _lastRecognizedWords = result.recognizedWords;
        if (result.finalResult) {
          _finalizeRecognition();
        }
      },
      localeId: 'tr-TR',
      listenFor: const Duration(seconds: 7),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
  }

  /// Dinlemeyi durdurur
  static Future<void> stopListening() async {
    await _speech.stop();
  }

  static bool get isListening => _speech.isListening;
}
