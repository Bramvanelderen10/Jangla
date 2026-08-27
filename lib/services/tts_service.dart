import 'package:flutter_tts/flutter_tts.dart';

import '../models/language.dart';

/// Thin wrapper around flutter_tts for speaking the target-language text of a
/// selected [LanguageOption] (Bengali, Japanese, ...).
///
/// The main pitfall this guards against: if the device has no voice for the
/// target language, flutter_tts silently falls back to the default (usually
/// English) engine, which then "spells out" the foreign script with English
/// phonetics. To avoid that garbage we only speak once we've confirmed a real
/// voice for the language is selected, picking the best available locale from
/// the language's configured [LanguageOption.ttsLocales] (ordered by
/// preference, best first).
class TtsService {
  TtsService(this.language);

  final LanguageOption language;
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _voiceAvailable = false;
  String? _resolvedLocale;

  /// English display name of the language being spoken (for UI labels).
  String get languageName => language.name;

  /// Whether a genuine voice for the language was found and selected.
  bool get voiceAvailable => _voiceAvailable;

  Future<void> init() async {
    try {
      final chosen = await _resolveLocale();
      if (chosen != null) {
        await _tts.setLanguage(chosen);
        await _selectVoice(chosen);
        _resolvedLocale = chosen;
        _voiceAvailable = true;
      } else {
        _voiceAvailable = false;
      }
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
      _voiceAvailable = false;
    }
  }

  /// Picks the best available locale for the language as the engine reports it,
  /// so we use whatever exact tag the device expects (Android may report
  /// `bn-IN`, `bn_IN`, `ja-JP`, `ja_JP`, etc.). Candidates in
  /// [LanguageOption.ttsLocales] are tried in order of preference. Returns null
  /// if none is installed.
  Future<String?> _resolveLocale() async {
    List<String> langs = const [];
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        langs = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // getLanguages unsupported; fall through to direct probing below.
    }

    for (final preferred in language.ttsLocales) {
      for (final available in langs) {
        if (_localeMatches(available, preferred)) return available;
      }
    }

    // Fallback: probe the preferred tags directly if the language list was empty.
    for (final preferred in language.ttsLocales) {
      try {
        final available = await _tts.isLanguageAvailable(preferred);
        if (available == true || available == 1) return preferred;
      } catch (_) {
        // Try the next candidate.
      }
    }
    return null;
  }

  /// Splits a locale tag on `-`/`_` and lowercases the parts.
  static List<String> _localeParts(String locale) =>
      locale.toLowerCase().split(RegExp('[-_]'));

  /// True when [candidate] satisfies [preferred]: the language subtag must
  /// match, and if [preferred] names a region that region must match too.
  static bool _localeMatches(String candidate, String preferred) {
    final c = _localeParts(candidate);
    final p = _localeParts(preferred);
    if (c.isEmpty || p.isEmpty || c.first != p.first) return false;
    if (p.length < 2) return true; // language-only preference
    return c.contains(p[1]);
  }

  /// Explicitly bind a voice matching the chosen locale when one exists.
  /// setLanguage alone is sometimes not enough to override a default voice.
  Future<void> _selectVoice(String locale) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final wanted = _localeParts(locale);
      Map? match;
      for (final v in voices) {
        if (v is Map) {
          final voiceLocale = (v['locale'] ?? '').toString();
          final parts = _localeParts(voiceLocale);
          if (parts.isEmpty || parts.first != wanted.first) continue;
          // Prefer a voice whose region also matches the chosen locale.
          if (wanted.length > 1 && parts.contains(wanted[1])) {
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
      // No matching voice: speaking would spell the script in English. Skip it
      // rather than produce garbage.
      if (!_voiceAvailable) return;
      await _tts.stop();
      if (_resolvedLocale != null) await _tts.setLanguage(_resolvedLocale!);
      await _tts.speak(text);
    } catch (_) {
      // Ignore playback errors (e.g. no matching voice installed).
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
