import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';

/// Right/wrong tally plus the spaced-repetition state for a single entry.
class EntryStat {
  /// Times answered correctly / incorrectly.
  int correct;
  int wrong;

  /// Leitner box index; higher boxes wait longer before the next review.
  int box;

  /// Local calendar day (see [QuizStatsService.dayOf]) the entry is next due.
  /// `0` means the entry has never been scheduled for review.
  int dueDay;

  /// Times the entry was missed after having been scheduled.
  int lapses;

  EntryStat({
    this.correct = 0,
    this.wrong = 0,
    this.box = 0,
    this.dueDay = 0,
    this.lapses = 0,
  });

  int get attempts => correct + wrong;

  bool get isScheduled => dueDay > 0;

  Map<String, dynamic> toJson() => {
        'c': correct,
        'w': wrong,
        'b': box,
        'd': dueDay,
        'l': lapses,
      };

  factory EntryStat.fromJson(Map<String, dynamic> json) => EntryStat(
        correct: (json['c'] ?? 0) as int,
        wrong: (json['w'] ?? 0) as int,
        box: (json['b'] ?? 0) as int,
        dueDay: (json['d'] ?? 0) as int,
        lapses: (json['l'] ?? 0) as int,
      );
}

/// One entry that is due for review, together with the lesson it came from.
/// The lesson id is what results are recorded against, so the schedule stays
/// attached to the original lesson even when reviewing from a mixed session.
class ReviewItem {
  final String lessonId;
  final Entry entry;

  const ReviewItem({required this.lessonId, required this.entry});
}

/// Persists per-entry results and the spaced-repetition schedule, and answers
/// "what is due today?" across every lesson the learner has started.
///
/// Stats are scoped to the active language: the same lesson id exists in more
/// than one content file (e.g. `greetings_goodbyes` in Bengali and Japanese),
/// so without the scope the two languages would share data.
class QuizStatsService {
  /// v2 adds the language scope and review scheduling. v1 data is ignored.
  static const String _prefsKey = 'quiz_stats_v2';

  /// Days until the next review for each Leitner box.
  static const List<int> _intervalDays = [0, 1, 3, 7, 16, 35];

  final Map<String, EntryStat> _stats = {};
  SharedPreferences? _prefs;
  String _language = '';

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((key, value) {
          _stats[key] = EntryStat.fromJson(value as Map<String, dynamic>);
        });
      }
    } catch (_) {
      // Start with empty stats if storage is unavailable.
    }
  }

  /// Selects which language's stats are read and written.
  void setLanguageScope(String code) {
    _language = code;
  }

  /// Maps a [date] to a stable day number for its local calendar date.
  static int dayOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  String _keyFor(String lessonId, Entry entry) =>
      '$_language::$lessonId::${entry.english}';

  EntryStat statFor(String lessonId, Entry entry) =>
      _stats[_keyFor(lessonId, entry)] ?? EntryStat();

  /// Records one graded answer and reschedules the entry. A correct answer
  /// moves it up a box (review further out); a wrong answer drops it to box 0
  /// and leaves it due, so it surfaces again on the next review.
  Future<void> record(
    String lessonId,
    Entry entry,
    bool correct, {
    DateTime? now,
  }) async {
    final stat = _stats.putIfAbsent(_keyFor(lessonId, entry), EntryStat.new);
    final today = dayOf(now ?? DateTime.now());

    if (correct) {
      stat.correct++;
      stat.box = (stat.box + 1).clamp(0, _intervalDays.length - 1);
      stat.dueDay = today + _intervalDays[stat.box];
    } else {
      stat.wrong++;
      stat.lapses++;
      stat.box = 0;
      stat.dueDay = today;
    }

    await _persist();
  }

  /// Number of entries in the lesson the user has answered wrong at least
  /// as often as right (i.e. still worth reviewing).
  int weakCount(Lesson lesson) => lesson.entries
      .where((e) => statFor(lesson.id, e).wrong > 0 &&
          statFor(lesson.id, e).wrong >= statFor(lesson.id, e).correct)
      .length;

  /// True when the entry has been scheduled and is due on or before [now].
  bool isDue(String lessonId, Entry entry, {DateTime? now}) {
    final stat = _stats[_keyFor(lessonId, entry)];
    if (stat == null || !stat.isScheduled) return false;
    return stat.dueDay <= dayOf(now ?? DateTime.now());
  }

  /// How many entries across [lessons] are due today.
  int dueCount(Iterable<Lesson> lessons, {DateTime? now}) =>
      _collectDue(lessons, now: now).length;

  /// Due entries across [lessons], most overdue first, capped at [limit].
  List<ReviewItem> dueEntries(
    Iterable<Lesson> lessons, {
    int limit = 15,
    DateTime? now,
  }) =>
      _collectDue(lessons, now: now).take(limit).toList();

  List<ReviewItem> _collectDue(Iterable<Lesson> lessons, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final items = <ReviewItem>[];
    final seen = <String>{};

    for (final lesson in lessons) {
      for (final entry in lesson.entries) {
        final stat = _stats[_keyFor(lesson.id, entry)];
        if (stat == null || !stat.isScheduled || stat.dueDay > today) continue;
        // The same entry can exist in more than one lesson; review it once.
        if (!seen.add(entry.key)) continue;
        items.add(ReviewItem(lessonId: lesson.id, entry: entry));
      }
    }

    items.sort((a, b) {
      final sa = _stats[_keyFor(a.lessonId, a.entry)]!;
      final sb = _stats[_keyFor(b.lessonId, b.entry)]!;
      final byDue = sa.dueDay.compareTo(sb.dueDay);
      if (byDue != 0) return byDue;
      final byBox = sa.box.compareTo(sb.box);
      if (byBox != 0) return byBox;
      return sb.wrong.compareTo(sa.wrong);
    });

    return items;
  }

  Future<void> _persist() async {
    try {
      final map = _stats.map((key, value) => MapEntry(key, value.toJson()));
      await _prefs?.setString(_prefsKey, jsonEncode(map));
    } catch (_) {
      // Ignore write failures; stats remain in memory for this session.
    }
  }
}
