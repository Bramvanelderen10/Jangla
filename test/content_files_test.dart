import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/models/course.dart';
import 'package:jangla/services/language_import.dart';

/// Guards every bundled course file: each must parse through the very same
/// pipeline a user upload goes through, so a half-finished language fails CI.
void main() {
  final files =
      Directory('assets/content')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('there is at least one bundled course file', () {
    expect(files, isNotEmpty);
  });

  final courses = <String, Course>{};
  for (final file in files) {
    final fileName = file.uri.pathSegments.last;
    final result = LanguageImport.parse(
      file.readAsStringSync(),
      source: LanguageSource.bundled,
      fileName: fileName,
      existingIds: courses.keys.toSet(),
    );

    test('$fileName parses as a course', () {
      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      expect(result.course, isNotNull);
    });

    if (result.ok) courses[result.course!.id] = result.course!;
  }

  test('course ids are unique', () {
    expect(courses.length, files.length);
  });

  test('exactly one bundled course is the default', () {
    final defaults = courses.values.where((c) => c.isDefault).toList();
    expect(defaults.length, 1);
    expect(defaults.single.name, 'Japanese');
  });

  test('every course has categories, lessons and entries', () {
    for (final course in courses.values) {
      final content = AppContent.fromJson(
        jsonDecode(course.rawJson) as Map<String, dynamic>,
      );
      expect(content.categories, isNotEmpty, reason: course.name);
      for (final category in content.categories) {
        expect(category.lessons, isNotEmpty, reason: category.id);
        for (final lesson in category.lessons) {
          expect(lesson.entries, isNotEmpty, reason: lesson.id);
        }
      }
    }
  });

  test('every course declares a language code and tts locale', () {
    for (final course in courses.values) {
      expect(course.language.code, isNotEmpty, reason: course.name);
      expect(course.language.ttsLocales, isNotEmpty, reason: course.name);
    }
  });
}
