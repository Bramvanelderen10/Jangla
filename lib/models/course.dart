import '../services/course_id.dart';
import 'language.dart';

/// Where a course's content came from: shipped in the app, or imported by the
/// user from a picked JSON file.
enum LanguageSource { bundled, imported }

/// One self-describing course file: the lessons plus the metadata that used to
/// live in `config.json` (`name` and the `language` block).
///
/// The bundled asset files and user uploads are the very same shape; the only
/// difference is [source] and where the bytes are read from.
class Course {
  /// Display name of the course, e.g. "Japanage" or "Business Japanese".
  final String name;

  /// The language the course teaches (code, native name, TTS locales).
  final LanguageOption language;

  /// The full course file text, decoded lazily by the repository.
  final String rawJson;

  final LanguageSource source;

  /// True for the bundled course that should be shown before the user picks
  /// one (the old `config.json` `defaultLanguage`).
  final bool isDefault;

  /// Asset path — set for bundled courses, null for imports.
  final String? assetPath;

  /// When the user imported this course (imports only).
  final DateTime? importedAt;

  /// The picked file's name (imports only), kept for display/debugging.
  final String? originalFileName;

  const Course({
    required this.name,
    required this.language,
    required this.rawJson,
    required this.source,
    this.isDefault = false,
    this.assetPath,
    this.importedAt,
    this.originalFileName,
  });

  /// Stable identity used for the picker selection, the `shared_preferences`
  /// selection key and the progress namespace. Falls back to the language code
  /// when the name has no letters/digits to slug.
  String get id {
    final slug = slugifyCourseName(name);
    return slug.isEmpty ? language.code : slug;
  }

  bool get isBundled => source == LanguageSource.bundled;

  /// Persistence form for user imports (bundled courses are never stored).
  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language.toJson(),
    'rawJson': rawJson,
    'isDefault': isDefault,
    if (importedAt != null) 'importedAt': importedAt!.toIso8601String(),
    if (originalFileName != null) 'originalFileName': originalFileName,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    name: json['name'] as String,
    language: LanguageOption.fromJson(
      (json['language'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
    ),
    rawJson: (json['rawJson'] ?? '') as String,
    source: LanguageSource.imported,
    isDefault: (json['isDefault'] ?? false) as bool,
    importedAt:
        json['importedAt'] == null
            ? null
            : DateTime.tryParse(json['importedAt'] as String),
    originalFileName: json['originalFileName'] as String?,
  );
}
