# Copilot instructions — Bangla Learn

A Flutter (Dart) Android app for learning basic Bengali (Bangla) words and
sentences. Content is data-driven from a single JSON config; the app never
hardcodes vocabulary.

## Architecture

- Entry point [`lib/main.dart`](../lib/main.dart): `BanglaLearnApp` → `HomeLoader`
  loads content once via a `FutureBuilder`, then shows `CategoriesScreen`.
- Content flow: **AppContent → Category → Lesson → Entry** (defined in
  [`lib/models/content_models.dart`](../lib/models/content_models.dart)).
- [`lib/data/content_repository.dart`](../lib/data/content_repository.dart)
  reads and decodes `assets/content/content.json` via `rootBundle`.
- [`lib/services/tts_service.dart`](../lib/services/tts_service.dart) wraps
  `flutter_tts` for Bengali speech (`bn-BD`) and fails silently if unavailable.
- [`lib/services/quiz_stats_service.dart`](../lib/services/quiz_stats_service.dart)
  persists per-entry right/wrong tallies via `shared_preferences` (keyed by
  `lessonId::english`) and provides `reviewEntries()` — a session weighted toward
  the words failed most (score `wrong*2 - correct`).
- [`lib/services/custom_list_service.dart`](../lib/services/custom_list_service.dart)
  persists user-made practice lists (`CustomList`, defined in
  [`lib/models/custom_list.dart`](../lib/models/custom_list.dart)) via
  `shared_preferences` (key `custom_lists_v1`). Lists are built from existing
  content `Entry`s; `CustomList.toLesson()` adapts a list to a `Lesson` (id =
  list id, `entriesPerSession` 0 = whole pool) so the flashcard/quiz screens
  work unchanged. Entries are de-duplicated by `Entry.key` (`en|bn|roman`).
- Screens in [`lib/screens/`](../lib/screens): `categories_screen` →
  `lessons_screen` → `flashcard_screen` (tap-to-flip PageView) and
  `quiz_screen`. Each quiz question is randomly one of two kinds
  (`QuestionKind.multipleChoice` with 5 options, or `typing`) in one of two
  directions (`QuizDirection.enToBn` / `bnToEn`); typed answers are normalized
  (lowercase, punctuation/whitespace stripped) before comparison. `QuizMode`
  (`random` or `reviewMistakes`) controls which entries are drawn.
- `categories_screen` also hosts `PhraseOfTheDayCard` (3 entries seeded by the
  calendar day via `AppContent.allEntries`) and an AppBar action to **My Lists**
  (`custom_lists_screen` → `custom_list_edit_screen`, which adds entries through
  the searchable `entry_picker_screen`).
- Bengali audio (🔊) buttons appear on the flashcard front, the `bnToEn` quiz
  prompt, the phrase-of-the-day card, and custom-list rows — all call
  `TtsService.speak(entry.bengali)`.

## Data model & config

- Content lives in [`assets/content/content.json`](../assets/content/content.json)
  ("easy config"). It is the source of truth — add words/lessons/categories here,
  not in Dart.
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
  `com.bramve.banglalearn`, label "Learn Bengali"). Other platform folders are
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
