import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content_models.dart';

/// Loads the lesson content from the bundled JSON config asset.
class ContentRepository {
  static const String assetPath = 'assets/content/content.json';

  Future<AppContent> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AppContent.fromJson(json);
  }
}
