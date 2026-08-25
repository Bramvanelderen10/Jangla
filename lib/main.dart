import 'package:flutter/material.dart';

import 'data/content_repository.dart';
import 'models/content_models.dart';
import 'screens/categories_screen.dart';
import 'services/custom_list_service.dart';
import 'services/quiz_stats_service.dart';
import 'services/tts_service.dart';

void main() {
  runApp(const BanglaLearnApp());
}

class BanglaLearnApp extends StatelessWidget {
  const BanglaLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learn Bengali',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00695C),
        useMaterial3: true,
      ),
      home: const HomeLoader(),
    );
  }
}

/// Loads content once and shows the category list when ready.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> {
  final ContentRepository _repo = ContentRepository();
  final TtsService _tts = TtsService();
  final QuizStatsService _stats = QuizStatsService();
  final CustomListService _customLists = CustomListService();
  late final Future<AppContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _tts.init();
  }

  Future<AppContent> _load() async {
    await _stats.init();
    await _customLists.init();
    return _repo.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load content:\n${snapshot.error}'),
              ),
            ),
          );
        }
        return CategoriesScreen(
          content: snapshot.data!,
          tts: _tts,
          stats: _stats,
          customLists: _customLists,
        );
      },
    );
  }
}
