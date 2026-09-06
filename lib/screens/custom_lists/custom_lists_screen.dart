import 'package:flutter/material.dart';

import '../../models/content_models.dart';
import '../../models/custom_list.dart';
import '../../services/custom_list_service.dart';
import '../../services/quiz_stats_service.dart';
import '../../services/tts_service.dart';
import 'custom_list_edit_screen.dart';

/// Lists the user's custom practice lists and lets them create new ones.
class CustomListsScreen extends StatefulWidget {
  final AppContent content;
  final CustomListService service;
  final TtsService tts;
  final QuizStatsService stats;

  const CustomListsScreen({
    super.key,
    required this.content,
    required this.service,
    required this.tts,
    required this.stats,
  });

  @override
  State<CustomListsScreen> createState() => _CustomListsScreenState();
}

class _CustomListsScreenState extends State<CustomListsScreen> {
  Future<String?> _nameDialog({String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(initial.isEmpty ? 'New list' : 'Rename list'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'List name',
                hintText: 'e.g. Dinner with family',
              ),
              onSubmitted: (v) => Navigator.pop(dialogContext, v),
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
  }

  Future<void> _create() async {
    final name = await _nameDialog();
    if (name == null || name.trim().isEmpty) return;
    final list = await widget.service.create(name);
    if (!mounted) return;
    setState(() {});
    _open(list);
  }

  Future<void> _rename(CustomList list) async {
    final name = await _nameDialog(initial: list.name);
    if (name == null || name.trim().isEmpty) return;
    await widget.service.rename(list, name);
    if (mounted) setState(() {});
  }

  Future<void> _delete(CustomList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Delete "${list.name}"?'),
            content: const Text(
              'This removes the list. The words themselves stay '
              'in the lessons.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed ?? false) {
      await widget.service.delete(list);
      if (mounted) setState(() {});
    }
  }

  Future<void> _open(CustomList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CustomListEditScreen(
              list: list,
              content: widget.content,
              service: widget.service,
              tts: widget.tts,
              stats: widget.stats,
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lists = widget.service.lists;
    return Scaffold(
      appBar: AppBar(title: const Text('My Lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body:
          lists.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No lists yet.\nTap "New list" to build your own set of '
                    'words and sentences to practise.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final list = lists[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(child: Icon(Icons.list)),
                      title: Text(
                        list.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('${list.entries.length} words'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') _rename(list);
                          if (value == 'delete') _delete(list);
                        },
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                      ),
                      onTap: () => _open(list),
                    ),
                  );
                },
              ),
    );
  }
}
