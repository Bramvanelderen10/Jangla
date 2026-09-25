# Copilot instructions — Jangla

A Flutter (Dart) Android app for learning basic vocabulary and sentences in a
chosen language (Bengali and Japanese ship in the box). Content is data-driven
from one JSON file per language plus a small `config.json` mapping; the app
never hardcodes vocabulary.

## Architecture

- Entry point [`lib/main.dart`](../lib/main.dart): `JanglaApp` → `HomeLoader`
  loads `config.json`, resolves the selected/default language, then loads that
  language's content via a `FutureBuilder` and shows `CategoriesScreen`. Picking
  a different language re-runs the future and rebuilds `TtsService`.
- Content flow: **AppContent → Category → Lesson → Entry** (defined in
  [`lib/models/content_models.dart`](../lib/models/content_models.dart)).
- [`lib/data/content_repository.dart`](../lib/data/content_repository.dart)
  decodes `assets/content/config.json` into `AppConfig`/`LanguageOption`
  (defined in [`lib/models/language.dart`](../lib/models/language.dart)), loads
  a language's `content.<code>.json` via `rootBundle`, and persists the chosen
  language code in `shared_preferences` (key `selected_language_v1`).
- [`lib/services/tts_service.dart`](../lib/services/tts_service.dart) wraps
  `flutter_tts`. It is constructed for the selected `LanguageOption` and speaks
  using the best available locale from its `ttsLocales` (e.g. `bn-IN`, `ja-JP`);
  it exposes `languageName` for UI labels and fails silently if no matching
  voice is installed.
- [`lib/services/quiz_stats_service.dart`](../lib/services/quiz_stats_service.dart)
  persists per-entry right/wrong tallies **and the spaced-repetition schedule**
  via `shared_preferences` (key `quiz_stats_v2`, keyed
  `<language>::<lessonId>::<english>`; v1 data is ignored). A correct answer
  moves an entry up a Leitner box (intervals 1/3/7/16/35 days); a wrong answer
  drops it to box 0 and leaves it due. `dueEntries()` / `dueCount()` return what
  is due across a set of lessons, and `mastery(lesson)` returns a
  `LessonMastery` (learned / learning / unseen / due) that drives the per-lesson
  mastery bar in `lessons_screen` (`masteredBox` = 3).
- [`lib/services/custom_list_service.dart`](../lib/services/custom_list_service.dart)
  persists user-made practice lists (`CustomList`, defined in
  [`lib/models/custom_list.dart`](../lib/models/custom_list.dart)) via
  `shared_preferences` (key `custom_lists_v1`). Lists are built from existing
  content `Entry`s; `CustomList.toLesson()` adapts a list to a `Lesson` (id =
  list id, `entriesPerSession` 0 = whole pool) so the screens work unchanged.
  Entries are de-duplicated by `Entry.key` (`en|bn|roman`).
- Screens in [`lib/screens/`](../lib/screens): `categories_screen` →
  `lessons_screen` → `learn_screen` (the interleaved introduce → quiz → retry
  loop, driven by [`lib/services/learn_session.dart`](../lib/services/learn_session.dart))
  and `quiz_screen`. Question shapes are described by the shared
  [`lib/models/quiz_models.dart`](../lib/models/quiz_models.dart) `QuizDirection`
  (`enToTarget`, `targetToEn`, plus the audio prompts `audioToEn` /
  `audioToTarget`); `LearnSession` only uses the audio directions when
  constructed with `allowAudio: true` (set from `TtsService.voiceAvailable`).
  Quiz questions are randomly one of two kinds (`QuestionKind.multipleChoice`
  with 5 options, or `typing`) in one of those directions — audio prompts are
  always multiple choice. Typed answers are normalized (lowercase,
  punctuation/whitespace stripped) before comparison.
