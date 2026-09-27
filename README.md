# Jangla

A simple Flutter app to learn basic vocabulary and phrases in a target language.
It started with Bengali (Bangla) — enough to chat with your girlfriend's family —
and now also ships Japanese (a two-week trip) and Spanish courses.

Each word/sentence shows the **target-language script** (Bengali, Japanese, …)
and a **romanized pronunciation**, and can be **spoken aloud** (text-to-speech).
The romanization is optional: languages written in the Latin alphabet (Spanish)
leave it out, and the app simply shows the target text on its own. Every lesson
picks a **random set** of entries each time you open it.

## Features

- Categories → Lessons → practice modes
- **Learn**: interleaved introduce → quiz → retry with in-session spaced review — introduces only the words you haven't learned yet, in the order they appear in the lesson (mixed with the rest of the lesson for quiz options), and ends once the lesson is fully learned. Starting it again replays the whole lesson without touching your saved progress
- **Quiz**: shuffled multiple-choice and typed answers, in both directions — typed answers forgive accents (`o` for `ō`) and bracketed asides (`rice` for `rice (cooked)`)
- **Listening cards**: some quiz cards play the audio only ("What did you hear?") and ask for the meaning — switched on automatically when a target-language voice is installed
- **Daily Review**: a spaced-repetition queue of everything due today, across every lesson you've already started
- **Progress**: every lesson shows a mastery bar (learned / total) and how many of its entries are due today
- **Text-to-speech** playback of the target language (uses the device's `bn-BD` / `ja-JP` / `es-ES` voice)
- Lessons are **randomized** and show a configurable number of entries per session
- **Import your own course**: pick a `.json` course file (e.g. "Business Japanese") and it becomes a learnable language — no app update needed

## Content

| Category | Lessons (in recommended order) |
| --- | --- |
| Survival Phrases | Greetings & Goodbyes · Emergency & Health · Useful Travel Sentences · Transport: Places & Vehicles · Transport: Tickets & Asking · Transport: Troubleshooting · Money & IC Cards · Hotel & Accommodation · Directions: Words · Directions: Phrases · Shopping & Money |
| Food & Dining | Food: Basics · Food & Drink: More · Dining: Manners · Ordering Food · Food Preferences · Dietary Needs · Convenience Store & Basics |
| Essential Words | Numbers 0-10 · Numbers 11-100 · Numbers: Big & Counters · Time Words · Calendar Words · Months · Pronouns & Question Words · Common Verbs (polite) · Adjectives: Basics · Adjectives: More · Places & Locations · Days & Time Words · Home & Everyday Things · Common Actions & Feelings · Family & Relatives |
| Conversation & Patterns | Introduce Yourself & Small Talk · Sentence Building · Questions & Negation · Useful Verb Patterns · Pronouns & Politeness · Plans & Future |

Lessons are **scaffolded**: each tier stays at one level of complexity so the
learner moves words → simple frames → longer sentences, e.g. *Transport: Places
& Vehicles* (nouns) → *Transport: Tickets & Asking* (frames) → *Transport:
Troubleshooting* (full sentences).

## Course files

Every language is one self-describing JSON file in
[`assets/content/`](assets/content) — [`content.ja.json`](assets/content/content.ja.json)
(Japanese), [`content.es.json`](assets/content/content.es.json) (Spanish) and
[`content.bn.json`](assets/content/content.bn.json) (Bengali). Each file carries
its own `name` and `language` metadata, so there is no separate `config.json`;
the bundled files are discovered automatically, so dropping a new file into the
folder adds a language with no code changes.

See [`COURSE_FORMAT.md`](COURSE_FORMAT.md) for the complete field-by-field
reference, the validation rules, and a ready-made prompt for generating a course
with an AI.

```json
{
  "name": "Japanese",
  "language": {
    "code": "ja",
    "nativeName": "日本語",
    "ttsLocales": ["ja-JP", "ja"],
    "default": true
  },
  "defaults": { "entriesPerSession": 10 },
  "categories": [ /* ... */ ]
}
```

- `name` is the course's display name **and its identity** — give each course a
  unique name (the app derives its internal id from it).
- `language.code` is the language for text-to-speech; several courses may share
  it (e.g. Japanese and Business Japanese).
- `language.default: true` marks the course shown on first launch (only one).
- `language.nativeName` and `language.ttsLocales` are optional; they fall back
  to the course name and the language code.

- `defaults.entriesPerSession` — how many random entries each lesson shows
  (set `0` to use every entry in the lesson).
- Each lesson can override this with its own `entriesPerSession`. Kanji- and
  grammar-heavy lessons are deliberately capped at **5–8** items per session to
  keep cognitive load low; plain word lists use higher caps.
- Add a new entry:

  ```json
  { "en": "friend", "bn": "বন্ধু", "roman": "bondhu" }
  ```

  `"roman"` is the pronunciation; leave it out for languages written in the
  Latin alphabet (e.g. Spanish), where the target text is readable as-is. Two
  more optional keys: `"tts"` gives a kana reading when the script would be
  ambiguous for speech, and `"note"` is a short usage hint shown under the word
  while learning:

  ```json
  {
    "en": "Thank you. (polite)",
    "bn": "ありがとうございます。",
    "roman": "arigatō gozaimasu.",
    "tts": "ありがとうございます。",
    "note": "The safe default with staff, hosts and strangers."
  }
  ```

- Add a new lesson or category by copying the existing structure.

No code changes are needed — just edit the JSON and re-run the app.

## Import your own language

You can also add a language at runtime, without building a new APK:

1. Create a course JSON file like the one above — a good starting point is to
   copy [`content.ja.json`](assets/content/content.ja.json) and give it a unique
   `name`, e.g. `"Business Japanese"`.
2. In the app, open the language menu and tap the **upload** icon in the top
   bar, then **Import JSON**.
3. Pick the file, check the preview, adjust the name/code if needed, and tap
   **Import**.

The new course appears in the language menu and keeps its own progress.
Imported courses can be **renamed** (their progress follows the new name) or
**removed** from the same **Languages** screen; the bundled courses are built
in and read-only.

## Requirements

- Flutter SDK (stable), Dart `^3.7.0`
- An Android device/emulator with a TTS voice for the target language installed
  (e.g. Bengali `bn-BD`, Japanese `ja-JP`; Android: *Settings → System →
  Languages → Text-to-speech output*)

## Run locally

The platform folders (`android/`) are generated by Flutter. From the project root:

```sh
flutter create --platforms=android .
flutter pub get
flutter run
```

`flutter create` only adds the missing Android scaffolding; it does not overwrite
`lib/`, `assets/`, or `pubspec.yaml`.

## App icon

The launcher icon is generated, not hand-edited:

- [`tool/generate_icon.py`](tool/generate_icon.py) draws the source PNGs into
  `assets/icon/` (`app_icon.png`, `app_icon_foreground.png`,
  `app_icon_monochrome.png`) with Pillow.
- `flutter_launcher_icons` (configured in `pubspec.yaml`) turns those into the
  Android mipmaps + adaptive icon, the iOS `AppIcon` set, and the web icons.

Regenerate after changing the script, or after dropping in real artwork:

```sh
python3 tool/generate_icon.py
dart run flutter_launcher_icons
```

The background colour (`#00695C`) matches `colorSchemeSeed` in `lib/main.dart`.
The iOS/web/desktop platform folders are gitignored, so only the Android icons
are tracked.

## Installing Android updates

Android only updates an installed app when the new APK has the **same
application id** and is signed with the **same key**. If the key differs, the
installer refuses with a signature error and the only way forward is to
uninstall (losing app data) and reinstall.

The application id is fixed (`com.bramve.jangla`), and the build script now
**refuses to produce a release APK without a configured keystore** — so you
never accidentally ship an APK that can't update an existing install. The only
setup needed is creating one keystore and using it everywhere.

### One-time setup

```sh
keytool -genkey -v \
  -keystore ~/jangla-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then copy `android/key.properties.example` to `android/key.properties`
(gitignored — never commit it) and fill it in:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/jangla-upload.jks
```

CI reads the same values from the repository secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD` (base64 the `.jks` for the first one). The workflow fails
loudly if any are missing.

> **Back the keystore up.** If you lose it you can never update an installed
> copy again — only uninstall and reinstall.

### Building and installing an update

1. Bump the build number in `pubspec.yaml` (`version: 1.0.0+2`, `+3`, …). A
   higher `versionCode` is what Android treats as an upgrade. Installing the
   same number also works, but never go backwards.
2. Build: `flutter build apk --release`
3. Install over the existing app:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or copy the APK to the phone and tap it — Android offers to update in place and
your app data is kept.

### Troubleshooting

- *"App not installed" / signature mismatch* — the APK was signed with a
  different key than the installed app. Uninstall once, then always build with
  the keystore above.
- *`flutter run`* uses the debug key, so it cannot replace a release-signed
  install on your phone. Use release APKs for the copy you carry around.

## Test

```sh
flutter test
```
