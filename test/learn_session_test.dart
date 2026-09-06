import 'package:bangla_learn/models/content_models.dart';
import 'package:bangla_learn/services/learn_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<Entry> _makeEntries(int n) => List.generate(
      n,
      (i) => Entry(english: 'e$i', target: 'b$i', roman: 'r$i'),
    );

Lesson _makeLesson({int totalEntries = 10, int perSession = 0}) => Lesson(
      id: 'test',
      title: 'Test',
      entriesPerSession: perSession,
      entries: _makeEntries(totalEntries),
    );

void main() {
  test('first action is an introduction of a new word', () {
    final session = LearnSession(_makeLesson());
    final action = session.nextAction();
    expect(action, isA<ShowIntroduction>());
    expect((action as ShowIntroduction).isRetry, false);
  });

  test('after 2 introductions, third action is a quiz on the first word', () {
    final session = LearnSession(_makeLesson());
    expect(session.nextAction(), isA<ShowIntroduction>());
    session.completeIntroduction();
    expect(session.nextAction(), isA<ShowIntroduction>());
   session.completeIntroduction();
    final action = session.nextAction();
    expect(action, isA<ShowQuiz>());
  });

  test('wrong answer triggers re-introduction then re-quiz', () {
    final session = LearnSession(_makeLesson());
    session.nextAction();
    session.completeIntroduction();
    session.nextAction();
    session.completeIntroduction();
    final quiz = session.nextAction() as ShowQuiz;
    final wrongDistractor = quiz.options
        .firstWhere((e) => e.key != quiz.entry.key);
    final outcome = session.answerQuiz(quiz.wordIndex, wrongDistractor);
    expect(outcome, QuizOutcome.wrong);
    final reIntro = session.nextAction();
    expect(reIntro, isA<ShowIntroduction>());
    expect((reIntro as ShowIntroduction).isRetry, true);
    session.completeIntroduction();
    expect(session.nextAction(), isA<ShowQuiz>());
  });

  test('correct answer marks word as learned', () {
    final session = LearnSession(_makeLesson());
    session.nextAction();
    session.completeIntroduction();
    session.nextAction();
    session.completeIntroduction();
    final quiz = session.nextAction() as ShowQuiz;
    session.answerQuiz(quiz.wordIndex, quiz.entry);
    expect(session.words[quiz.wordIndex].phase, WordPhase.learned);
  });

  test('quiz has 4 options with exactly 1 correct', () {
    final session = LearnSession(_makeLesson(totalEntries: 10));
    session.nextAction();
    session.completeIntroduction();
    session.nextAction();
    session.completeIntroduction();
    final quiz = session.nextAction() as ShowQuiz;
    expect(quiz.options.length, 4);
    final correctCount =
        quiz.options.where((e) => e.key == quiz.entry.key).length;
    expect(correctCount, 1);
  });

  test('session completes when all words are learned', () {
    final session = LearnSession(_makeLesson(totalEntries: 3));
    LearnAction? action;
    int loops = 0;
    while (loops < 200) {
      loops++;
      action = session.nextAction();
      if (action is SessionComplete) break;
      if (action is ShowIntroduction) {
        session.completeIntroduction();
      } else if (action is ShowQuiz) {
        session.answerQuiz(action.wordIndex, action.entry);
      }
    }
    expect(action, isA<SessionComplete>());
    final done = action as SessionComplete;
    expect(done.results.where((w) => w.phase == WordPhase.learned).length,
        done.results.length);
  });

  test('empty lesson returns SessionComplete immediately', () {
    final lesson = Lesson(
      id: 'x',
      title: 'X',
      entriesPerSession: 0,
      entries: [],
    );
    final session = LearnSession(lesson);
    expect(session.nextAction(), isA<SessionComplete>());
  });

  test('skipQuiz defers the word rather than forcing an immediate retry', () {
    final session = LearnSession(_makeLesson());
    session.nextAction();
    session.completeIntroduction();
    session.nextAction();
    session.completeIntroduction();
    final quiz = session.nextAction() as ShowQuiz;
    final wordIdx = quiz.wordIndex;
    session.skipQuiz(wordIdx);
    // Word is now deferred (phase = learned with review = 2), so the
    // engine continues with other words instead of looping.
    expect(session.words[wordIdx].phase, WordPhase.learned);
    // Next action should NOT be a retry introduction — it should
    // introduce a new word or continue the session.
    final action = session.nextAction();
    // It can be ShowIntroduction(isRetry: false) or ShowQuiz on another
    // word, but NOT an introduction with isRetry == true for this word.
    if (action is ShowIntroduction) {
      expect(action.isRetry, false);
    }
  });
}