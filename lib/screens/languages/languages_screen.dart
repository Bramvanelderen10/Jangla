import 'package:flutter/material.dart';

import '../../data/course_repository.dart';
import '../../models/course.dart';
import 'import_language_screen.dart';

/// Lists the courses the app can learn from — the bundled ones and the user's
/// own imports — and lets the user add or remove a language.
class LanguagesScreen extends StatefulWidget {
  final List<Course> courses;
  final Course current;
  final CourseRepository repo;
  final ValueChanged<Course> onSelect;

  /// Asks the home screen to reload its course list (optionally switching to a
  /// just-imported course).
  final Future<void> Function(Course? select) onChanged;

  const LanguagesScreen({
    super.key,
    required this.courses,
    required this.current,
    required this.repo,
    required this.onSelect,
    required this.onChanged,
  });

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  late List<Course> _courses = widget.courses;
  List<String> _errors = const [];

  Future<void> _reload() async {
    final courses = await widget.repo.loadCourses();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _errors = List.of(widget.repo.loadErrors);
    });
  }

  Future<void> _import() async {
    final imported = await Navigator.push<Course>(
      context,
      MaterialPageRoute(builder: (_) => ImportLanguageScreen(repo: widget.repo)),
    );
    if (imported == null) return;
    await widget.onChanged(imported);
    if (mounted) Navigator.pop(context);
  }

  void _select(Course course) {
    widget.onSelect(course);
    Navigator.pop(context);
  }

  Future<void> _delete(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Remove "${course.name}"?'),
            content: const Text(
              'This removes the imported language and its lessons from the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (!(confirmed ?? false)) return;
    final wasCurrent = course.id == widget.current.id;
    await widget.repo.deleteCourse(course);
    await widget.onChanged(null);
    if (!mounted) return;
    if (wasCurrent) {
      Navigator.pop(context);
      return;
    }
    await _reload();
  }

  Future<void> _rename(Course course) async {
    final controller = TextEditingController(text: course.name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Rename course'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'Progress follows the new name',
              ),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (name == null) return;

    final result = await widget.repo.renameCourse(course, name);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errors.first)));
      return;
    }

    final renamed = result.course!;
    // Only switch the app over when the renamed course was the active one.
    await widget.onChanged(course.id == widget.current.id ? renamed : null);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Languages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.upload_file),
        label: const Text('Import JSON'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errors.isNotEmpty) ...[
            _LoadErrorsCard(errors: _errors),
            const SizedBox(height: 12),
          ],
          const Text(
            'Installed languages',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final course in _courses)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  child: Icon(
                    course.isBundled ? Icons.public : Icons.download_done,
                  ),
                ),
                title: Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${course.language.nativeName} · ${course.language.code}'
                  '${course.isBundled ? ' · built-in' : ''}',
                ),
                onTap: () => _select(course),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (course.id == widget.current.id)
                      const Icon(Icons.check, color: Colors.teal),
                    if (!course.isBundled)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') _rename(course);
                          if (value == 'remove') _delete(course);
                        },
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove'),
                              ),
                            ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const _FormatHelpCard(),
        ],
      ),
    );
  }
}

class _LoadErrorsCard extends StatelessWidget {
  final List<String> errors;

  const _LoadErrorsCard({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some bundled courses could not be loaded',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 6),
            for (final error in errors)
              Text(error, style: TextStyle(color: Colors.red.shade900)),
          ],
        ),
      ),
    );
  }
}

/// Explains the course file format, so a user can create their own language.
class _FormatHelpCard extends StatelessWidget {
  const _FormatHelpCard();

  static const String _example = '''
{
  "name": "Business Japanese",
  "language": {
    "code": "ja",
    "nativeName": "日本語",
    "ttsLocales": ["ja-JP", "ja"]
  },
  "defaults": { "entriesPerSession": 10 },
  "categories": [
    {
      "id": "meetings",
      "title": "Meetings",
      "lessons": [
        {
          "id": "greetings",
          "title": "Greetings",
          "entries": [
            { "en": "Nice to meet you.",
              "bn": "はじめまして。",
              "roman": "hajimemashite." }
          ]
        }
      ]
    }
  ]
}''';

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('How do I make a course file?'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text(
            'A course file is a single JSON file. "name" is what appears in '
            'the app (give it a unique name). "language.code" is the language '
            'for text-to-speech. Every entry needs "en", "bn" (the '
            'target-language text) and "roman".',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                _example,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
