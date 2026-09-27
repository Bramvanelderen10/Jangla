/// The target language a course teaches, described by the `language` block of
/// a course file. A course's own display name lives on [Course]; this is only
/// what the app needs to recognise and speak the language.
class LanguageOption {
  /// Short language code, e.g. "ja". Drives text-to-speech and is the fallback
  /// identity when a course name cannot be turned into a slug.
  final String code;

  /// The language's own script name, e.g. "日本語" — shown as the subtitle in
  /// the picker so a themed course is recognisable by language.
  final String nativeName;

  /// Preferred text-to-speech locales, best first (e.g. `ja-JP`, `bn-IN`).
  final List<String> ttsLocales;

  const LanguageOption({
    required this.code,
    required this.nativeName,
    required this.ttsLocales,
  });

  factory LanguageOption.fromJson(Map<String, dynamic> json) => LanguageOption(
    code: (json['code'] ?? '') as String,
    nativeName: (json['nativeName'] ?? '') as String,
    ttsLocales:
        (json['ttsLocales'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'nativeName': nativeName,
    'ttsLocales': ttsLocales,
  };
}
