import 'dart:convert';

import '../models/course.dart';
import '../models/language.dart';
import 'course_id.dart';

/// The outcome of parsing a course file: either a usable [Course] or a list of
/// human-readable problems the user can act on.
class ImportResult {
  final Course? course;
  final List<String> errors;

  const ImportResult.success(Course this.course) : errors = const [];

  const ImportResult.failure(this.errors) : course = null;

  bool get ok => course != null;
}

/// The single parsing/validation pipeline used for **both** the bundled asset
/// files and user-uploaded files, so the two can never drift apart.
class LanguageImport {
  /// Upper bound for a course file (characters of JSON text).
  static const int maxChars = 2 * 1024 * 1024;

  /// Max problems reported back before the list is truncated.
  static const int _maxErrors = 8;

  /// Parses [rawJson]. [existingIds] are the ids already installed (bundled and
  /// imported); a collision is reported so the user can rename the course.
  static ImportResult parse(
    String rawJson, {
    required LanguageSource source,
    String? fileName,
    String? assetPath,
    DateTime? importedAt,
    Set<String> existingIds = const {},
  }) {
    if (rawJson.trim().isEmpty) {
      return const ImportResult.failure(['The file is empty.']);
    }
    if (rawJson.length > maxChars) {
      return const ImportResult.failure(['The file is too large (limit 2 MB).']);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      return const ImportResult.failure([
        'This is not valid JSON. Check for a missing comma or bracket.',
      ]);
    }
    if (decoded is! Map<String, dynamic>) {
      return const ImportResult.failure([
        'The file must contain a JSON object at the top level.',
      ]);
    }
    final json = decoded;

    final errors = <String>[];
    var truncated = false;
    void addError(String message) {
      if (errors.length < _maxErrors) {
        errors.add(message);
      } else {
        truncated = true;
      }
    }

    // --- root name ---------------------------------------------------------
    final name = (json['name'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty) {
      addError(
        'Add a "name" at the top level, e.g. "Japanese" or "Business Japanese".',
      );
    }

    // --- language block ----------------------------------------------------
    var code = '';
    var nativeName = name;
    var ttsLocales = const <String>[];
    final languageJson = json['language'];
    if (languageJson is! Map<String, dynamic>) {
      addError('Add a "language" object with at least a "code", e.g. "ja".');
    } else {
      code = (languageJson['code'] as Object?)?.toString().trim() ?? '';
      if (code.isEmpty) {
        addError('The "language" object needs a "code", e.g. "ja".');
      }
      final native = (languageJson['nativeName'] as Object?)?.toString().trim();
      if (native != null && native.isNotEmpty) nativeName = native;
      final locales =
          (languageJson['ttsLocales'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
      ttsLocales =
          (locales != null && locales.isNotEmpty)
              ? locales
              : (code.isEmpty ? const [] : [code]);
    }

    // --- content shape -----------------------------------------------------
    final categories = json['categories'];
    if (categories is! List || categories.isEmpty) {
      addError('Add a non-empty "categories" list.');
    } else {
      _validateCategories(categories, addError);
    }

    if (truncated) {
      addError('…and more problems further down.');
    }
    if (errors.isNotEmpty) return ImportResult.failure(errors);

    // --- identity ----------------------------------------------------------
    final slug = slugifyCourseName(name);
    final id = slug.isEmpty ? code : slug;
    if (existingIds.contains(id)) {
      return ImportResult.failure([
        'A course named "$name" is already installed. '
            'Give this one a different "name".',
      ]);
    }

    final languageFinal = json['language'] as Map<String, dynamic>;
    return ImportResult.success(
      Course(
        name: name,
        language: LanguageOption(
          code: code,
          nativeName: nativeName,
          ttsLocales: ttsLocales,
        ),
        rawJson: rawJson,
        source: source,
        isDefault: languageFinal['default'] == true,
        assetPath: assetPath,
        importedAt: importedAt,
        originalFileName: fileName,
      ),
    );
  }

  /// Walks `categories -> lessons -> entries` and reports the first problems.
  static void _validateCategories(
    List<dynamic> categories,
    void Function(String) addError,
  ) {
    for (var ci = 0; ci < categories.length; ci++) {
      final category = categories[ci];
      if (category is! Map<String, dynamic>) {
        addError('Category ${ci + 1} must be an object.');
        continue;
      }
      final categoryTitle = (category['title'] as Object?)?.toString();
      final lessons = category['lessons'];
      if (lessons is! List || lessons.isEmpty) {
        addError('Category "${categoryTitle ?? ci + 1}" has no lessons.');
        continue;
      }
      for (var li = 0; li < lessons.length; li++) {
        final lesson = lessons[li];
        if (lesson is! Map<String, dynamic>) {
          addError('Lesson ${li + 1} must be an object.');
          continue;
        }
        final lessonTitle = (lesson['title'] as Object?)?.toString();
        final lessonLabel = lessonTitle ?? '${li + 1}';
        final entries = lesson['entries'];
        if (entries is! List || entries.isEmpty) {
          addError('Lesson "$lessonLabel" has no entries.');
          continue;
        }
        for (var ei = 0; ei < entries.length; ei++) {
          final entry = entries[ei];
          if (entry is! Map<String, dynamic>) {
            addError('Entry ${ei + 1} in "$lessonLabel" must be an object.');
            continue;
          }
          final en = (entry['en'] as Object?)?.toString().trim() ?? '';
          final target =
              ((entry['target'] ?? entry['bn']) as Object?)?.toString().trim() ??
              '';
          final roman = (entry['roman'] as Object?)?.toString().trim() ?? '';
          if (en.isEmpty || target.isEmpty || roman.isEmpty) {
            addError(
              'Every entry needs "en", "bn" and "roman" '
              '(lesson "$lessonLabel", entry ${ei + 1}).',
            );
          }
        }
      }
    }
  }
}
