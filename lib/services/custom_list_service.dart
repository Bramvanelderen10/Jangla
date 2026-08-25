import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';
import '../models/custom_list.dart';

/// Persists user-made practice lists via shared_preferences.
class CustomListService {
  static const String _prefsKey = 'custom_lists_v1';

  final List<CustomList> _lists = [];
  SharedPreferences? _prefs;

  List<CustomList> get lists => List.unmodifiable(_lists);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        _lists
          ..clear()
          ..addAll(decoded
              .map((e) => CustomList.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // Start with no lists if storage is unavailable.
    }
  }

  Future<CustomList> create(String name) async {
    final list = CustomList(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Untitled list' : name.trim(),
      entries: [],
    );
    _lists.add(list);
    await _persist();
    return list;
  }

  Future<void> rename(CustomList list, String name) async {
    if (name.trim().isEmpty) return;
    list.name = name.trim();
    await _persist();
  }

  Future<void> delete(CustomList list) async {
    _lists.removeWhere((l) => l.id == list.id);
    await _persist();
  }

  /// Adds entries, skipping any already present in the list.
  Future<void> addEntries(CustomList list, Iterable<Entry> entries) async {
    final existing = list.entries.map((e) => e.key).toSet();
    for (final entry in entries) {
      if (existing.add(entry.key)) list.entries.add(entry);
    }
    await _persist();
  }

  Future<void> removeEntry(CustomList list, Entry entry) async {
    list.entries.removeWhere((e) => e.key == entry.key);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode(_lists.map((l) => l.toJson()).toList()),
      );
    } catch (_) {
      // Ignore write failures; lists remain in memory for this session.
    }
  }
}
