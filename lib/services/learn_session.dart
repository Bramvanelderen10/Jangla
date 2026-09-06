import 'dart:math';

import '../models/content_models.dart';

enum WordPhase { new_, introduced, needsRetry, learned }

class LearnWord {
  final Entry entry;
  WordPhase phase;
  int timesIntroduced;
  int timesQuizzed;
  int correctStreak;
  int timesWrong;
  int _reviewInterval = 0;
  int _actionsUntilReview = 0;

  LearnWord({required this.entry})
    : phase = WordPhase.new_,
      timesIntroduced = 0,
      timesQuizzed = 0,
      correctStreak = 0,
      timesWrong = 0;

  bool tickReview() {
    if (phase != WordPhase.learned || _reviewInterval == 0) return false;
    _actionsUntilReview--;
    return _actionsUntilReview <= 0;
  }

  void scheduleReview(int interval) {
    _reviewInterval = interval;
    _actionsUntilReview = interval;
  }

  bool get reviewDue => phase == WordPhase.learned && _actionsUntilReview <= 0;
  int get debugActionsUntilReview => _actionsUntilReview;
}

// ---------------------------------------------------------------------------
// Sealed action union — the UI switches on this to know what to render.
// ---------------------------------------------------------------------------
sealed class LearnAction {
  const LearnAction();
}

class ShowIntroduction extends LearnAction {
  final Entry entry;
  final bool isRetry;
  const ShowIntroduction({required this.entry, required this.isRetry});
}

class ShowQuiz extends LearnAction {
  final Entry entry;
  final int wordIndex;
  final bool showTarget;
  final List<Entry> options;
  const ShowQuiz({
    required this.entry,
    required this.wordIndex,
    required this.showTarget,
    required this.options,
  });
}

class SessionComplete extends LearnAction {
  final List<LearnWord> results;
  final int totalIntroductions;
  final int totalQuizzes;
  final int totalWrong;
  final String lessonId;
  const SessionComplete({
    required this.results,
    required this.totalIntroductions,
    required this.totalQuizzes,
    required this.totalWrong,
    required this.lessonId,
  });
}

enum QuizOutcome { correct, wrong }

// ---------------------------------------------------------------------------
// Pure-Dart engine that drives the interleaved introduce-test-retry loop.
// ---------------------------------------------------------------------------
class LearnSession {
  LearnSession(this.lesson) : _rng = Random() {
    _words =
        lesson.sessionEntries(_rng).map((e) => LearnWord(entry: e)).toList();
    if (_words.isNotEmpty) {
      _newPool = List<int>.generate(_words.length, (i) => i)..shuffle(_rng);
    }
  }

  final Lesson lesson;
  final Random _rng;

  late final List<LearnWord> _words;
  List<LearnWord> get words => List.unmodifiable(_words);
  int get totalWords => _words.length;
  int get learnedCount =>
      _words.where((w) => w.phase == WordPhase.learned).length;

  late final List<int> _newPool;
  final List<int> _introBuffer = [];
  final List<int> _retryBuffer = [];
  final List<int> _laterPool = []; // words deferred after failing retries
  int _retryState = 0;

  int _totalIntroductions = 0;
  int _totalQuizzes = 0;
  int _totalWrong = 0;

