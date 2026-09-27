import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/data/course_repository.dart';
import 'package:jangla/models/course.dart';
import 'package:jangla/services/imported_course_service.dart';
import 'package:jangla/services/language_import.dart';
import 'package:jangla/services/quiz_stats_service.dart';

/// Exercises the real runtime path: bundled courses discovered from the asset
/// manifest and decoded through the shared import pipeline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CourseRepository repo() =>
      CourseRepository(ImportedCourseService(), QuizStatsService());

  test('loadCourses discovers every bundled course', () async {
    final repository = repo();

    final courses = await repository.loadCourses();

    expect(
      courses.map((c) => c.id),
      containsAll(<String>['bengali', 'japanese', 'spanish']),
    );
    expect(repository.loadErrors, isEmpty, reason: repository.loadErrors.join('\n'));
  });

  test('a discovered course provides decodable content', () async {
    final repository = repo();

    final courses = await repository.loadCourses();
    final japanese = courses.singleWhere((c) => c.id == 'japanese');

    expect(japanese.isBundled, isTrue);
    expect(japanese.isDefault, isTrue);
    expect(japanese.language.code, 'ja');
    expect(repository.contentFor(japanese).categories, isNotEmpty);
  });

  test('resolveSelection prefers the saved course, then the default', () async {
    final repository = repo();
    final courses = await repository.loadCourses();

    expect(repository.resolveSelection(courses, 'spanish')!.id, 'spanish');
    // Legacy saved codes are migrated.
    expect(repository.resolveSelection(courses, 'bn')!.id, 'bengali');
    // Nothing saved -> the flagged default.
    expect(repository.resolveSelection(courses, null)!.id, 'japanese');
  });

  test('renaming an imported course is validated and re-ids it', () async {
    final repository = repo();
    final course = _tinyImportedCourse();

    // Cannot take a bundled course's name.
    final clash = await repository.renameCourse(course, 'Bengali');
    expect(clash.ok, isFalse);

    final renamed = await repository.renameCourse(course, 'Work Japanese');
    expect(renamed.ok, isTrue, reason: renamed.errors.join(', '));
    expect(renamed.course!.name, 'Work Japanese');
    expect(renamed.course!.id, 'work-japanese');
    // The stored file's root name is kept consistent with the course.
    expect(renamed.course!.rawJson, contains('"name":"Work Japanese"'));
  });

  test('renaming to an empty name is rejected', () async {
    final repository = repo();
    final result = await repository.renameCourse(_tinyImportedCourse(), '   ');
    expect(result.ok, isFalse);
  });
}

Course _tinyImportedCourse() {
  final result = LanguageImport.parse(
    jsonEncode({
      'name': 'Business Japanese',
      'language': {'code': 'ja', 'ttsLocales': ['ja-JP']},
      'categories': [
        {
          'id': 'c',
          'title': 'C',
          'lessons': [
            {
              'id': 'l',
              'title': 'L',
              'entries': [
                {'en': 'one', 'bn': 'いち', 'roman': 'ichi'},
              ],
            },
          ],
        },
      ],
    }),
    source: LanguageSource.imported,
  );
  return result.course!;
}
