import 'dart:math';

import '../models/content_models.dart';
import '../models/quiz_models.dart';

enum WordPhase { new_, introduced, needsRetry, learned, deferred }

enum RetryState { introduction, quiz }

enum QuizOutcome { correct, wrong }

class LearnWord {
  LearnWord({required this.entry});

  final Entry entry;

  WordPhase phase = WordPhase.new_;

  int timesIntroduced = 0;
  int timesQuizzed = 0;
  int timesCorrect = 0;
  int timesWrong = 0;

  int correctStreak = 0;
  int wrongStreak = 0;

  int? _reviewInterval;
  int? _actionsUntilReview;

  bool get reviewDue =>
      phase == WordPhase.learned &&
      _actionsUntilReview != null &&
      _actionsUntilReview! <= 0;

  bool get hasScheduledReview =>
      _reviewInterval != null && _actionsUntilReview != null;

  int? get actionsUntilReview => _actionsUntilReview;

  void tickReview() {
    if (!hasScheduledReview || _actionsUntilReview! <= 0) return;

    _actionsUntilReview = _actionsUntilReview! - 1;
  }

  void scheduleReview(int interval) {
    if (interval <= 0) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Review interval must be greater than zero.',
      );
    }

    _reviewInterval = interval;
    _actionsUntilReview = interval;
  }

  void markFullyLearned() {
    phase = WordPhase.learned;
    _reviewInterval = null;
    _actionsUntilReview = null;
  }
}

// ---------------------------------------------------------------------------
// Actions returned by the learning engine.
// ---------------------------------------------------------------------------

sealed class LearnAction {
  const LearnAction();
}

class ShowIntroduction extends LearnAction {
  const ShowIntroduction({required this.entry, required this.isRetry});

  final Entry entry;
  final bool isRetry;
}

class ShowQuiz extends LearnAction {
  const ShowQuiz({
    required this.entry,
    required this.wordIndex,
    required this.direction,
    required this.options,
  });

  final Entry entry;
  final int wordIndex;
  final QuizDirection direction;
  final List<Entry> options;
}

class SessionComplete extends LearnAction {
  const SessionComplete({
    required this.results,
    required this.totalIntroductions,
    required this.totalQuizzes,
    required this.totalWrong,
    required this.lessonId,
  });

  final List<LearnWord> results;
  final int totalIntroductions;
  final int totalQuizzes;
  final int totalWrong;
  final String lessonId;
}

// ---------------------------------------------------------------------------
// Pure-Dart engine that drives the interleaved introduce-test-retry loop.
// ---------------------------------------------------------------------------

class LearnSession {
  LearnSession(
    this.lesson, {
    Random? random,
    bool allowAudio = false,
  }) : _rng = random ?? Random(),
       _allowAudio = allowAudio {
    _words =
        lesson
            .sessionEntries(_rng)
            .map((entry) => LearnWord(entry: entry))
            .toList();

    if (_words.isNotEmpty) {
      _newPool = List<int>.generate(_words.length, (index) => index)
        ..shuffle(_rng);
    } else {
      _newPool = [];
    }
  }

  final Lesson lesson;
  final Random _rng;

  /// When false (e.g. no target-language voice is installed), audio-prompt
  /// questions are never generated because they would be silent.
  final bool _allowAudio;

  late final List<LearnWord> _words;

  List<LearnWord> get words => List.unmodifiable(_words);

  int get totalWords => _words.length;

  int get learnedCount =>
      _words.where((word) => word.phase == WordPhase.learned).length;

  late final List<int> _newPool;

  final List<int> _introBuffer = [];
  final List<int> _retryBuffer = [];

  RetryState _retryState = RetryState.introduction;

  int _totalIntroductions = 0;
  int _totalQuizzes = 0;
  int _totalWrong = 0;

  LearnAction nextAction() {
    if (_words.isEmpty) {
      return _complete();
    }

    final retryAction = _nextRetryAction();
    if (retryAction != null) {
      return retryAction;
    }

    final bufferedQuiz = _nextBufferedQuiz();
    if (bufferedQuiz != null) {
      return bufferedQuiz;
    }

    final reviewQuiz = _nextDueReview();
    if (reviewQuiz != null) {
      return reviewQuiz;
    }

    final introduction = _nextIntroduction();
    if (introduction != null) {
      return introduction;
    }

    final remainingQuiz = _nextRemainingQuiz();
    if (remainingQuiz != null) {
      return remainingQuiz;
    }

    final finalReview = _nextFinalReview();
    if (finalReview != null) {
      return finalReview;
    }

    return _complete();
  }

  // -------------------------------------------------------------------------
  // Action selection
  // -------------------------------------------------------------------------

  LearnAction? _nextRetryAction() {
    if (_retryBuffer.isEmpty) return null;

    final index = _retryBuffer.first;
    final word = _words[index];

    return switch (_retryState) {
      RetryState.introduction => ShowIntroduction(
        entry: word.entry,
        isRetry: true,
      ),
      RetryState.quiz => _buildQuiz(index),
    };
  }

  ShowQuiz? _nextBufferedQuiz() {
    if (_introBuffer.length < 2) return null;

    final index = _introBuffer.removeAt(0);
    return _buildQuiz(index);
  }

  ShowQuiz? _nextDueReview() {
    for (var index = 0; index < _words.length; index++) {
      if (_words[index].reviewDue) {
        return _buildQuiz(index);
      }
    }

    return null;
  }

