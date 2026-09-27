import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/course.dart';
import 'package:jangla/models/language.dart';
import 'package:jangla/services/course_id.dart';

Course sample({String name = 'Business Japanese'}) => Course(
  name: name,
  language: const LanguageOption(
    code: 'ja',
    nativeName: '日本語',
    ttsLocales: ['ja-JP'],
  ),
  rawJson: '{"name":"Business Japanese"}',
  source: LanguageSource.imported,
  importedAt: DateTime.utc(2026, 1, 2),
  originalFileName: 'biz.json',
);

void main() {
  test('slugifyCourseName makes a stable id', () {
    expect(slugifyCourseName('Business Japanese'), 'business-japanese');
    expect(slugifyCourseName('  Spanish  '), 'spanish');
    expect(slugifyCourseName('日本語'), '日本語');
    expect(slugifyCourseName('!!!'), '');
  });

  test('id falls back to the language code when the name has no slug', () {
    expect(sample(name: '!!!').id, 'ja');
  });

  test('Course round-trips through toJson/fromJson', () {
    final restored = Course.fromJson(sample().toJson());

    expect(restored.name, 'Business Japanese');
    expect(restored.id, 'business-japanese');
    expect(restored.language.code, 'ja');
    expect(restored.language.ttsLocales, ['ja-JP']);
    expect(restored.source, LanguageSource.imported);
    expect(restored.originalFileName, 'biz.json');
    expect(restored.rawJson, '{"name":"Business Japanese"}');
  });

  test('legacy bundled ids map to their new course ids', () {
    expect(migrateLegacyCourseId('ja'), 'japanese');
    expect(migrateLegacyCourseId('spanish'), 'spanish');
  });
}
