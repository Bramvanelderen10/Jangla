import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../services/quiz_stats_service.dart';
import '../../services/tts_service.dart';
import '../learnings/learn_screen.dart';
import '../quizes/quiz_screen.dart';

class LessonsScreen extends StatefulWidget {
  final Category category;
  final TtsService tts;
  final QuizStatsService stats;

  const LessonsScreen({
    super.key,
    required this.category,
    required this.tts,
    required this.stats,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  /// Opens [screen] and refreshes on return, so the mastery bars reflect the
  /// session that just finished.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.category.lessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final lesson = widget.category.lessons[i];
          final mastery = widget.stats.mastery(lesson);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.entries.length} entries · '
                    '${lesson.entriesPerSession} per session',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  _MasteryBar(mastery: mastery),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          () => _open(
                            LearnScreen(
                              lesson: lesson,
                              tts: widget.tts,
                              stats: widget.stats,
                            ),
                          ),
                      icon: const Icon(Icons.school),
                      label: const Text('Learn'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          () => _open(
                            QuizScreen(
                              lesson: lesson,
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
          );
        },
      ),
    );
  }
}

/// Progress through a lesson: how much has stuck, and how much is due today.
class _MasteryBar extends StatelessWidget {
  final LessonMastery mastery;

  const _MasteryBar({required this.mastery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = mastery.isComplete;
    final color = complete ? Colors.teal : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: mastery.progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${mastery.learned} / ${mastery.total} learned',
              style: TextStyle(
                fontSize: 13,
                fontWeight: complete ? FontWeight.w600 : FontWeight.normal,
                color: complete ? Colors.teal.shade700 : Colors.grey[700],
              ),
            ),
            const Spacer(),
            if (complete)
              Text(
                'Mastered',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
              )
            else if (mastery.due > 0)
              Text(
                '${mastery.due} due',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

