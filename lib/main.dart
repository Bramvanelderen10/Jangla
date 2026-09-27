import 'package:flutter/material.dart';

import 'data/course_repository.dart';
import 'models/content_models.dart';
import 'models/course.dart';
import 'screens/categories/categories_screen.dart';
import 'services/custom_list_service.dart';
import 'services/imported_course_service.dart';
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

/// Loads the available courses and the selected course's content, then shows
/// the category list. Switching course re-loads the matching content and
/// reconfigures text-to-speech.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> {
  final ImportedCourseService _imported = ImportedCourseService();
  final QuizStatsService _stats = QuizStatsService();
  final CustomListService _customLists = CustomListService();
  late final CourseRepository _repo = CourseRepository(_imported, _stats);

  List<Course> _courses = const [];
  Course? _course;
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
    await _imported.init();
    final courses = await _repo.loadCourses();
    _courses = courses;
    final course = _repo.resolveSelection(
      courses,
      await _repo.loadSelectedCourseId(),
    );
    if (course == null) {
      throw StateError('No courses are available.');
    }
    return _selectAndLoad(course);
  }

  /// Points the app at [course]: reconfigures TTS and loads its content.
  Future<AppContent> _selectAndLoad(Course course) async {
    _course = course;
    // Stats are course-scoped, so switch the namespace before any lesson id
    // is used.
    _stats.setCourseScope(course.id);
    await _tts?.stop();
    final tts = TtsService(course.language, displayName: course.name);
    _tts = tts;
    await tts.init();
    return _repo.contentFor(course);
  }

  void _switchCourse(Course course) {
    if (course.id == _course?.id) return;
    _repo.saveSelectedCourseId(course.id);
    setState(() {
      _future = _selectAndLoad(course);
    });
  }

  /// Reloads the course list after the languages screen imports or deletes
  /// something. Pass [select] to jump to a newly imported course; if the active
  /// course is gone the default takes over.
  Future<void> _reloadCourses(Course? select) async {
    final courses = await _repo.loadCourses();
    if (!mounted) return;
    final target = select ?? _repo.resolveSelection(courses, _course?.id);
    setState(() {
      _courses = courses;
      if (target != null && target.id != _course?.id) {
        _repo.saveSelectedCourseId(target.id);
        _future = _selectAndLoad(target);
      }
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
          course: _course!,
          courses: _courses,
          repo: _repo,
          onSelectCourse: _switchCourse,
          onCoursesChanged: _reloadCourses,
        );
      },
    );
  }
}
