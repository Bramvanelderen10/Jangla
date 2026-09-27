/// Folding and comparison for typed quiz answers.
///
/// Learners can rarely type exactly what the content shows, so answers are
/// compared loosely:
///
/// * accents and special characters fold to plain ASCII (`o` == `ō`),
/// * bracketed asides are ignored (`rice` == `rice (cooked)`),
/// * everything that isn't a letter or digit is dropped — including spaces, so
///   `round trip` == `round-trip` and `icecream` == `ice cream`.
library;

/// Characters that compare equal to their plain ASCII form.
const Map<String, String> _foldedCharacters = {
  // Long vowels in the Japanese romanization.
  'ā': 'a',
  'ē': 'e',
  'ī': 'i',
  'ō': 'o',
  'ū': 'u',
  // Under/over-dotted consonants in the Bengali romanization.
  'ḍ': 'd',
  'ṭ': 't',
  'ṇ': 'n',
  'ṃ': 'm',
  'ḥ': 'h',
  'ś': 's',
  'ṣ': 's',
  'ṛ': 'r',
  'ñ': 'n',
  // Common Latin accents, in case the content or a learner uses them.
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
};

final RegExp _parenthesised = RegExp(r'\([^)]*\)');
final RegExp _bracketed = RegExp(r'\[[^\]]*\]');
final RegExp _braced = RegExp(r'\{[^}]*\}');
final RegExp _notAlphanumeric = RegExp(r'[^a-z0-9]');

/// Normalizes [value] for comparison: lowercased, with bracketed asides,
/// accents, punctuation and whitespace all removed.
String normalizeAnswer(String value) {
  var text = value.toLowerCase();
  // Bracketed asides are hints, not part of the answer.
  text = text
      .replaceAll(_parenthesised, ' ')
      .replaceAll(_bracketed, ' ')
      .replaceAll(_braced, ' ');

  final folded = StringBuffer();
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    folded.write(_foldedCharacters[character] ?? character);
  }

  return folded.toString().replaceAll(_notAlphanumeric, '');
}

/// True when [typed] matches [expected].
///
/// [expected] may list synonyms separated by `/`, and bracketed asides are
/// ignored on both sides.
bool isTypedAnswerCorrect(String typed, String expected) {
  final answer = normalizeAnswer(typed);
  if (answer.isEmpty) return false;

  for (final alternative in expected.split('/')) {
    final candidate = normalizeAnswer(alternative);
    if (candidate.isNotEmpty && candidate == answer) return true;
  }
  return false;
}
