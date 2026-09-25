/// Which side a question is asked from: what the learner is given, and what
/// they have to produce.
enum QuizDirection {
  /// Prompt in English; answer in the target language.
  enToTarget,

  /// Prompt in the target-language script; answer in English.
  targetToEn,

  /// Prompt is audio only; answer is the English meaning.
  ///
  /// This is deliberately the only listening variant. An audio prompt whose
  /// answers are written in the target language collapses into "which
  /// romanization matches the sound?" — the script becomes decoration and no
  /// reading or meaning is tested.
  audioToEn;

  /// True when the prompt is played rather than written, so the text must be
  /// hidden and the audio auto-played (with a replay button available).
  bool get isAudio => this == audioToEn;

  /// True when the answer is shown in the target language, which is exactly
  /// when the romanization is a useful hint rather than a giveaway.
  bool get answerInTarget => this == enToTarget;
}
