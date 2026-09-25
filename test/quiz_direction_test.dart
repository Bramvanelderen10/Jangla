import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/models/quiz_models.dart';
import 'package:jangla/services/learn_session.dart';

void main() {
  Lesson makeLesson({int total = 12}) => Lesson(
    id: 'l',
    title: 'L',
    entriesPerSession: 0,
    entries: [
      for (var i = 0; i < total; i++)
        Entry(english: 'e$i', target: 't$i', roman: 'r$i'),
    ],
  );

  /// Drives a session to completion, collecting every quiz direction seen.
  Set<QuizDirection> directionsFor({
    required bool allowAudio,
    required int seed,
  }) {
    final session = LearnSession(
      makeLesson(),
      random: Random(seed),
      allowAudio: allowAudio,
    );
    final seen = <QuizDirection>{};
    var guard = 0;
    while (guard++ < 2000) {
      final action = session.nextAction();
      if (action is SessionComplete) break;
      if (action is ShowIntroduction) {
        session.completeIntroduction();
      } else if (action is ShowQuiz) {
        seen.add(action.direction);
        session.answerQuiz(action.wordIndex, action.entry);
      }
    }
    return seen;
  }

  test('audio directions are never used when audio is disallowed', () {
    for (var seed = 0; seed < 40; seed++) {
      final seen = directionsFor(allowAudio: false, seed: seed);
      expect(seen.any((d) => d.isAudio), isFalse, reason: 'seed $seed');
    }
  });

  test('both audio directions appear when audio is allowed', () {
    final seen = <QuizDirection>{};
    for (var seed = 0; seed < 40; seed++) {
      seen.addAll(directionsFor(allowAudio: true, seed: seed));
    }
    expect(seen.contains(QuizDirection.audioToEn), isTrue);
    expect(seen.contains(QuizDirection.audioToTarget), isTrue);
  });

  test('direction helpers describe the prompt and answer sides', () {
    expect(QuizDirection.audioToEn.isAudio, isTrue);
    expect(QuizDirection.audioToTarget.isAudio, isTrue);
    expect(QuizDirection.enToTarget.isAudio, isFalse);
    expect(QuizDirection.targetToEn.isAudio, isFalse);

    expect(QuizDirection.audioToEn.answerInTarget, isFalse);
    expect(QuizDirection.audioToTarget.answerInTarget, isTrue);
    expect(QuizDirection.enToTarget.answerInTarget, isTrue);
    expect(QuizDirection.targetToEn.answerInTarget, isFalse);
  });
}
