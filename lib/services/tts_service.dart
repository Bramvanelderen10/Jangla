import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts for speaking Bengali text.
/// Fails silently if TTS is unavailable on the device.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setLanguage('bn-BD');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_ready) await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore playback errors (e.g. no Bengali voice installed).
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
