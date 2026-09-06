import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../services/tts_service.dart';

class FlashcardScreen extends StatefulWidget {
  final Lesson lesson;
  final TtsService tts;

  const FlashcardScreen({super.key, required this.lesson, required this.tts});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final PageController _controller = PageController();
  late List<Entry> _entries;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _entries = widget.lesson.sessionEntries();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reshuffle() {
    setState(() {
      _entries = widget.lesson.sessionEntries();
      _index = 0;
    });
    _controller.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            onPressed: _reshuffle,
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle again',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LinearProgressIndicator(
              value: _entries.isEmpty ? 0 : (_index + 1) / _entries.length,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _entries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder:
                  (context, i) =>
                      _FlipCard(entry: _entries[i], tts: widget.tts),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${_index + 1} / ${_entries.length}'),
          ),
        ],
      ),
    );
  }
}

class _FlipCard extends StatefulWidget {
  final Entry entry;
  final TtsService tts;

  const _FlipCard({required this.entry, required this.tts});

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> {
  bool _showTarget = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => setState(() => _showTarget = !_showTarget),
        child: Card(
          elevation: 4,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showTarget ? _targetSide(entry) : _englishSide(entry),
              ),
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
        Text(
          entry.english,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        IconButton.filledTonal(
          iconSize: 36,
          onPressed:
              () =>
                  widget.tts.speak(entry.target, pronunciation: entry.ttsText),
          icon: const Icon(Icons.volume_up),
          tooltip: 'Listen in ${widget.tts.languageName}',
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to see ${widget.tts.languageName}',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _targetSide(Entry entry) {
    return Column(
      key: const ValueKey('bn'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.target,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          entry.roman,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 20),
        IconButton.filled(
          iconSize: 36,
          onPressed:
              () =>
                  widget.tts.speak(entry.target, pronunciation: entry.ttsText),
          icon: const Icon(Icons.volume_up),
        ),
        const SizedBox(height: 12),
        const Text('Tap to see English', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