  LearnAction nextAction() {
    if (_words.isEmpty) return _complete();

    // 1. Retry: re-introduce or quiz a needsRetry word.
    if (_retryBuffer.isNotEmpty) {
      final idx = _retryBuffer.first;
      if (_retryState == 0) {
        return ShowIntroduction(entry: _words[idx].entry, isRetry: true);
      } else {
        return _buildQuiz(idx);
      }
    }

    // 2. Quiz introduced words when buffer has >=2 (interleaving lag).
    if (_introBuffer.length >= 2) {
      final idx = _introBuffer.removeAt(0);
      return _buildQuiz(idx);
    }

    // 3. Spaced review: learned word whose timer expired.
    for (int i = 0; i < _words.length; i++) {
      if (_words[i].reviewDue) return _buildQuiz(i);
    }

    // 4. Introduce a new word.
    if (_newPool.isNotEmpty) {
      final idx = _newPool.removeAt(0);
      _words[idx].phase = WordPhase.introduced;
      _words[idx].timesIntroduced++;
      _introBuffer.add(idx);
      _totalIntroductions++;
      _tickReviews();
      return ShowIntroduction(entry: _words[idx].entry, isRetry: false);
    }

    // 5. Drain remaining introduced words (1 left).
    if (_introBuffer.isNotEmpty) {
      final idx = _introBuffer.removeAt(0);
      return _buildQuiz(idx);
    }

    // 6. Drain remaining spaced reviews (skip fully-learned sentinels).
    for (int i = 0; i < _words.length; i++) {
      if (_words[i].phase == WordPhase.learned &&
          _words[i].debugActionsUntilReview > 0 &&
          _words[i].debugActionsUntilReview < 1000) {
        _words[i].scheduleReview(1);
        return _buildQuiz(i);
      }
    }

    // 7. All done.
    return _complete();
  }

  SessionComplete _complete() {
    return SessionComplete(
      results: _words,
      totalIntroductions: _totalIntroductions,
      totalQuizzes: _totalQuizzes,
      totalWrong: _totalWrong,
      lessonId: lesson.id,
    );
  }

  void completeIntroduction() {
    _tickReviews();
    if (_retryBuffer.isNotEmpty && _retryState == 0) {
      _retryState = 1;
    }
  }

  QuizOutcome answerQuiz(int wordIndex, Entry selected) {
    final word = _words[wordIndex];
    final isCorrect = selected.key == word.entry.key;
    _totalQuizzes++;
    word.timesQuizzed++;

    if (isCorrect) {
      word.correctStreak++;
      word.phase = WordPhase.learned;
      // Only schedule spaced review for first 2 successes.
      if (word.correctStreak <= 2) {
        final interval = switch (word.correctStreak) {
          1 => 4,
          2 => 8,
          _ => 0,
        };
        word.scheduleReview(interval);
      } else {
        // No more reviews — mark as fully learned.
        word.scheduleReview(1000000);
      }
      _retryBuffer.remove(wordIndex);
      _tickReviews();
      return QuizOutcome.correct;
    } else {
      word.correctStreak = 0;
      word.timesWrong++;
      _totalWrong++;
      _retryBuffer.remove(wordIndex);
      // After 2 consecutive wrong answers, defer — let other words in.
      if (word.timesWrong >= 2) {
        word.phase = WordPhase.learned;
        word.scheduleReview(2);
        _laterPool.add(wordIndex);
        _tickReviews();
        return QuizOutcome.wrong;
      }
      word.phase = WordPhase.needsRetry;
      _retryBuffer.add(wordIndex);
      _retryState = 0;
      _tickReviews();
      return QuizOutcome.wrong;
    }
  }

  void skipQuiz(int wordIndex) {
    final word = _words[wordIndex];
    word.correctStreak = 0;
    word.timesWrong++;
    word.phase = WordPhase.learned;
    word.scheduleReview(2);
    _laterPool.add(wordIndex);
    _totalWrong++;
    _tickReviews();
  }

  ShowQuiz _buildQuiz(int wordIndex) {
    final word = _words[wordIndex];
    final correct = word.entry;
    final showTarget = _rng.nextBool();

    final pool = List<Entry>.from(lesson.entries)
      ..removeWhere((e) => e.key == correct.key);
    pool.shuffle(_rng);
    final distractors = pool.take(3).toList();

    while (distractors.length < 3) {
      for (final w in _words) {
        if (w.entry.key != correct.key &&
            !distractors.any((d) => d.key == w.entry.key)) {
          distractors.add(w.entry);
          if (distractors.length >= 3) break;
        }
      }
      break;
    }

    final options = [correct, ...distractors]..shuffle(_rng);

    return ShowQuiz(
      entry: correct,
      wordIndex: wordIndex,
      showTarget: showTarget,
      options: options,
    );
  }

  void _tickReviews() {
    for (final word in _words) {
      word.tickReview();
    }
  }
}
