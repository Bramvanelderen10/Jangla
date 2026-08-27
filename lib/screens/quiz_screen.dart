import 'dart:math';

import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/quiz_stats_service.dart';
import '../services/tts_service.dart';

/// How the quiz picks its questions.
enum QuizMode {
  /// Random subset of the lesson.
  random,

  /// Weighted toward the words answered wrong most often.
  reviewMistakes,
}

/// Which way the question is asked.
enum QuizDirection {
  /// Prompt in English, answer in Bengali (typed answer is the roman form).
  enToBn,

  /// Prompt in Bengali, answer in English.
  bnToEn,
}

/// The two question formats.
enum QuestionKind { multipleChoice, typing }

/// A single prepared question: the target entry, how it is asked, and the
/// multiple-choice options (only used for [QuestionKind.multipleChoice]).
class _Question {
  final Entry entry;
  final QuestionKind kind;
  final QuizDirection direction;
  final List<Entry> options;

  _Question({
    required this.entry,
    required this.kind,
    required this.direction,
    required this.options,
  });
}

class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  final TtsService tts;
  final QuizStatsService stats;
  final QuizMode mode;

  const QuizScreen({
    super.key,
    required this.lesson,
    required this.tts,
    required this.stats,
    this.mode = QuizMode.random,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const int _optionCount = 5;

  final Random _random = Random();
  final TextEditingController _typedController = TextEditingController();

  late QuizMode _mode;
  late List<_Question> _questions;
  int _index = 0;
  int _score = 0;

  bool _answered = false;
  bool _wasCorrect = false;
  Entry? _selectedOption;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _questions = _buildQuestions();
  }

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  List<_Question> _buildQuestions() {
    final entries =
        _mode == QuizMode.reviewMistakes
            ? widget.stats.reviewEntries(widget.lesson, _random)
            : widget.lesson.sessionEntries(_random);
    return entries.map(_makeQuestion).toList();
  }

  _Question _makeQuestion(Entry entry) {
    final kind =
        _random.nextBool() ? QuestionKind.multipleChoice : QuestionKind.typing;
    final direction =
        _random.nextBool() ? QuizDirection.enToBn : QuizDirection.bnToEn;

    final distractors =
        List<Entry>.from(widget.lesson.entries)
          ..remove(entry)
          ..shuffle(_random);
    final options = [entry, ...distractors.take(_optionCount - 1)]
      ..shuffle(_random);

    return _Question(
      entry: entry,
      kind: kind,
      direction: direction,
      options: options,
    );
  }

  _Question get _current => _questions[_index];

  /// The text a typed answer is compared against for the current direction.
  String get _expectedTyped =>
      _current.direction == QuizDirection.enToBn
          ? _current.entry.roman
          : _current.entry.english;

  String _normalize(String value) =>
      value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  void _answer(bool correct, {Entry? selected}) {
    setState(() {
      _answered = true;
      _wasCorrect = correct;
      _selectedOption = selected;
      if (correct) _score++;
    });
    widget.stats.record(widget.lesson.id, _current.entry, correct);
    widget.tts.speak(_current.entry.bengali);
  }

  void _choose(Entry option) {
    if (_answered) return;
    _answer(option == _current.entry, selected: option);
  }

  void _submitTyped() {
    if (_answered) return;
    if (_typedController.text.trim().isEmpty) return;

    _expectedTyped.split("/").forEach((expected) {
      if (_normalize(_typedController.text) == _normalize(expected)) {
        _answer(true);
        return;
      }
    });

    _answer(false);
    return;
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _answered = false;
        _wasCorrect = false;
        _selectedOption = null;
        _typedController.clear();
      });
    } else {
      _showResult();
    }
  }

  void _restart() {
    setState(() {
      _questions = _buildQuestions();
      _index = 0;
      _score = 0;
      _answered = false;
      _wasCorrect = false;
      _selectedOption = null;
      _typedController.clear();
    });
  }

  void _setMode(QuizMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _restart();
  }

  void _showResult() {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Quiz complete'),
            content: Text('You scored $_score / ${_questions.length}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _restart();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lesson.title} · Quiz'),
        actions: [
          PopupMenuButton<QuizMode>(
            icon: const Icon(Icons.tune),
            tooltip: 'Quiz mode',
            initialValue: _mode,
            onSelected: _setMode,
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: QuizMode.random,
                    child: Text('Random words'),
                  ),
                  PopupMenuItem(
                    value: QuizMode.reviewMistakes,
                    child: Text('Review my mistakes'),
                  ),
                ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (_index + 1) / _questions.length),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score: $_score',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _mode == QuizMode.reviewMistakes
                        ? 'Reviewing mistakes'
                        : 'Random words',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _prompt(),
                      const SizedBox(height: 20),
                      if (_current.kind == QuestionKind.multipleChoice)
                        ..._current.options.map(_optionTile)
                      else
                        _typingArea(),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prompt() {
    final entry = _current.entry;
    final isTyping = _current.kind == QuestionKind.typing;
    final String instruction;
    if (_current.direction == QuizDirection.enToBn) {
      instruction =
          isTyping
              ? 'Type the pronunciation (roman) for:'
              : 'What is the Bengali for:';
    } else {
      instruction =
          isTyping ? 'Type the English for:' : 'What is the English for:';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(instruction, style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 8),
        if (_current.direction == QuizDirection.enToBn)
          Text(
            entry.english,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.bengali,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => widget.tts.speak(entry.bengali),
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Listen',
                  ),
                ],
              ),
              Text(
                entry.roman,
                style: const TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _optionTile(Entry option) {
    final isAnswer = option == _current.entry;
    Color? color;
    if (_answered) {
      if (isAnswer) {
        color = Colors.green.shade100;
      } else if (option == _selectedOption) {
        color = Colors.red.shade100;
      }
    }

    final showBengali = _current.direction == QuizDirection.enToBn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _choose(option),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                showBengali
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.bengali,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          option.roman,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    )
                    : Text(
                      option.english,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _typingArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _typedController,
          enabled: !_answered,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitTyped(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Your answer',
            hintText: 'Type in roman letters',
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _wasCorrect ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _wasCorrect ? 'Correct!' : 'Not quite',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Answer: $_expectedTyped',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  '${_current.entry.bengali} · ${_current.entry.roman}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child:
          _answered
              ? FilledButton(
                onPressed: _next,
                child: Text(_index < _questions.length - 1 ? 'Next' : 'Finish'),
              )
              : _current.kind == QuestionKind.typing
              ? FilledButton(
                onPressed: _submitTyped,
                child: const Text('Check answer'),
              )
              : const SizedBox.shrink(),
    );
  }
}
