/// One learnable language, described in `assets/content/config.json`.
class LanguageOption {
  final String code;

  /// English display name, e.g. "Bengali".
  final String name;

  /// The language's own script name, e.g. "বাংলা" — shown in the picker.
  final String nativeName;

  /// Content asset file name, e.g. "content.bn.json".
  final String file;

  /// Preferred text-to-speech locales, best first (e.g. `bn-IN`, `ja-JP`).
  final List<String> ttsLocales;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.file,
    required this.ttsLocales,
  });

  factory LanguageOption.fromJson(Map<String, dynamic> json) => LanguageOption(
        code: json['code'] as String,
        name: json['name'] as String,
        nativeName: (json['nativeName'] ?? json['name']) as String,
        file: json['file'] as String,
        ttsLocales:
            (json['ttsLocales'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

/// The multi-language config: which languages exist and which is the default.
class AppConfig {
  final String defaultLanguageCode;
  final List<LanguageOption> languages;

  const AppConfig({
    required this.defaultLanguageCode,
    required this.languages,
  });

  /// The language with the given [code], or null if it isn't configured.
  LanguageOption? languageForCode(String? code) {
    if (code == null) return null;
    for (final language in languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// The configured default, falling back to the first available language.
  LanguageOption get defaultLanguage =>
      languageForCode(defaultLanguageCode) ?? languages.first;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final languages = (json['languages'] as List)
        .map((e) => LanguageOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return AppConfig(
      defaultLanguageCode: (json['defaultLanguage'] as String?) ??
          (languages.isNotEmpty ? languages.first.code : ''),
      languages: languages,
    );
  }
}
