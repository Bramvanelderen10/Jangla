import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';

/// Right/wrong tally for a single entry.
class EntryStat {
  int correct;
  int wrong;

  EntryStat({this.correct = 0, this.wrong = 0});

  int get attempts => correct + wrong;

  Map<String, dynamic> toJson() => {'c': correct, 'w': wrong};

  factory EntryStat.fromJson(Map<String, dynamic> json) => EntryStat(
        correct: (json['c'] ?? 0) as int,
        wrong: (json['w'] ?? 0) as int,
      );
}

/// Persists per-entry quiz results and selects entries to review, biased
/// toward the words the user has gotten wrong most often.
class QuizStatsService {
  static const String _prefsKey = 'quiz_stats_v1';

  final Map<String, EntryStat> _stats = {};
  SharedPreferences? _prefs;

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

  String _keyFor(String lessonId, Entry entry) => '$lessonId::${entry.english}';

  EntryStat statFor(String lessonId, Entry entry) =>
      _stats[_keyFor(lessonId, entry)] ?? EntryStat();

  Future<void> record(String lessonId, Entry entry, bool correct) async {
    final stat = _stats.putIfAbsent(_keyFor(lessonId, entry), EntryStat.new);
    if (correct) {
      stat.correct++;
    } else {
      stat.wrong++;
    }
    await _persist();
  }

  /// Number of entries in the lesson the user has answered wrong at least
  /// as often as right (i.e. still worth reviewing).
  int weakCount(Lesson lesson) => lesson.entries
      .where((e) => statFor(lesson.id, e).wrong > 0 &&
          statFor(lesson.id, e).wrong >= statFor(lesson.id, e).correct)
      .length;

  /// Higher score = needs more practice.
  int _reviewScore(String lessonId, Entry entry) {
    final s = statFor(lessonId, entry);
    return s.wrong * 2 - s.correct;
  }

  /// Returns a session of entries ordered toward the ones failed most.
  /// Words never seen sit above mastered ones so they still get practiced.
  List<Entry> reviewEntries(Lesson lesson, [Random? random]) {
    final rng = random ?? Random();
    final entries = List<Entry>.from(lesson.entries)..shuffle(rng);
    entries.sort((a, b) =>
        _reviewScore(lesson.id, b).compareTo(_reviewScore(lesson.id, a)));

    final count = lesson.entriesPerSession <= 0
        ? entries.length
        : min(lesson.entriesPerSession, entries.length);

    return entries.take(count).toList()..shuffle(rng);
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
