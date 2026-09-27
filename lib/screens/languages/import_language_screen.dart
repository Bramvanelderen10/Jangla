import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/course_repository.dart';

/// Picks a course JSON file, previews it, lets the user adjust the course
/// metadata, and imports it as a new language.
class ImportLanguageScreen extends StatefulWidget {
  final CourseRepository repo;

  const ImportLanguageScreen({super.key, required this.repo});

  @override
  State<ImportLanguageScreen> createState() => _ImportLanguageScreenState();
}

class _ImportLanguageScreenState extends State<ImportLanguageScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _native = TextEditingController();
  final TextEditingController _tts = TextEditingController();

  Map<String, dynamic>? _root;
  String? _fileName;
  List<String> _errors = const [];
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _native.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        setState(() {
          _root = null;
          _errors = const [
            'This is not valid JSON. Check for a missing comma or bracket.',
          ];
        });
        return;
      }
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _root = null;
          _errors = const [
            'The file must contain a JSON object at the top level.',
          ];
        });
        return;
      }
      _fileName = file.name;
      _root = decoded;
      _seedFields(decoded);
      final result = await widget.repo.previewImport(
        _mergedJson(),
        _fileName ?? 'course.json',
      );
      if (!mounted) return;
      setState(() => _errors = result.errors);
    } catch (_) {
      if (mounted) setState(() => _errors = const ['Could not read that file.']);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _seedFields(Map<String, dynamic> root) {
    _name.text = (root['name'] as Object?)?.toString() ?? '';
    final lang = root['language'];
    if (lang is Map<String, dynamic>) {
      _code.text = (lang['code'] as Object?)?.toString() ?? '';
      _native.text = (lang['nativeName'] as Object?)?.toString() ?? '';
      final locales = lang['ttsLocales'];
      if (locales is List) {
        _tts.text = locales.map((e) => e.toString()).join(', ');
      }
    }
  }

  String _mergedJson() {
    final root = Map<String, dynamic>.from(_root!);
    root['name'] = _name.text.trim();
    final lang = Map<String, dynamic>.from(
      (_root!['language'] as Map<String, dynamic>?) ?? const {},
    );
    lang['code'] = _code.text.trim();
    final native = _native.text.trim();
    if (native.isNotEmpty) lang['nativeName'] = native;
    final locales =
        _tts.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    if (locales.isNotEmpty) lang['ttsLocales'] = locales;
    root['language'] = lang;
    return jsonEncode(root);
  }

  String _summary() {
    final categories = _root?['categories'];
    if (categories is! List) return '';
    var lessons = 0;
    var entries = 0;
    for (final category in categories) {
      if (category is Map<String, dynamic> && category['lessons'] is List) {
        final lessonList = category['lessons'] as List;
        lessons += lessonList.length;
        for (final lesson in lessonList) {
          if (lesson is Map<String, dynamic> && lesson['entries'] is List) {
            entries += (lesson['entries'] as List).length;
          }
        }
      }
    }
    return '${categories.length} categories · $lessons lessons · '
        '$entries entries';
  }

  Future<void> _import() async {
    if (_root == null) return;
    setState(() => _busy = true);
    final result = await widget.repo.previewImport(
      _mergedJson(),
      _fileName ?? 'course.json',
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _errors = result.errors;
        _busy = false;
      });
      return;
    }
    await widget.repo.saveImport(result.course!);
    if (!mounted) return;
    Navigator.pop(context, result.course);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import a language')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.folder_open),
            label: Text(
              _root == null ? 'Choose JSON file' : 'Choose a different file',
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_root != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(_fileName ?? 'Course file'),
                subtitle: Text(_summary()),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'Shown in the app, e.g. Business Japanese',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Language code',
                helperText: 'For text-to-speech, e.g. ja',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _native,
              decoration: const InputDecoration(
                labelText: 'Native name',
                helperText: 'e.g. 日本語',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tts,
              decoration: const InputDecoration(
                labelText: 'TTS locales',
                helperText: 'Best first, comma separated, e.g. ja-JP, ja',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Problems to fix',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final error in _errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_root == null || _busy) ? null : _import,
            icon: const Icon(Icons.download_done),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
