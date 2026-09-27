import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';
import '../models/course.dart';
import '../services/course_id.dart';
import '../services/imported_course_service.dart';
import '../services/language_import.dart';
import '../services/quiz_stats_service.dart';

/// Discovers the courses the app can learn from — the bundled asset files and
/// the user's own imports — and loads a selected course's lesson content.
///
/// Course files are self-describing: each carries its own `name` and `language`
/// metadata, so there is no separate config file. Bundled files are found
/// through the asset manifest and go through the very same [LanguageImport]
/// pipeline as an uploaded file.
class CourseRepository {
  static const String _dir = 'assets/content';

  /// Kept as `selected_language_v1` so an existing install's choice survives.
  static const String _selectedKey = 'selected_language_v1';

  CourseRepository(this._imported, this._stats);

  final ImportedCourseService _imported;
  final QuizStatsService _stats;
  final Map<String, AppContent> _contentCache = {};

  /// Problems found while loading bundled courses (malformed files). The app
  /// keeps running with the rest; these are surfaced in the languages screen.
  final List<String> loadErrors = [];

  /// Every available course: bundled first, then the user's imports.
  Future<List<Course>> loadCourses() async {
    loadErrors.clear();
    final courses = <Course>[];
    final ids = <String>{};

    for (final assetPath in await _bundledPaths()) {
      final fileName = assetPath.split('/').last;
      String raw;
      try {
        raw = await rootBundle.loadString(assetPath);
      } catch (_) {
        loadErrors.add('Could not read $fileName.');
        continue;
      }
      final result = LanguageImport.parse(
        raw,
        source: LanguageSource.bundled,
        fileName: fileName,
        assetPath: assetPath,
        existingIds: ids,
      );
      if (result.ok) {
        courses.add(result.course!);
        ids.add(result.course!.id);
      } else {
        loadErrors.add('$fileName: ${result.errors.first}');
      }
    }

    // Imports were validated against the ids installed at the time; skip any
    // that would now clash with a bundled course.
    for (final course in _imported.courses) {
      if (ids.add(course.id)) courses.add(course);
    }
    return courses;
  }

  /// The bundled course files, discovered from the asset manifest (the
  /// `assets/content/` folder is bundled wholesale via pubspec).
  Future<List<String>> _bundledPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().where(
      (path) => path.startsWith('$_dir/') && path.endsWith('.json'),
    ).toList()..sort();
  }

  /// Decodes and caches a course's lesson content.
  AppContent contentFor(Course course) => _contentCache.putIfAbsent(
    course.id,
    () =>
        AppContent.fromJson(jsonDecode(course.rawJson) as Map<String, dynamic>),
  );

  /// Picks the course to start with: the saved one, else the flagged default,
  /// else the first bundled, else the first available.
  Course? resolveSelection(List<Course> courses, String? savedId) {
    if (courses.isEmpty) return null;
    final wanted = savedId == null ? null : migrateLegacyCourseId(savedId);
    for (final course in courses) {
      if (course.id == wanted) return course;
    }
    for (final course in courses) {
      if (course.isBundled && course.isDefault) return course;
    }
    for (final course in courses) {
      if (course.isBundled) return course;
    }
    return courses.first;
  }

  /// Validates a picked file without saving it, so the import screen can show a
  /// preview and any problems before the user confirms.
  Future<ImportResult> previewImport(String rawJson, String fileName) async {
    final courses = await loadCourses();
    return LanguageImport.parse(
      rawJson,
      source: LanguageSource.imported,
      fileName: fileName,
      importedAt: DateTime.now(),
      existingIds: courses.map((c) => c.id).toSet(),
    );
  }

  /// Persists a [Course] that [previewImport] already accepted.
  Future<void> saveImport(Course course) => _imported.addOrReplace(course);

  Future<void> deleteCourse(Course course) async {
    if (!course.isBundled) {
      await _imported.delete(course.id);
      _contentCache.remove(course.id);
    }
  }

  /// Renames an imported course. Because a course's id is derived from its
  /// name, progress and the saved selection move to the new id.
  Future<ImportResult> renameCourse(Course course, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const ImportResult.failure(['Give the course a name.']);
    }

    final renamed = Course(
      name: trimmed,
      language: course.language,
      rawJson: _renameJson(course.rawJson, trimmed),
      source: course.source,
      isDefault: course.isDefault,
      assetPath: course.assetPath,
      importedAt: course.importedAt,
      originalFileName: course.originalFileName,
    );

    if (renamed.id != course.id) {
      final courses = await loadCourses();
      if (courses.any((c) => c.id == renamed.id)) {
        return ImportResult.failure([
          'A course named "$trimmed" already exists.',
        ]);
      }
    }

    await _imported.addOrReplace(renamed);
    if (renamed.id != course.id) {
      await _imported.delete(course.id);
      _contentCache.remove(course.id);
      await _stats.renameCourseScope(course.id, renamed.id);
      if (await loadSelectedCourseId() == course.id) {
        await saveSelectedCourseId(renamed.id);
      }
    }
    return ImportResult.success(renamed);
  }

  /// Returns [rawJson] with its root `name` replaced, so the stored file stays
  /// consistent with the course's identity.
  static String _renameJson(String rawJson, String name) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    map['name'] = name;
    return jsonEncode(map);
  }

  Future<String?> loadSelectedCourseId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedCourseId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedKey, id);
    } catch (_) {
      // Selection just won't persist if storage is unavailable.
    }
  }
}
