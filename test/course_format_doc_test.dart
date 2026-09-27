import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/course.dart';
import 'package:jangla/services/language_import.dart';

/// Keeps the examples in `COURSE_FORMAT.md` honest: every ```json block must be
/// a valid, importable course file, so the documented format cannot drift from
/// what the app actually accepts.
void main() {
  final doc = File('COURSE_FORMAT.md').readAsStringSync();
  final blocks =
      RegExp(r'```json\r?\n([\s\S]*?)```')
          .allMatches(doc)
          .map((match) => match.group(1)!)
          .toList();

  test('COURSE_FORMAT.md contains JSON examples', () {
    expect(blocks, isNotEmpty);
  });

  for (var i = 0; i < blocks.length; i++) {
    test('example ${i + 1} in COURSE_FORMAT.md is a valid course', () {
      final result = LanguageImport.parse(
        blocks[i],
        source: LanguageSource.imported,
      );

      expect(result.ok, isTrue, reason: result.errors.join('\n'));
    });
  }
}
