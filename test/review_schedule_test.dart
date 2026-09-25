import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/services/quiz_stats_service.dart';

void main() {
  Entry entry(String english) =>
      Entry(english: english, target: 'x', roman: 'r');

  Lesson lesson(String id, List<Entry> entries) =>
      Lesson(id: id, title: id, entriesPerSession: 0, entries: entries);

  final day1 = DateTime(2026, 1, 1, 9);
  final day2 = DateTime(2026, 1, 2, 9);
  final day3 = DateTime(2026, 1, 3, 9);
  final day4 = DateTime(2026, 1, 4, 9);

  group('dayOf', () {
    test('is stable across times on the same local day', () {
      expect(
        QuizStatsService.dayOf(day1),
        QuizStatsService.dayOf(DateTime(2026, 1, 1, 23, 59)),
      );
      expect(QuizStatsService.dayOf(day2) - QuizStatsService.dayOf(day1), 1);
    });
  });

  group('scheduling', () {
    test('an unseen entry is not due', () {
      final stats = QuizStatsService()..setLanguageScope('ja');
      final e = entry('a');

      expect(stats.isDue('l', e, now: day1), isFalse);
      expect(stats.dueCount([lesson('l', [e])], now: day1), 0);
    });

    test('a correct answer schedules the next review one day out', () async {
      final stats = QuizStatsService()..setLanguageScope('ja');
      final e = entry('a');
      await stats.record('l', e, true, now: day1);

      expect(stats.statFor('l', e).box, 1);
      expect(stats.statFor('l', e).dueDay, QuizStatsService.dayOf(day2));
      expect(stats.isDue('l', e, now: day1), isFalse);
      expect(stats.isDue('l', e, now: day2), isTrue);
    });

    test('consecutive correct answers grow the interval', () async {
      final stats = QuizStatsService()..setLanguageScope('ja');
      final e = entry('a');
      await stats.record('l', e, true, now: day1); // box 1 -> due next day
      await stats.record('l', e, true, now: day2); // box 2 -> due in 3 days

      expect(stats.statFor('l', e).box, 2);
      expect(stats.statFor('l', e).dueDay, QuizStatsService.dayOf(day2) + 3);
    });

    test('a wrong answer resets the box, lapses, and leaves it due', () async {
      final stats = QuizStatsService()..setLanguageScope('ja');
      final e = entry('a');
      await stats.record('l', e, true, now: day1);
      await stats.record('l', e, true, now: day2);
      await stats.record('l', e, false, now: day3);

      final stat = stats.statFor('l', e);
      expect(stat.box, 0);
      expect(stat.lapses, 1);
      expect(stat.wrong, 1);
      expect(stats.isDue('l', e, now: day3), isTrue);
    });
  });

  group('dueEntries', () {
    test('returns only due entries, most overdue first, capped by limit',
        () async {
      final stats = QuizStatsService()..setLanguageScope('ja');
      final a = entry('a');
      final b = entry('b');
      final c = entry('c');
      final chapter = lesson('l', [a, b, c]);

      await stats.record('l', a, true, now: day1); // due day2
      await stats.record('l', b, true, now: day2); // due day3 (c stays unseen)

      expect(stats.dueCount([chapter], now: day1), 0);
      expect(stats.dueCount([chapter], now: day4), 2);

      final due = stats.dueEntries([chapter], now: day4);
      expect(due.map((item) => item.entry.english).toList(), ['a', 'b']);
      expect(due.first.lessonId, 'l');

      final limited = stats.dueEntries([chapter], limit: 1, now: day4);
      expect(limited.length, 1);
      expect(limited.single.entry.english, 'a');
    });
  });

  group('language scope', () {
    test('the same lesson id in two languages keeps separate stats', () async {
      final stats = QuizStatsService();
      final e = entry('hello');

      stats.setLanguageScope('ja');
      await stats.record('greetings', e, true, now: day1);

      stats.setLanguageScope('bn');
      expect(stats.isDue('greetings', e, now: day2), isFalse);
      expect(stats.statFor('greetings', e).attempts, 0);

      stats.setLanguageScope('ja');
      expect(stats.isDue('greetings', e, now: day2), isTrue);
    });
  });
}
