# Copilot instructions — Jangla

A Flutter (Dart) Android app for learning basic vocabulary and sentences in a
chosen language (Bengali, Japanese and Spanish ship in the box). Content is
data-driven from one self-describing JSON file per course; the app never
hardcodes vocabulary.

## Architecture

- Entry point [`lib/main.dart`](../lib/main.dart): `JanglaApp` → `HomeLoader`
  initialises stats/custom-lists/imports, discovers the available courses,
  resolves the selected/default one, then loads that course's content via a
  `FutureBuilder` and shows `CategoriesScreen`. Picking a different course
  re-runs the future and rebuilds `TtsService`.
- Content flow: **AppContent → Category → Lesson → Entry** (defined in
  [`lib/models/content_models.dart`](../lib/models/content_models.dart)).
- A **Course** ([`lib/models/course.dart`](../lib/models/course.dart)) is the
  unit a learner picks: the root-level `name`, a `language` block
  ([`LanguageOption`](../lib/models/language.dart): `code`, `nativeName`,
  `ttsLocales`), the raw JSON text, and a `LanguageSource` (`bundled` or
  `imported`). Its `id` is derived from the name (`slugifyCourseName`,
  [`lib/services/course_id.dart`](../lib/services/course_id.dart)) — the JSON
  never stores an id.
- [`lib/data/course_repository.dart`](../lib/data/course_repository.dart)
  discovers bundled courses by listing `assets/content/*.json` through
  `AssetManifest.loadFromAssetBundle(rootBundle)`, merges them with the user's
  imports, decodes/caches a course's `AppContent`, and persists the selected
  course id in `shared_preferences` (key `selected_language_v1`). There is **no
  `config.json`**.
- [`lib/services/language_import.dart`](../lib/services/language_import.dart) is
  the single parse/validate pipeline shared by bundled files and user uploads.
  It checks the `name` and `language` block and walks categories → lessons →
  entries (every entry needs non-empty `en`, `bn`, `roman`), derives
  `nativeName`/`ttsLocales` fallbacks, enforces a size cap and rejects duplicate
  course ids.
- [`lib/services/imported_course_service.dart`](../lib/services/imported_course_service.dart)
  persists user-imported courses via `shared_preferences` (key
  `imported_courses_v1`); bundled courses are never stored.
- [`lib/services/tts_service.dart`](../lib/services/tts_service.dart) wraps
  `flutter_tts`. It is constructed for the selected `LanguageOption` plus a
  display name and speaks using the best available locale from `ttsLocales`
  (e.g. `bn-IN`, `ja-JP`); it exposes `languageName` for UI labels and fails
  silently if no matching voice is installed.
- [`lib/services/quiz_stats_service.dart`](../lib/services/quiz_stats_service.dart)
  persists per-entry right/wrong tallies **and the spaced-repetition schedule**
  via `shared_preferences` (key `quiz_stats_v2`, keyed
  `<courseId>::<lessonId>::<english>`). `setCourseScope(id)` selects the active
  namespace; on init it migrates the legacy bundled scopes
  (`bn`/`ja`/`es` → `bengali`/`japanese`/`spanish`). A correct answer moves an
  entry up a Leitner box (intervals 1/3/7/16/35 days); a wrong answer drops it
  to box 0 and leaves it due. `dueEntries()` / `dueCount()` return what is due
  across a set of lessons, and `mastery(lesson)` returns a `LessonMastery`
  (learned / learning / unseen / due) that drives the per-lesson mastery bar in
  `lessons_screen` (`masteredBox` = 3). `newEntries(lesson)` picks a session's
  not-yet-learned entries and is what `learn_screen` feeds to `LearnSession`.
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
  (`enToTarget`, `targetToEn`, plus the audio prompt `audioToEn`);
  `LearnSession` only uses the audio direction when constructed with
  `allowAudio: true` (set from `TtsService.voiceAvailable`). Quiz questions are
  randomly one of two kinds (`QuestionKind.multipleChoice` with
  `quizOptionCount` (6) options, or `typing`) in one of those directions —
  audio prompts are always multiple choice. Typed answers are compared with
  [`lib/services/answer_matching.dart`](../lib/services/answer_matching.dart),
  which folds accents and special characters (`ō` -> `o`, `ḍ` -> `d`), drops
  bracketed asides (`rice (cooked)` -> `rice`) and accepts `/`-separated
  synonyms on either side.
