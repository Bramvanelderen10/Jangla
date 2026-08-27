import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../models/custom_list.dart';
import '../services/custom_list_service.dart';
import '../services/quiz_stats_service.dart';
import '../services/tts_service.dart';
import 'entry_picker_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

/// View and edit a single custom list: add or remove entries and practise it.
class CustomListEditScreen extends StatefulWidget {
  final CustomList list;
  final AppContent content;
  final CustomListService service;
  final TtsService tts;
  final QuizStatsService stats;

  const CustomListEditScreen({
    super.key,
    required this.list,
    required this.content,
    required this.service,
    required this.tts,
    required this.stats,
  });

  @override
  State<CustomListEditScreen> createState() => _CustomListEditScreenState();
}

class _CustomListEditScreenState extends State<CustomListEditScreen> {
  CustomList get _list => widget.list;

  Future<void> _addWords() async {
    final picked = await Navigator.push<List<Entry>>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryPickerScreen(
          content: widget.content,
          alreadyAdded: _list.entries.map((e) => e.key).toSet(),
        ),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      await widget.service.addEntries(_list, picked);
      if (mounted) setState(() {});
    }
  }

  Future<void> _remove(Entry entry) async {
    await widget.service.removeEntry(_list, entry);
    if (mounted) setState(() {});
  }

  void _practise(Widget screen) {
    if (_list.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some words first.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _list.entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          IconButton(
            onPressed: _addWords,
            icon: const Icon(Icons.add),
            tooltip: 'Add words',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _practise(
                      FlashcardScreen(lesson: _list.toLesson(), tts: widget.tts),
                    ),
                    icon: const Icon(Icons.style),
                    label: const Text('Flashcards'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _practise(
                      QuizScreen(
                        lesson: _list.toLesson(),
                        tts: widget.tts,
                        stats: widget.stats,
                      ),
                    ),
                    icon: const Icon(Icons.quiz),
                    label: const Text('Quiz'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No words yet.\nTap + to add words from the lessons.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      return ListTile(
                        title: Text(
                          entry.target,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${entry.roman} · ${entry.english}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              tooltip: 'Listen',
                              onPressed: () => widget.tts.speak(entry.target),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Remove',
                              onPressed: () => _remove(entry),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
