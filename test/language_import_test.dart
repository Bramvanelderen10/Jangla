import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/course.dart';
import 'package:jangla/services/language_import.dart';

/// A minimal-but-valid course file, with each part overridable so individual
/// validation failures can be exercised.
Map<String, dynamic> courseJson({
  Object? name = 'Business Japanese',
  Object? language = const {
    'code': 'ja',
    'nativeName': '日本語',
    'ttsLocales': ['ja-JP', 'ja'],
  },
  Object? categories,
}) => {
  'name': name,
  'language': language,
  'categories':
      categories ??
      [
        {
          'id': 'c1',
          'title': 'Cat',
          'lessons': [
            {
              'id': 'l1',
              'title': 'Lesson',
              'entries': [
                {'en': 'one', 'bn': 'いち', 'roman': 'ichi'},
              ],
            },
          ],
        },
      ],
};

String encode(Map<String, dynamic> json) => jsonEncode(json);

void main() {
  group('LanguageImport.parse', () {
    test('accepts a valid course file', () {
      final result = LanguageImport.parse(
        encode(courseJson()),
        source: LanguageSource.imported,
      );

      expect(result.ok, isTrue, reason: result.errors.join(', '));
      expect(result.course!.name, 'Business Japanese');
      expect(result.course!.id, 'business-japanese');
      expect(result.course!.language.code, 'ja');
      expect(result.course!.language.ttsLocales, ['ja-JP', 'ja']);
    });

    test('derives native name and locales when omitted', () {
      final result = LanguageImport.parse(
        encode(courseJson(language: const {'code': 'nl'})),
        source: LanguageSource.imported,
      );

      expect(result.ok, isTrue, reason: result.errors.join(', '));
      expect(result.course!.language.nativeName, 'Business Japanese');
      expect(result.course!.language.ttsLocales, ['nl']);
    });

    test('flags a missing name', () {
      final result = LanguageImport.parse(
        encode(courseJson(name: '')),
        source: LanguageSource.imported,
      );

      expect(result.ok, isFalse);
      expect(result.errors.join(' '), contains('name'));
    });

    test('flags a missing language block', () {
      final result = LanguageImport.parse(
        encode(courseJson(language: null)),
        source: LanguageSource.imported,
      );

      expect(result.ok, isFalse);
      expect(result.errors.join(' '), contains('language'));
    });

    test('rejects invalid JSON', () {
      final result = LanguageImport.parse(
        '{oops',
        source: LanguageSource.imported,
      );

      expect(result.ok, isFalse);
      expect(result.errors.single, contains('valid JSON'));
    });

    test('rejects empty categories', () {
      final result = LanguageImport.parse(
        encode(courseJson(categories: const [])),
        source: LanguageSource.imported,
      );

      expect(result.ok, isFalse);
      expect(result.errors.join(' '), contains('categories'));
    });

    test('rejects an entry missing en or bn', () {
      final result = LanguageImport.parse(
        encode(
          courseJson(
            categories: [
              {
                'id': 'c',
                'title': 'C',
                'lessons': [
                  {
                    'id': 'l',
                    'title': 'L',
                    'entries': [
                      {'en': 'Hello.', 'bn': ''},
                    ],
                  },
                ],
              },
            ],
          ),
        ),
        source: LanguageSource.imported,
      );

      expect(result.ok, isFalse);
      expect(result.errors.join(' '), contains('bn'));
    });

    test('romanization is optional (Latin-script languages)', () {
      final result = LanguageImport.parse(
        encode(
          courseJson(
            categories: [
              {
                'id': 'c',
                'title': 'C',
                'lessons': [
                  {
                    'id': 'l',
                    'title': 'L',
                    'entries': [
                      {'en': 'Hello.', 'bn': 'Hola.'},
                    ],
                  },
                ],
              },
            ],
          ),
        ),
        source: LanguageSource.imported,
      );

      expect(result.ok, isTrue, reason: result.errors.join(', '));
      expect(result.course, isNotNull);
    });

    test('reports a duplicate course id', () {
      final result = LanguageImport.parse(
        encode(courseJson()),
        source: LanguageSource.imported,
        existingIds: const {'business-japanese'},
      );

      expect(result.ok, isFalse);
      expect(result.errors.single, contains('already installed'));
    });

    test('slugs a non-Latin name', () {
      final result = LanguageImport.parse(
        encode(courseJson(name: '日本語コース')),
        source: LanguageSource.imported,
      );

      expect(result.ok, isTrue, reason: result.errors.join(', '));
      expect(result.course!.id, '日本語コース');
    });

    test('carries the default flag and source', () {
      final result = LanguageImport.parse(
        encode(courseJson(language: const {'code': 'ja', 'default': true})),
        source: LanguageSource.bundled,
      );

      expect(result.course!.isDefault, isTrue);
      expect(result.course!.source, LanguageSource.bundled);
    });
  });
}
