import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../models/language.dart';
import '../../services/custom_list_service.dart';
import '../../services/quiz_stats_service.dart';
import '../../services/tts_service.dart';
import '../custom_lists/custom_lists_screen.dart';
import '../lessons/lessons_screen.dart';
import '../review/daily_review_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final AppContent content;
  final TtsService tts;
  final QuizStatsService stats;
  final CustomListService customLists;
  final LanguageOption language;
  final List<LanguageOption> languages;
  final ValueChanged<LanguageOption> onSelectLanguage;

  const CategoriesScreen({
    super.key,
    required this.content,
    required this.tts,
    required this.stats,
    required this.customLists,
    required this.language,
    required this.languages,
    required this.onSelectLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learn ${language.name}'),
        actions: [
          if (languages.length > 1)
            PopupMenuButton<LanguageOption>(
              icon: const Icon(Icons.language),
              tooltip: 'Language',
              onSelected: onSelectLanguage,
              itemBuilder:
                  (context) => [
                    for (final option in languages)
                      PopupMenuItem(
                        value: option,
                        child: Row(
                          children: [
                            Icon(
                              option.code == language.code ? Icons.check : null,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text('${option.name} · ${option.nativeName}'),
                          ],
                        ),
                      ),
                  ],
            ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'My Lists',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CustomListsScreen(
                          content: content,
                          service: customLists,
                          tts: tts,
                          stats: stats,
                        ),
                  ),
                ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: content.categories.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return DailyReviewCard(content: content, tts: tts, stats: stats);
          }
          if (i == 1) {
            return PhraseOfTheDayCard(content: content, tts: tts);
          }
          final category = content.categories[i - 2];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(child: Text('$i')),
              title: Text(
                category.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${category.lessons.length} lessons'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => LessonsScreen(
                            category: category,
                            tts: tts,
                            stats: stats,
                          ),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}

/// A low-pressure daily nudge: a few phrases to focus on today. The selection
/// is seeded by the calendar day, so it stays the same until tomorrow.
class PhraseOfTheDayCard extends StatelessWidget {
  final AppContent content;
  final TtsService tts;

  const PhraseOfTheDayCard({
    super.key,
    required this.content,
    required this.tts,
  });

  List<Entry> _pickForToday() {
    final all = content.allEntries;
    if (all.isEmpty) return const [];
    final now = DateTime.now();
    final daySeed = now.year * 10000 + now.month * 100 + now.day;
    final pool = List<Entry>.from(all)..shuffle(Random(daySeed));
    return pool.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _pickForToday();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  "Today's phrases",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in entries) _phraseRow(context, entry),
          ],
        ),
      ),
    );
  }

  Widget _phraseRow(BuildContext context, Entry entry) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.target,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${entry.roman} · ${entry.english}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                () => tts.speak(entry.target, pronunciation: entry.ttsText),
            icon: const Icon(Icons.volume_up),
            color: theme.colorScheme.onPrimaryContainer,
            tooltip: 'Listen',
          ),
        ],
      ),
    );
  }
}

/// Spaced-repetition entry point: reviews whatever is due across the lessons
/// the learner has already started. The count refreshes after each session.
class DailyReviewCard extends StatefulWidget {
  final AppContent content;
  final TtsService tts;
  final QuizStatsService stats;

  const DailyReviewCard({
    super.key,
    required this.content,
    required this.tts,
    required this.stats,
  });

  @override
  State<DailyReviewCard> createState() => _DailyReviewCardState();
}

class _DailyReviewCardState extends State<DailyReviewCard> {
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _due = widget.stats.dueCount(widget.content.allLessons);
  }

  Future<void> _start() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DailyReviewScreen(
              lessons: widget.content.allLessons,
              tts: widget.tts,
              stats: widget.stats,
            ),
      ),
    );
    if (mounted) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caughtUp = _due == 0;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              caughtUp ? Icons.check_circle_outline : Icons.today,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Review',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caughtUp
                        ? 'All caught up for today'
                        : '$_due ${_due == 1 ? 'word' : 'words'} due',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (!caughtUp)
              FilledButton(onPressed: _start, child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}

