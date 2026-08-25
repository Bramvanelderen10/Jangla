import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts for speaking Bengali text.
///
/// The main pitfall this guards against: if the device has no Bengali voice,
/// flutter_tts silently falls back to the default (usually English) engine,
/// which then "spells out" the Bengali script with English phonetics. To avoid
/// that garbage we only speak once we've confirmed a real Bengali voice is
/// selected, and we pick the best available Bengali locale (preferring the
/// West Bengal / Kolkata `bn-IN` variant the content is written in).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _bengaliAvailable = false;
  String? _language;

  /// Bengali locales in order of preference. The content uses the West Bengal
  /// (Kolkata) variant, so `bn-IN` sounds most correct; fall back to Bangladesh
  /// and the bare language tag.
  static const List<String> _preferredLanguages = ['bn-IN', 'bn-BD', 'bn'];

  /// Whether a genuine Bengali voice was found and selected.
  bool get bengaliAvailable => _bengaliAvailable;

  Future<void> init() async {
    try {
      final chosen = await _resolveBengaliLanguage();
      if (chosen != null) {
        await _tts.setLanguage(chosen);
        await _selectBengaliVoice(chosen);
        _language = chosen;
        _bengaliAvailable = true;
      } else {
        _bengaliAvailable = false;
      }
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
      _bengaliAvailable = false;
    }
  }

  /// Returns the first preferred Bengali locale the engine reports as available,
  /// or null if the device has no Bengali voice installed.
  Future<String?> _resolveBengaliLanguage() async {
    for (final lang in _preferredLanguages) {
      try {
        final available = await _tts.isLanguageAvailable(lang);
        // Android returns a bool; iOS may return an int/other truthy value.
        if (available == true || available == 1) return lang;
      } catch (_) {
        // Ignore and try the next candidate.
      }
    }
    return null;
  }

  /// Explicitly bind a Bengali voice for the chosen language when one exists.
  /// setLanguage alone is sometimes not enough to override a default voice.
  Future<void> _selectBengaliVoice(String language) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final langLower = language.toLowerCase();
      final prefix = langLower.split('-').first; // e.g. "bn"
      Map? match;
      for (final v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          if (locale == langLower) {
            match = v;
            break;
          }
          if (match == null && locale.startsWith(prefix)) {
            match = v;
          }
        }
      }
      if (match != null) {
        await _tts.setVoice({
          'name': match['name'].toString(),
          'locale': match['locale'].toString(),
        });
      }
    } catch (_) {
      // Voice selection is best-effort; language is already set.
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_ready) await init();
      // No Bengali voice: speaking would spell the script in English. Skip it
      // rather than produce garbage.
      if (!_bengaliAvailable) return;
      await _tts.stop();
      if (_language != null) await _tts.setLanguage(_language!);
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
