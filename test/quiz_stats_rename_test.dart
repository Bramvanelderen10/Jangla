import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/services/quiz_stats_service.dart';

/// Renaming a course changes its id (the id is derived from the name), so its
/// spaced-repetition progress has to move with it.
void main() {
  const entry = Entry(english: 'one', target: 'いち', roman: 'ichi');
  const lesson = Lesson(
    id: 'l1',
    title: 'L',
    entriesPerSession: 0,
    entries: [entry],
  );

  test('renameCourseScope moves scheduled entries to the new id', () async {
    final stats = QuizStatsService();
    stats.setCourseScope('business-japanese');
    await stats.record('l1', entry, true);

    await stats.renameCourseScope('business-japanese', 'work-japanese');

    stats.setCourseScope('work-japanese');
    final mastery = stats.mastery(lesson);
    expect(mastery.unseen, 0);
    expect(mastery.learning + mastery.learned, 1);
  });

  test('renameCourseScope leaves the old scope empty', () async {
    final stats = QuizStatsService();
    stats.setCourseScope('old');
    await stats.record('l1', entry, true);

    await stats.renameCourseScope('old', 'new');

    stats.setCourseScope('old');
    expect(stats.mastery(lesson).unseen, 1);
  });
}
