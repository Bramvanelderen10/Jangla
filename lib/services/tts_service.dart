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

  /// Picks the best available Bengali locale as the engine reports it, so we use
  /// whatever exact tag the device expects (Android may report `bn-IN`, `bn_IN`,
  /// `ben-IND`, etc.). Prefers the India (Kolkata) variant the content uses,
  /// then Bangladesh, then any Bengali. Returns null if none is installed.
  Future<String?> _resolveBengaliLanguage() async {
    List<String> langs = const [];
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        langs = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // getLanguages unsupported; fall through to direct probing below.
    }

    final bengali = langs.where(_isBengali).toList();
    // Prefer India, then Bangladesh, then any Bengali variant.
    for (final match in [
      bengali.where(_isIndia),
      bengali.where(_isBangladesh),
      bengali,
    ]) {
      if (match.isNotEmpty) return match.first;
    }

    // Fallback: probe common tags directly if the language list was empty.
    for (final lang in const ['bn-IN', 'bn_IN', 'bn-BD', 'bn']) {
      try {
        final available = await _tts.isLanguageAvailable(lang);
        if (available == true || available == 1) return lang;
      } catch (_) {
        // Try the next candidate.
      }
    }
    return null;
  }

  /// Splits a locale tag on `-`/`_` and lowercases the parts.
  static List<String> _localeParts(String locale) =>
      locale.toLowerCase().split(RegExp('[-_]'));

  static bool _isBengali(String locale) {
    final lang = _localeParts(locale).first;
    return lang == 'bn' || lang == 'ben';
  }

  static bool _isIndia(String locale) {
    final parts = _localeParts(locale);
    return parts.contains('in') || parts.contains('ind');
  }

  static bool _isBangladesh(String locale) {
    final parts = _localeParts(locale);
    return parts.contains('bd') || parts.contains('bgd');
  }

  /// Explicitly bind a Bengali voice for the chosen language when one exists.
  /// setLanguage alone is sometimes not enough to override a default voice.
  Future<void> _selectBengaliVoice(String language) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final wantIndia = _isIndia(language);
      Map? match;
      for (final v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString();
          if (!_isBengali(locale)) continue;
          // Exact preference: a Bengali-India voice when we chose India.
          if (wantIndia && _isIndia(locale)) {
            match = v;
            break;
          }
          match ??= v;
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