- `categories_screen` hosts `DailyReviewCard` (opens
  `review/daily_review_screen`, which reviews everything due across
  `AppContent.allLessons` by reusing `LearnScreen` with a synthetic lesson plus
  `lessonIdFor`, so results are recorded against each entry's original lesson)
  and `PhraseOfTheDayCard` (3 entries seeded by the calendar day via
  `AppContent.allEntries`), plus an AppBar action to **My Lists**
  (`custom_lists_screen` → `custom_list_edit_screen`, which adds entries through
  the searchable `entry_picker_screen`).
- Target-language audio (🔊) buttons appear on the Learn card, the `targetToEn`
  quiz prompt, the phrase-of-the-day card, and custom-list rows — all call
  `TtsService.speak(entry.target)`.

## Data model & config

- Content lives in one file per language,
  `assets/content/content.<code>.json` (e.g. `content.bn.json`,
  `content.ja.json`) — the "easy config". It is the source of truth — add
  words/lessons/categories there, not in Dart.
- [`assets/content/config.json`](../assets/content/config.json) maps each
  language `code` to its display `name`, `nativeName`, content `file`, and
  preferred `ttsLocales`, and sets `defaultLanguage`. To add a language, drop a
  `content.<code>.json` file in `assets/content/` and add an entry here — the
  folder is bundled wholesale via pubspec, so no `pubspec.yaml` change is needed.
- The per-entry `bn` JSON key holds the target-language script regardless of
  language (kept as `bn` for backward compatibility); `Entry.bengali` mirrors it.
- Entry shape: `{ "en": <english>, "bn": <Bengali script>, "roman": <pronunciation> }`.
  Always provide all three fields. `Entry` also has `toJson()` and a `key` getter
  (`en|bn|roman`) used to persist and de-duplicate custom-list entries.
- `defaults.entriesPerSession` sets how many random entries a lesson shows;
  `0` means use the whole pool. A lesson may override with its own
  `entriesPerSession`.
- `Lesson.sessionEntries([Random])` returns a shuffled subset each call — this is
  how lessons are randomized. Keep this the single source of randomization.
- Keep the `"//"` comment keys in the JSON; they document the format.

## Conventions

- Material 3, seed color `0xFF00695C`. Bengali script rendered large/bold, the
  romanized form in italic teal.
- Screens receive `content`/`category`/`lesson` and the shared `TtsService`
  and `QuizStatsService` via constructor injection; there is no global state or
  DI container. Services are created in `HomeLoader` and passed down.
- `Entry` uses default identity equality — quiz option/answer matching relies on
  the same object instances from `Lesson.entries`. Do not add value equality
  without updating quiz logic. Custom lists satisfy this because a single
  `CustomList.toLesson()` supplies all option instances from the same list.
- New models must have a `fromJson` factory mirroring the existing ones.

## Workflows

- The Android platform folder (`android/`) IS committed (app id
  `com.bramve.jangla`, label "Jangla"). Other platform folders are
  generated on demand: `flutter create --platforms=<platform> .`
- Run: `flutter pub get` then `flutter run`. Test: `flutter test`.
- CI: [`.github/workflows/build-and-publish.yml`](../.github/workflows/build-and-publish.yml)
  builds a release APK on push to `main` (uploaded as an artifact) and, on a
  `v*` tag, publishes a GitHub Release with the APK attached. Release signing is
  used only if the `ANDROID_KEYSTORE_*` secrets are set; otherwise the APK is
  debug-signed (still installable by sideloading).
- Unit tests live in [`test/`](../test) and focus on model/config parsing and
  randomization ([`test/content_models_test.dart`](../test/content_models_test.dart)).

## Content notes

- Romanization is phonetic (not a strict transliteration standard); keep it
  readable for English speakers.
- Vocabulary uses the West Bengal (Kolkata) variant where dialects differ
  (e.g. জল/`jol` for water not পানি/`pani`; নুন/`nun` for salt; নমস্কার/`nomoshkar`
  as the greeting).
