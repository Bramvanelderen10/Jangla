import 'package:jangla/models/content_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Entry> makeEntries(int n) => List.generate(
        n,
        (i) => Entry(english: 'e$i', target: 'b$i', roman: 'r$i'),
      );

  test('sessionEntries returns entriesPerSession unique items', () {
    final lesson = Lesson(
      id: 'x',
      title: 'X',
      entriesPerSession: 20,
      entries: makeEntries(30),
    );

    final session = lesson.sessionEntries();

    expect(session.length, 20);
    expect(session.toSet().length, 20, reason: 'entries should be unique');
  });

  test('sessionEntries caps at the pool size', () {
    final lesson = Lesson(
      id: 'x',
      title: 'X',
      entriesPerSession: 20,
      entries: makeEntries(5),
    );

    expect(lesson.sessionEntries().length, 5);
  });

  test('entriesPerSession of 0 uses the whole pool', () {
    final lesson = Lesson(
      id: 'x',
      title: 'X',
      entriesPerSession: 0,
      entries: makeEntries(12),
    );

    expect(lesson.sessionEntries().length, 12);
  });

  test('AppContent.fromJson applies default entriesPerSession', () {
    final content = AppContent.fromJson({
      'defaults': {'entriesPerSession': 15},
      'categories': [
        {
          'id': 'c1',
          'title': 'Cat 1',
          'lessons': [
            {
              'id': 'l1',
              'title': 'Lesson 1',
              'entries': [
                {'en': 'one', 'bn': 'এক', 'roman': 'ek'},
              ],
            },
          ],
        },
      ],
    });

    expect(content.defaultEntriesPerSession, 15);
    expect(content.categories.single.lessons.single.entriesPerSession, 15);
    expect(content.categories.single.lessons.single.entries.single.roman, 'ek');
  });
}
