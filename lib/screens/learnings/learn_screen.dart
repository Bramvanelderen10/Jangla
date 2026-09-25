import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../models/quiz_models.dart';
import '../../services/learn_session.dart';
import '../../services/quiz_stats_service.dart';
import '../../services/tts_service.dart';

class LearnScreen extends StatefulWidget {
  final Lesson lesson;
  final TtsService tts;
  final QuizStatsService stats;

  /// Maps an entry back to the lesson it came from. Defaults to [lesson]'s id;
  /// Daily Review uses it so a mixed session still records results (and thus
  /// the review schedule) against each entry's original lesson.
  final String? Function(Entry entry)? lessonIdFor;

  const LearnScreen({
    super.key,
    required this.lesson,
    required this.tts,
    required this.stats,
    this.lessonIdFor,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LearnSession _session;
  LearnAction? _action;
  bool _answered = false;
  bool _wasCorrect = false;
  Entry? _selectedOption;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _session = LearnSession(
      widget.lesson,
      allowAudio: widget.tts.voiceAvailable,
    );
    _advance();
  }

  void _advance() {
    setState(() {
      _action = _session.nextAction();
      _answered = false;
      _wasCorrect = false;
      _selectedOption = null;
      _flipped = false;
    });
    _speakIfAudioPrompt();
  }

  /// Audio-prompt questions play automatically (the card shows no text),
  /// deferred to after the frame so `TtsService` is not called during build.
  void _speakIfAudioPrompt() {
    final action = _action;
    if (action is! ShowQuiz || !action.direction.isAudio) return;
    if (!widget.tts.voiceAvailable) return;
    final entry = action.entry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.tts.speak(entry.target, pronunciation: entry.ttsText);
    });
  }

  void _onIntroductionDone() {
    _session.completeIntroduction();
    _advance();
  }

  void _onAnswer(Entry selected) {
    if (_answered) return;

    final quiz = _action as ShowQuiz;
    widget.tts.speak(quiz.entry.target, pronunciation: quiz.entry.ttsText);

    final outcome = _session.answerQuiz(quiz.wordIndex, selected);
    widget.stats.record(
      widget.lessonIdFor?.call(quiz.entry) ?? widget.lesson.id,
      quiz.entry,
      outcome == QuizOutcome.correct,
    );
    setState(() {
      _answered = true;
      _wasCorrect = outcome == QuizOutcome.correct;
      _selectedOption = selected;
    });
  }

  void _onSkip() {
    final quiz = _action as ShowQuiz;
    _session.skipQuiz(quiz.wordIndex);
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    if (_action == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_action is SessionComplete) {
      return _buildCompleteScreen(_action as SessionComplete);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value:
                _session.totalWords == 0
                    ? 0
                    : _session.learnedCount / _session.totalWords,
          ),
        ),
      ),
      body:
          _action is ShowIntroduction
              ? _buildIntroduction(_action as ShowIntroduction)
              : _buildQuiz(_action as ShowQuiz),
    );
  }

  // ---- introduction (tap-to-flip card) ----

  Widget _buildIntroduction(ShowIntroduction action) {
    final entry = action.entry;
    widget.tts.speak(entry.target, pronunciation: entry.ttsText);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _flipped = !_flipped),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  action.isRetry ? "Let's try again!" : 'New word',
                  style: TextStyle(
                    fontSize: 13,
                    color: action.isRetry ? Colors.orange : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _englishSide(entry),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _onIntroductionDone,
                  icon: const Icon(Icons.check),
                  label: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _englishSide(Entry entry) {
    return Column(
      key: const ValueKey('en'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.english,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.target,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.roman,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                IconButton.filledTonal(
                  iconSize: 26,
                  onPressed:
                      () => widget.tts.speak(
                        entry.target,
                        pronunciation: entry.ttsText,
                      ),
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen in ${widget.tts.languageName}',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---- quiz ----

  Widget _buildQuiz(ShowQuiz quiz) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quiz.direction.isAudio) ...[
                  Text(
                    'What did you hear?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  IconButton.filled(
                    iconSize: 40,
                    onPressed:
                        () => widget.tts.speak(
                          quiz.entry.target,
                          pronunciation: quiz.entry.ttsText,
                        ),
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Play again',
                  ),
                ] else ...[
                  if (quiz.direction == QuizDirection.targetToEn) ...[
                    Text(
                      quiz.entry.target,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz.entry.roman,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.teal,
                      ),
                    ),
                  ] else
                    Text(
                      quiz.entry.english,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed:
                        () => widget.tts.speak(
                          quiz.entry.target,
                          pronunciation: quiz.entry.ttsText,
                        ),
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Listen',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            (quiz.options.length / 2).ceil(),
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    if (row * 2 + col < quiz.options.length)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: col == 0 ? 0 : 5,
                            right: col == 0 ? 5 : 0,
                          ),
                          child: _optionButton(
                            quiz.options[row * 2 + col],
                            row * 2 + col,
                            quiz,
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_answered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _wasCorrect ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _wasCorrect ? 'Correct!' : 'Not quite',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap Next to continue',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _answered ? null : _onSkip,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
              ),
              if (_answered)
                FilledButton(onPressed: _advance, child: const Text('Next')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionButton(Entry option, int index, ShowQuiz quiz) {
    Color? bg;
    Color? fg;
    if (_answered) {
      if (option.key == quiz.entry.key) {
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
      } else if (option == _selectedOption && !_wasCorrect) {
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
      }
    }
    final fadedColor = _answered && option.key != quiz.entry.key;
    return OutlinedButton(
      onPressed: _answered ? null : () => _onAnswer(option),
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quiz.direction.answerInTarget ? option.target : option.english,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: fadedColor ? Colors.grey[600] : null,
            ),
          ),
          if (quiz.direction.answerInTarget) ...[
            const SizedBox(height: 2),
            Text(
              option.roman,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: fadedColor ? Colors.grey[500] : Colors.teal.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleteScreen(SessionComplete done) {
    final learned =
        done.results.where((w) => w.phase == WordPhase.learned).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Session complete')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Well done!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              _statRow('Words learned', '$learned / ${done.results.length}'),
              _statRow('Introductions', '${done.totalIntroductions}'),
              _statRow('Quizzes answered', '${done.totalQuizzes}'),
              _statRow('Mistakes', '${done.totalWrong}'),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _session = LearnSession(
                      widget.lesson,
                      allowAudio: widget.tts.voiceAvailable,
                    );
                    _advance();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Restart'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to lessons'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
