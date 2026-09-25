/// Which side a question is asked from: what the learner is given, and what
/// they have to produce.
enum QuizDirection {
  /// Prompt in English; answer in the target language.
  enToTarget,

  /// Prompt in the target-language script; answer in English.
  targetToEn,

  /// Prompt is audio only; answer is the English meaning.
  audioToEn,

  /// Prompt is audio only; answer is the written target-language script.
  audioToTarget;

  /// True when the prompt is played rather than written, so the text must be
  /// hidden and the audio auto-played (with a replay button available).
  bool get isAudio => this == audioToEn || this == audioToTarget;

  /// True when the answer is shown in the target language.
  bool get answerInTarget => this == enToTarget || this == audioToTarget;
}
