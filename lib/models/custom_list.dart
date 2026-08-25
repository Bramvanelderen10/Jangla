import 'content_models.dart';

/// A user-made practice list built from existing content entries.
class CustomList {
  final String id;
  String name;
  final List<Entry> entries;

  CustomList({
    required this.id,
    required this.name,
    required this.entries,
  });

  /// Presents the list as a [Lesson] so the flashcard and quiz screens can use
  /// it unchanged. Uses the whole pool each session (entriesPerSession = 0).
  Lesson toLesson() => Lesson(
        id: id,
        title: name,
        entriesPerSession: 0,
        entries: entries,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory CustomList.fromJson(Map<String, dynamic> json) => CustomList(
        id: json['id'] as String,
        name: json['name'] as String,
        entries: (json['entries'] as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
