import 'package:flutter/material.dart';

import '../models/content_models.dart';

/// Lets the user search all existing content and pick entries to add to a
/// custom list. Returns the selected entries, or null if cancelled.
class EntryPickerScreen extends StatefulWidget {
  final AppContent content;

  /// Keys ([Entry.key]) already in the target list; shown as disabled.
  final Set<String> alreadyAdded;

  const EntryPickerScreen({
    super.key,
    required this.content,
    required this.alreadyAdded,
  });

  @override
  State<EntryPickerScreen> createState() => _EntryPickerScreenState();
}

class _EntryPickerScreenState extends State<EntryPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = {};
  late final List<Entry> _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // De-duplicate content entries by key.
    final seen = <String>{};
    _all = [
      for (final e in widget.content.allEntries)
        if (seen.add(e.key)) e,
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Entry> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where((e) =>
            e.english.toLowerCase().contains(q) ||
            e.roman.toLowerCase().contains(q) ||
            e.target.contains(_query))
        .toList();
  }

  void _done() {
    final picked =
        _all.where((e) => _selected.contains(e.key)).toList(growable: false);
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty
            ? 'Add words'
            : 'Add words (${_selected.length})'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _done,
            child: const Text('Add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search words or sentences',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final entry = filtered[i];
                final added = widget.alreadyAdded.contains(entry.key);
                final checked = _selected.contains(entry.key);
                return CheckboxListTile(
                  value: added || checked,
                  onChanged: added
                      ? null
                      : (v) => setState(() {
                            if (v ?? false) {
                              _selected.add(entry.key);
                            } else {
                              _selected.remove(entry.key);
                            }
                          }),
                  title: Text(
                    entry.target,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    added
                        ? '${entry.roman} · ${entry.english}  (already added)'
                        : '${entry.roman} · ${entry.english}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
