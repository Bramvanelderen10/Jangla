import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';

/// Persists the courses the user imported, via shared_preferences (matching the
/// app's other stores). Bundled courses are never stored here — they are
/// re-read from the asset bundle on every launch.
class ImportedCourseService {
  static const String _prefsKey = 'imported_courses_v1';

  final List<Course> _courses = [];
  SharedPreferences? _prefs;

  List<Course> get courses => List.unmodifiable(_courses);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        _courses
          ..clear()
          ..addAll(
            decoded.map((e) => Course.fromJson(e as Map<String, dynamic>)),
          );
      }
    } catch (_) {
      // Start with no imports if storage is unavailable.
    }
  }

  /// Adds [course], replacing any import with the same id.
  Future<void> addOrReplace(Course course) async {
    _courses.removeWhere((c) => c.id == course.id);
    _courses.add(course);
    await _persist();
  }

  Future<void> delete(String id) async {
    _courses.removeWhere((c) => c.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode(_courses.map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Ignore write failures; imports remain in memory for this session.
    }
  }
}
