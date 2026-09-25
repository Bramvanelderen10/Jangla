import 'package:flutter/material.dart';

import 'data/content_repository.dart';
import 'models/content_models.dart';
import 'models/language.dart';
import 'screens/categories/categories_screen.dart';
import 'services/custom_list_service.dart';
import 'services/quiz_stats_service.dart';
import 'services/tts_service.dart';

void main() {
  runApp(const JanglaApp());
}

class JanglaApp extends StatelessWidget {
  const JanglaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jangla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00695C),
        useMaterial3: true,
      ),
      home: const HomeLoader(),
    );
  }
}

/// Loads the language config and the selected language's content, then shows
/// the category list. Switching language re-loads the matching content file
/// and reconfigures text-to-speech.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> {
  final ContentRepository _repo = ContentRepository();
  final QuizStatsService _stats = QuizStatsService();
  final CustomListService _customLists = CustomListService();

  AppConfig? _config;
  LanguageOption? _language;
  TtsService? _tts;
  late Future<AppContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
  }

  Future<AppContent> _bootstrap() async {
    await _stats.init();
    await _customLists.init();
    final config = await _repo.loadConfig();
    _config = config;
    final savedCode = await _repo.loadSelectedLanguageCode();
    final language =
        config.languageForCode(savedCode) ?? config.defaultLanguage;
    return _selectAndLoad(language);
  }

  /// Points the app at [language]: reconfigures TTS and loads its content.
  Future<AppContent> _selectAndLoad(LanguageOption language) async {
    _language = language;
    // Stats are language-scoped, so switch the namespace before any content
    // (and therefore any lesson id) is used.
    _stats.setLanguageScope(language.code);
    await _tts?.stop();
    final tts = TtsService(language);
    _tts = tts;
    await tts.init();
    return _repo.loadContent(language);
  }

  void _switchLanguage(LanguageOption language) {
    if (language.code == _language?.code) return;
    _repo.saveSelectedLanguageCode(language.code);
    setState(() {
      _future = _selectAndLoad(language);
    });
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
          tts: _tts!,
          stats: _stats,
          customLists: _customLists,
          language: _language!,
          languages: _config!.languages,
          onSelectLanguage: _switchLanguage,
        );
      },
    );
  }
}
