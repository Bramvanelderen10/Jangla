import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../services/quiz_stats_service.dart';
import '../../services/tts_service.dart';
import '../learnings/learn_screen.dart';

/// A mixed review session drawn from every lesson that is due today.
///
/// Reuses [LearnScreen] (and therefore the whole introduce → quiz → retry
/// loop) by wrapping the due entries in a synthetic [Lesson]. Each answer is
/// attributed back to the lesson the entry came from through
/// [LearnScreen.lessonIdFor], so the spaced-repetition schedule stays attached
/// to the original lesson instead of the synthetic one.
class DailyReviewScreen extends StatefulWidget {
  final List<Lesson> lessons;
  final TtsService tts;
  final QuizStatsService stats;
  final int maxEntries;

  const DailyReviewScreen({
    super.key,
    required this.lessons,
    required this.tts,
    required this.stats,
    this.maxEntries = 15,
  });

  @override
  State<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends State<DailyReviewScreen> {
  late final List<ReviewItem> _items;
  late final Lesson _lesson;
  late final Map<String, String> _lessonIdByEntry;

  @override
  void initState() {
    super.initState();
    _items = widget.stats.dueEntries(
      widget.lessons,
      limit: widget.maxEntries,
    );
    _lesson = Lesson(
      id: 'daily_review',
      title: 'Daily Review',
      entriesPerSession: 0,
      entries: [for (final item in _items) item.entry],
    );
    _lessonIdByEntry = {
      for (final item in _items) item.entry.key: item.lessonId,
    };
  }

  String? _lessonIdFor(Entry entry) => _lessonIdByEntry[entry.key];

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const _NothingDueScreen();
    return LearnScreen(
      lesson: _lesson,
      tts: widget.tts,
      stats: widget.stats,
      lessonIdFor: _lessonIdFor,
    );
  }
}

class _NothingDueScreen extends StatelessWidget {
  const _NothingDueScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Review')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.teal.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'All caught up',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nothing is due right now. Practise a lesson with Learn and it '
                'will come back here for review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
