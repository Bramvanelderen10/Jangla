import 'dart:math';

/// A single vocabulary/sentence item.
class Entry {
  final String english;

  /// Target-language script (Bengali, Japanese, ...); JSON key stays `bn`.
  final String target;
  final String roman;
  final String? ttsText;

  const Entry({
    required this.english,
    required this.target,
    required this.roman,
    this.ttsText,
  });

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    english: json['en'] as String,
    target: (json['target'] ?? json['bn']) as String,
    roman: (json['roman'] ?? '') as String,
    ttsText: json['tts'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'en': english,
    'bn': target,
    'roman': roman,
    if (ttsText != null) 'tts': ttsText,
  };

  /// Stable string identity used to de-duplicate entries in custom lists.
  String get key => '$english|$target|$roman';
}

/// A lesson: a pool of entries plus how many to show per randomized session.
class Lesson {
  final String id;
  final String title;
  final int entriesPerSession;
  final List<Entry> entries;

  const Lesson({
    required this.id,
    required this.title,
    required this.entriesPerSession,
    required this.entries,
  });

  factory Lesson.fromJson(Map<String, dynamic> json, int defaultPerSession) =>
      Lesson(
        id: json['id'] as String,
        title: json['title'] as String,
        entriesPerSession:
            (json['entriesPerSession'] as int?) ?? defaultPerSession,
        entries:
            (json['entries'] as List)
                .map((e) => Entry.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  /// Returns a shuffled subset of entries for one practice session.
  /// If [entriesPerSession] is 0 or larger than the pool, all entries are used.
  List<Entry> sessionEntries([Random? random]) {
    final rng = random ?? Random();
    final pool = List<Entry>.from(entries)..shuffle(rng);
    final count =
        entriesPerSession <= 0
            ? pool.length
            : min(entriesPerSession, pool.length);
    return pool.take(count).toList();
  }
}

/// A category groups related lessons.
class Category {
  final String id;
  final String title;
  final List<Lesson> lessons;

  const Category({
    required this.id,
    required this.title,
    required this.lessons,
  });

  factory Category.fromJson(Map<String, dynamic> json, int defaultPerSession) =>
      Category(
        id: json['id'] as String,
        title: json['title'] as String,
        lessons:
            (json['lessons'] as List)
                .map(
                  (l) => Lesson.fromJson(
                    l as Map<String, dynamic>,
                    defaultPerSession,
                  ),
                )
                .toList(),
      );
}

/// Root content object loaded from the config asset.
class AppContent {
  final int defaultEntriesPerSession;
  final List<Category> categories;

  const AppContent({
    required this.defaultEntriesPerSession,
    required this.categories,
  });

  /// Every entry across all categories and lessons.
  List<Entry> get allEntries => [
    for (final c in categories)
      for (final l in c.lessons) ...l.entries,
  ];

  factory AppContent.fromJson(Map<String, dynamic> json) {
    final defaults = (json['defaults'] as Map<String, dynamic>?) ?? const {};
    final defaultPerSession = (defaults['entriesPerSession'] as int?) ?? 20;
    return AppContent(
      defaultEntriesPerSession: defaultPerSession,
      categories:
          (json['categories'] as List)
              .map(
                (c) => Category.fromJson(
                  c as Map<String, dynamic>,
                  defaultPerSession,
                ),
              )
              .toList(),
    );
  }
}
