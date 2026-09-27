import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/models/language.dart';

/// Guards every content file listed in `config.json`: it must parse and every
/// entry must be complete, so a half-finished language file fails CI.
void main() {
  final config = AppConfig.fromJson(
    jsonDecode(File('assets/content/config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  AppContent read(String file) => AppContent.fromJson(
    jsonDecode(File('assets/content/$file').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('config lists at least one language', () {
    expect(config.languages, isNotEmpty);
  });

  for (final language in config.languages) {
    group('${language.code} content', () {
      final content = read(language.file);

      test('has categories, lessons and entries', () {
        expect(content.categories, isNotEmpty);
        for (final category in content.categories) {
          expect(category.lessons, isNotEmpty, reason: category.id);
          for (final lesson in category.lessons) {
            expect(lesson.entries, isNotEmpty, reason: lesson.id);
          }
        }
      });

      test('every entry has a prompt, target and romanization', () {
        for (final category in content.categories) {
          for (final lesson in category.lessons) {
            for (final entry in lesson.entries) {
              expect(entry.english.trim(), isNotEmpty, reason: lesson.id);
              expect(entry.target.trim(), isNotEmpty, reason: entry.english);
              expect(entry.roman.trim(), isNotEmpty, reason: entry.english);
            }
          }
        }
      });

      test('lesson ids are unique', () {
        final ids = [
          for (final c in content.categories)
            for (final l in c.lessons) l.id,
        ];
        expect(ids.toSet().length, ids.length);
      });
    });
  }

  test('Spanish mirrors the Japanese lesson structure', () {
    List<String> lessonIds(String file) => [
      for (final c in read(file).categories)
        for (final l in c.lessons) '${c.id}/${l.id}',
    ];

    expect(lessonIds('content.es.json'), lessonIds('content.ja.json'));
  });
}