  ShowIntroduction? _nextIntroduction() {
    if (_newPool.isEmpty) return null;

    final index = _newPool.removeAt(0);
    final word = _words[index];

    word.phase = WordPhase.introduced;
    word.timesIntroduced++;

    _introBuffer.add(index);
    _totalIntroductions++;

    _tickReviews();

    return ShowIntroduction(entry: word.entry, isRetry: false);
  }

  ShowQuiz? _nextRemainingQuiz() {
    if (_introBuffer.isEmpty) return null;

    final index = _introBuffer.removeAt(0);
    return _buildQuiz(index);
  }

  ShowQuiz? _nextFinalReview() {
    for (var index = 0; index < _words.length; index++) {
      final word = _words[index];

      if (word.phase == WordPhase.deferred && word.reviewDue) {
        return _buildQuiz(index);
      }
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // Session completion
  // -------------------------------------------------------------------------

  SessionComplete _complete() {
    return SessionComplete(
      results: List.unmodifiable(_words),
      totalIntroductions: _totalIntroductions,
      totalQuizzes: _totalQuizzes,
      totalWrong: _totalWrong,
      lessonId: lesson.id,
    );
  }

  // -------------------------------------------------------------------------
  // Introduction handling
  // -------------------------------------------------------------------------

  void completeIntroduction() {
    _tickReviews();

    if (_retryBuffer.isNotEmpty && _retryState == RetryState.introduction) {
      _retryState = RetryState.quiz;
    }
  }

  // -------------------------------------------------------------------------
  // Quiz handling
  // -------------------------------------------------------------------------

  QuizOutcome answerQuiz(int wordIndex, Entry selected) {
    _validateWordIndex(wordIndex);

    final word = _words[wordIndex];
    final isCorrect = selected.key == word.entry.key;

    _totalQuizzes++;
    word.timesQuizzed++;

    if (isCorrect) {
      _handleCorrectAnswer(wordIndex);
      return QuizOutcome.correct;
    }

    _handleWrongAnswer(wordIndex);
    return QuizOutcome.wrong;
  }

  void _handleCorrectAnswer(int wordIndex) {
    final word = _words[wordIndex];

    word.timesCorrect++;
    word.correctStreak++;
    word.wrongStreak = 0;

    word.phase = WordPhase.learned;

    switch (word.correctStreak) {
      case 1:
        word.scheduleReview(4);
      case 2:
        word.scheduleReview(8);
      default:
        word.markFullyLearned();
    }

    _retryBuffer.remove(wordIndex);

    _tickReviews();
  }

  void _handleWrongAnswer(int wordIndex) {
    final word = _words[wordIndex];

    word.timesWrong++;
    word.wrongStreak++;
    word.correctStreak = 0;

    _totalWrong++;

    _retryBuffer.remove(wordIndex);

    if (word.wrongStreak >= 2) {
      _deferWord(wordIndex);
    } else {
      word.phase = WordPhase.needsRetry;
      _retryBuffer.add(wordIndex);
      _retryState = RetryState.introduction;
    }

    _tickReviews();
  }

  void _deferWord(int wordIndex) {
    final word = _words[wordIndex];

    word.phase = WordPhase.deferred;
    word.scheduleReview(2);

    _tickReviews();
  }

  void skipQuiz(int wordIndex) {
    _validateWordIndex(wordIndex);

    final word = _words[wordIndex];

    word.correctStreak = 0;
    word.wrongStreak = 0;
    word.phase = WordPhase.deferred;

    word.scheduleReview(2);

    _tickReviews();
  }

  // -------------------------------------------------------------------------
  // Quiz generation
  // -------------------------------------------------------------------------

  ShowQuiz _buildQuiz(int wordIndex) {
    _validateWordIndex(wordIndex);

    final word = _words[wordIndex];
    final correct = word.entry;

    final distractors = _buildDistractors(correct);

    final options = [correct, ...distractors]..shuffle(_rng);

    return ShowQuiz(
      entry: correct,
      wordIndex: wordIndex,
      direction: _pickDirection(),
      options: options,
    );
  }

  /// Picks how the question is asked. Audio prompts are only used when the
  /// caller allows them, because without a real voice they would be silent.
  QuizDirection _pickDirection() {
    final pool = <QuizDirection>[
      QuizDirection.enToTarget,
      QuizDirection.targetToEn,
      if (_allowAudio) QuizDirection.audioToEn,
    ];
    return pool[_rng.nextInt(pool.length)];
  }

  List<Entry> _buildDistractors(Entry correct) {
    final distractors = <Entry>[];
    final usedKeys = <String>{correct.key};

    final pool =
        List<Entry>.from(lesson.entries)
          ..removeWhere((entry) => entry.key == correct.key)
          ..shuffle(_rng);

    for (final entry in pool) {
      if (distractors.length >= 5) break;

      if (usedKeys.add(entry.key)) {
        distractors.add(entry);
      }
    }

    // If the lesson doesn't contain enough unique entries, use session words
    // as a fallback.
    if (distractors.length < 3) {
      for (final word in _words) {
        if (distractors.length >= 3) break;

        if (usedKeys.add(word.entry.key)) {
          distractors.add(word.entry);
        }
      }
    }

    return distractors;
  }

  // -------------------------------------------------------------------------
  // Review handling
  // -------------------------------------------------------------------------

  void _tickReviews() {
    for (final word in _words) {
      word.tickReview();
    }
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  void _validateWordIndex(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= _words.length) {
      throw RangeError.index(wordIndex, _words, 'wordIndex');
    }
  }
}
