/// Course identity is derived from the course's display name rather than stored
/// in the JSON, so a course file stays human-editable and there is no id for an
/// author to get wrong or duplicate.
///
/// The rule: lowercase, keep Unicode letters/digits, turn every run of other
/// characters into a single `-`, and trim leading/trailing dashes. So
/// "Business Japanese" -> "business-japanese" and "日本語" -> "日本語".
String slugifyCourseName(String name) {
  final buffer = StringBuffer();
  var pendingDash = false;
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (_isLetterOrDigit(char)) {
      if (pendingDash && buffer.isNotEmpty) buffer.write('-');
      pendingDash = false;
      buffer.write(char);
    } else {
      pendingDash = true;
    }
  }
  return buffer.toString();
}

final RegExp _alnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isLetterOrDigit(String char) => _alnum.hasMatch(char);

/// Course ids the bundled courses used before identity was derived from the
/// course name. Used once to migrate the saved selection and the saved stats
/// so existing learners keep their progress.
const Map<String, String> legacyCourseIdAliases = {
  'bn': 'bengali',
  'ja': 'japanese',
  'es': 'spanish',
};

/// Maps a pre-migration id to its current equivalent (or returns it unchanged).
String migrateLegacyCourseId(String id) => legacyCourseIdAliases[id] ?? id;