- `categories_screen` hosts `DailyReviewCard` (opens
  `review/daily_review_screen`, which reviews everything due across
  `AppContent.allLessons` by reusing `LearnScreen` with a synthetic lesson plus
  `lessonIdFor`, so results are recorded against each entry's original lesson)
  and `PhraseOfTheDayCard` (3 entries seeded by the calendar day via
  `AppContent.allEntries`), plus AppBar actions for **Languages**
  (`languages_screen` → `import_language_screen`, which uses `file_picker` to
  read a course file) and **My Lists** (`custom_lists_screen` →
  `custom_list_edit_screen`, which adds entries through the searchable
  `entry_picker_screen`).
- Target-language audio (🔊) buttons appear on the Learn card, the `targetToEn`
  quiz prompt, the phrase-of-the-day card, and custom-list rows — all call
  `TtsService.speak(entry.target)`.

## Data model & course files

- Content lives in one file per course in [`assets/content/`](../assets/content)
  (`content.bn.json`, `content.ja.json`, `content.es.json`) — the "easy config".
  Each file is self-describing and is the source of truth; add
  words/lessons/categories there, not in Dart.
- A course file is:
  `{ "name": <course name>, "language": { "code", "nativeName"?, "ttsLocales"?, "default"? }, "defaults": {...}, "categories": [...] }`.
  The `name` is the course identity (slugified), so it must be unique; a second
  course on the same language uses a different name (e.g. `"Business Japanese"`).
- `language.code` drives text-to-speech and may be shared by several courses;
  `language.default: true` marks the course shown on first launch (only one).
  `nativeName`/`ttsLocales` fall back to the course name and the language code.
- The bundled folder is discovered via the asset manifest, so adding a `*.json`
  file there is enough — no `pubspec.yaml` or `config.json` change.
- Users can import a course at runtime: `languages_screen` →
  `import_language_screen` picks a `.json` file (`file_picker`), validates it
  (`LanguageImport`) and stores it via `ImportedCourseService`. Imported courses
  can also be renamed or removed from `languages_screen`; renaming moves the
  stats scope and the saved selection (`QuizStatsService.renameCourseScope`,
  `CourseRepository.renameCourse`).
- The per-entry `bn` JSON key holds the target-language script regardless of
  language (kept as `bn` for backward compatibility); `Entry.target` mirrors it.
- Entry shape: `{ "en": <english>, "bn": <target script>, "roman": <pronunciation> }`.
  Always provide all three. Two optional keys: `tts` supplies a kana reading when
  the script is ambiguous for text-to-speech, and `note` is a short usage hint
  (register/etiquette) shown under the word on the Learn card. `Entry` also has
  `toJson()` and a `key` getter (`en|bn|roman`) used to persist and de-duplicate
  custom-list entries.
- `defaults.entriesPerSession` sets how many random entries a lesson shows;
  `0` means use the whole pool. A lesson may override with its own
  `entriesPerSession`.
- `Lesson.sessionEntries([Random])` returns a shuffled subset each call — this is
  how lessons are randomized. Keep this the single source of randomization.
- Keep the `"//"` comment keys in the JSON; they document the format.

## Tooling

- **Always prefer the built-in editor tool over Python (or shell) for editing
  files.** Use its exact-match replace, create and insert operations for every
  file change, including large rewrites (split them into chunks if needed) and
  CRLF files — it matches and preserves the file's existing line endings.
- Only reach for the shell when the task is genuinely shell-shaped: running
  `flutter analyze` / `flutter test`, `git`, listing or searching files, or a
  large mechanical rename across many files (verify the result afterwards).
- Do not leave scratch scripts in the repo; keep throwaway files in `/tmp` and
  delete them when done.

## Conventions

- Material 3, seed color `0xFF00695C`. Bengali script rendered large/bold, the
  romanized form in italic teal.
- Screens receive `content`/`course`/`category`/`lesson` and the shared
  `TtsService`/`QuizStatsService` via constructor injection; there is no global
  state or DI container. Services are created in `HomeLoader` and passed down.
- `Entry` uses default identity equality — quiz option/answer matching relies on
  the same object instances from `Lesson.entries`. Do not add value equality
  without updating quiz logic. Custom lists satisfy this because a single
  `CustomList.toLesson()` supplies all option instances from the same list.
- New models must have a `fromJson` factory mirroring the existing ones.
- Several files use CRLF line endings; preserve them when editing.

## Workflows

- The Android platform folder (`android/`) IS committed (app id
  `com.bramve.jangla`, label "Jangla"). Other platform folders are generated on
  demand: `flutter create --platforms=<platform> .`
- Run: `flutter pub get` then `flutter run`. Test: `flutter test`.
- CI: [`.github/workflows/build-and-publish.yml`](../.github/workflows/build-and-publish.yml)
  builds a release APK on push to `main` (uploaded as an artifact) and, on a
  `v*` tag, publishes a GitHub Release with the APK attached. Release signing is
  used only if the `ANDROID_KEYSTORE_*` secrets are set; otherwise the APK is
  debug-signed (still installable by sideloading).
- Unit tests live in [`test/`](../test):
  [`test/content_files_test.dart`](../test/content_files_test.dart) parses every
  bundled course file through `LanguageImport`;
  [`test/language_import_test.dart`](../test/language_import_test.dart) covers
  the validator; [`test/course_repository_test.dart`](../test/course_repository_test.dart)
  exercises discovery via the real asset manifest;
  [`test/quiz_stats_rename_test.dart`](../test/quiz_stats_rename_test.dart)
  covers progress moving with a renamed course.

## Content notes

- Romanization is phonetic (not a strict transliteration standard); keep it
  readable for English speakers.
- Vocabulary uses the West Bengal (Kolkata) variant where dialects differ
  (e.g. জল/`jol` for water not পানি/`pani`; নুন/`nun` for salt; নমস্কার/`nomoshkar`
  as the greeting).
- The Japanese and Spanish courses are not required to stay structurally
  identical; they may diverge.
