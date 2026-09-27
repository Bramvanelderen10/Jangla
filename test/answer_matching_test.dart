import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/services/answer_matching.dart';

void main() {
  group('normalizeAnswer', () {
    test('folds long-vowel macrons to plain ASCII', () {
      expect(normalizeAnswer('tōkyō'), 'tokyo');
      expect(normalizeAnswer('ohayō gozaimasu'), 'ohayogozaimasu');
      expect(normalizeAnswer('kyūkyūsha'), 'kyukyusha');
      expect(normalizeAnswer('jūichi'), 'juichi');
    });

    test('folds Bengali transliteration marks', () {
      expect(normalizeAnswer('ḍ'), 'd');
      expect(normalizeAnswer('paṛa'), 'para');
    });

    test('drops bracketed asides', () {
      expect(normalizeAnswer('rice (cooked)'), 'rice');
      expect(
        normalizeAnswer('Please take me here. (show map)'),
        'pleasetakemehere',
      );
      expect(normalizeAnswer('boxed meal [bento]'), 'boxedmeal');
    });

    test('ignores punctuation and whitespace', () {
      expect(normalizeAnswer("Let's go!"), 'letsgo');
      expect(normalizeAnswer('  I  am   fine '), 'iamfine');
      expect(
        normalizeAnswer('round-trip ticket'),
        normalizeAnswer('round trip ticket'),
      );
    });
  });

  group('isTypedAnswerCorrect', () {
    test('accepts plain ASCII for an accented answer, both ways', () {
      expect(isTypedAnswerCorrect('tokyo', 'Tōkyō'), isTrue);
      expect(isTypedAnswerCorrect('tōkyō', 'tokyo'), isTrue);
      expect(isTypedAnswerCorrect('tokio', 'Tōkyō'), isFalse);
    });

    test('accepts the answer without its bracketed aside', () {
      expect(isTypedAnswerCorrect('rice', 'rice (cooked)'), isTrue);
      expect(isTypedAnswerCorrect('rice (cooked)', 'rice'), isTrue);
      expect(isTypedAnswerCorrect('cooked', 'rice (cooked)'), isFalse);
    });

    test('accepts any slash-separated synonym', () {
      expect(isTypedAnswerCorrect('see', 'see / watch'), isTrue);
      expect(isTypedAnswerCorrect('watch', 'see / watch'), isTrue);
      expect(isTypedAnswerCorrect('look', 'see / watch'), isFalse);
    });

    test('accepts a different word split for hyphenated answers', () {
      expect(isTypedAnswerCorrect('round trip ticket', 'round-trip ticket'),
          isTrue);
      expect(isTypedAnswerCorrect('round-tripticket', 'round-trip ticket'),
          isTrue);
      expect(isTypedAnswerCorrect('one-way', 'one-way ticket'), isFalse);
    });

    test('rejects an empty answer', () {
      expect(isTypedAnswerCorrect('', 'rice'), isFalse);
      expect(isTypedAnswerCorrect('   ', 'rice'), isFalse);
    });
  });
}
