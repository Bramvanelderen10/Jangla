import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jangla/models/content_models.dart';
import 'package:jangla/models/language.dart';
import 'package:jangla/screens/learnings/learn_screen.dart';
import 'package:jangla/services/quiz_stats_service.dart';
import 'package:jangla/services/tts_service.dart';

void main() {
  const ja = LanguageOption(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    file: 'content.ja.json',
    ttsLocales: ['ja-JP'],
  );

  /// Long enough that it must wrap onto several lines on any phone screen.
  const longEntry = Entry(
    english:
        'I would like to ask whether it is possible to change the reservation '
        'for tomorrow evening, if that is not too much trouble.',
    target:
        '明日の夕方の予約を変更することが可能かどうかお伺いしたいのですが、'
        'ご迷惑でなければよろしいでしょうか。',
    roman:
        'asu no yūgata no yoyaku o henkō suru koto ga kanō ka dō ka oukagai '
        'shitai no desu ga, gomeiwaku de nakereba yoroshii deshō ka.',
  );

  Widget wrap(Entry entry) => MaterialApp(
    home: LearnScreen(
      lesson: Lesson(
        id: 'l',
        title: 'Long sentences',
        entriesPerSession: 0,
        entries: [entry],
      ),
      tts: TtsService(ja),
      stats: QuizStatsService()..setLanguageScope('ja'),
    ),
  );

  testWidgets('introduction card fits a long sentence without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(longEntry));
    await tester.pump();

    expect(find.text('New word'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('introduction card fits a long sentence with a note', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Entry(
          english:
              'Could you tell me where the nearest station with a coin locker '
              'is, please?',
          target: '一番近いコインロッカーのある駅はどこですか、教えていただけますか。',
          roman:
              'ichiban chikai koinrokkā no aru eki wa doko desu ka, '
              'oshiete itadakemasu ka.',
          note:
              'Very polite. Drop the ending for a more casual version with '
              'friends.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New word'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short entries still render fully', (tester) async {
    await tester.pumpWidget(
      wrap(const Entry(english: 'rice', target: 'ভাত', roman: 'bhaat')),
    );
    await tester.pump();

    expect(find.text('New word'), findsOneWidget);
    expect(find.text('rice'), findsOneWidget);
    expect(find.text('ভাত'), findsOneWidget);
    expect(find.text('bhaat'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long sentence fits on a small phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(longEntry));
    await tester.pump();

    expect(find.text('New word'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
