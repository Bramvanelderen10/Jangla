import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';
import '../models/language.dart';

/// Loads the language config and per-language lesson content, and remembers
/// which language the user last selected.
class ContentRepository {
  static const String _dir = 'assets/content';
  static const String configPath = '$_dir/config.json';
  static const String _selectedLanguageKey = 'selected_language_v1';

  /// The list of available languages and the default choice.
  Future<AppConfig> loadConfig() async {
    final raw = await rootBundle.loadString(configPath);
    return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Loads the lesson content for [language] from its configured asset file.
  Future<AppContent> loadContent(LanguageOption language) async {
    final raw = await rootBundle.loadString('$_dir/${language.file}');
    return AppContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// The language code the user last chose, or null if none is stored.
  Future<String?> loadSelectedLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedLanguageKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedLanguageCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedLanguageKey, code);
    } catch (_) {
      // Selection just won't persist if storage is unavailable.
    }
  }
}
