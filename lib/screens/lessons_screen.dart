import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/quiz_stats_service.dart';
import '../services/tts_service.dart';
import 'flashcard_screen.dart';
import 'learn_screen.dart';
import 'quiz_screen.dart';

class LessonsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: category.lessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final lesson = category.lessons[i];
          final weak = stats.weakCount(lesson);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.entries.length} entries · ${lesson.entriesPerSession} per session',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FlashcardScreen(lesson: lesson, tts: tts),
                            ),
                          ),
                          icon: const Icon(Icons.style),
                          label: const Text('Flashcards'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizScreen(
                                lesson: lesson,
                                tts: tts,
                                stats: stats,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.quiz),
                          label: const Text('Quiz'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LearnScreen(
                            lesson: lesson,
                            tts: tts,
                            stats: stats,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.school),
                      label: const Text('Learn'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            lesson: lesson,
                            tts: tts,
                            stats: stats,
                            mode: QuizMode.reviewMistakes,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.trending_up),
                      label: Text(
                        weak > 0
                            ? 'Review mistakes ($weak to practice)'
                            : 'Review mistakes',
                      ),
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
