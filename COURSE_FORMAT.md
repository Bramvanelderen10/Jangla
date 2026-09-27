# Jangla course file format

A **course** is a single self-describing JSON file. Jangla uses the *exact same*
format for the courses that ship inside the app and for files a user imports, so
any file that follows this document can be added as a new language.

- One file = one course (e.g. "Japanese", "Business Japanese", "Mexican Spanish").
- The file holds both the course metadata (`name`, `language`) and the lessons.
- No code or config changes are needed: the app discovers `*.json` course files.

This document is intentionally precise so it can be handed to an AI to generate a
valid course. There is a ready-made [prompt template](#prompt-template-for-an-ai)
at the end.

---

## 1. Minimal valid example

```json
{
  "name": "Italian",
  "language": { "code": "it" },
  "categories": [
    {
      "id": "survival",
      "title": "Survival",
      "lessons": [
        {
          "id": "greetings_goodbyes",
          "title": "Greetings & Goodbyes",
          "entries": [
            { "en": "Hello.", "bn": "Ciao.", "roman": "chow." },
            { "en": "Thank you.", "bn": "Grazie.", "roman": "graht-see-eh." }
          ]
        }
      ]
    }
  ]
}
```

Only `name`, `language.code` and a non-empty `categories` list are strictly
required; everything else has a sensible default.

---

## 2. Full example (every feature)

```json
{
  "//": "Comments are allowed as '//' keys; the app ignores unknown keys.",
  "name": "Business Japanese",
  "language": {
    "code": "ja",
    "nativeName": "日本語",
    "ttsLocales": ["ja-JP", "ja"]
  },
  "defaults": { "entriesPerSession": 12 },
  "categories": [
    {
      "id": "meetings",
      "title": "Meetings",
      "lessons": [
        {
          "id": "greetings",
          "title": "Greetings",
          "//": "This lesson overrides the course-wide session size.",
          "entriesPerSession": 8,
          "entries": [
            {
              "en": "Nice to meet you.",
              "bn": "はじめまして。",
              "roman": "hajimemashite.",
              "note": "Used when meeting someone for the first time."
            },
            {
              "en": "Please treat me well.",
              "bn": "よろしくお願いします。",
              "roman": "yoroshiku onegai shimasu.",
              "tts": "よろしくおねがいします。",
              "note": "Set phrase. 'yoroshiku' on its own is casual."
            },
            {
              "en": "Excuse me. (leaving)",
              "bn": "失礼します。",
              "roman": "shitsurei shimasu.",
              "tts": "しつれいします。",
              "note": "Said when leaving a meeting, office or someone's home."
            }
          ]
        }
      ]
    }
  ]
}
```

Things to notice:

- **`bn` always holds the target-language text**, whatever the language. The key
  name is a legacy quirk; `target` is accepted as a synonym for it.
- **`roman` is the pronunciation and is optional.** For languages written in the
  Latin alphabet (Italian, Spanish, Dutch, …) omit it — the app then shows `bn`
  on its own. For non-Latin scripts, always provide it.
- **`tts`** gives the text to speak when the written script is ambiguous for
  text-to-speech (typically Japanese kanji → kana). It falls back to `bn`.
- **`note`** is a short usage/register hint shown while learning.
- A **`/`** inside `bn` (and `roman`) separates accepted synonyms, e.g.
  `"bn": "こんにちは。 / やあ。"`. Typed answers match any alternative and ignore
  accents, punctuation and bracketed asides.

---

## 3. Field reference

### Root object

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `name` | string | **yes** | — | Course display name. Also its identity (the app derives an id from it), so it must be **unique** among installed courses. |
| `language` | object | **yes** | — | See below. |
| `defaults` | object | no | `{}` | See below. |
| `categories` | array | **yes** | — | Must be non-empty. |
| `"//"` (or any unknown key) | any | no | — | Ignored. Used for comments/documentation. |

### `language` object

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `code` | string | **yes** | — | Language code, e.g. `"ja"`, `"es"`, `"nl"`. Fallback identity and default TTS locale. |
| `nativeName` | string | no | = `name` | The language's own name, e.g. `"日本語"`. Shown as the subtitle. |
| `ttsLocales` | string[] | no | `[code]` | Preferred text-to-speech locales, **best first**, e.g. `["ja-JP","ja"]`. The first one the device has is used. |
| `default` | boolean | no | `false` | Bundled courses only: marks the course shown on first launch. Ignored for user imports. |

### `defaults` object

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `entriesPerSession` | integer | no | `20` | How many random entries one practice session shows. `0` uses the whole lesson. |

> `defaults.shuffle` appears in some legacy files but is **not read** by the app.

### `category` object

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | **yes** | Stable, unique within the course, no spaces (e.g. `"survival"`). |
| `title` | string | **yes** | Shown in the list (e.g. `"Survival"`). |
| `lessons` | array | **yes** | Must be non-empty. |

### `lesson` object

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `id` | string | **yes** | — | Unique within the course. Used as the saved-progress key. |
| `title` | string | **yes** | — | Shown in the list. |
| `entriesPerSession` | integer | no | course default | Overrides `defaults.entriesPerSession`. `0` = whole lesson. |
| `entries` | array | **yes** | — | Must be non-empty. |

### `entry` object

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `en` | string | **yes** | — | English prompt. Must be non-empty. |
| `bn` | string | **yes** | — | Target-language text. Must be non-empty. `target` is accepted as an alias. |
| `roman` | string | no | `""` | Pronunciation. **Omit for Latin-script languages.** |
| `tts` | string | no | = `bn` | Speaks this instead of `bn` (e.g. kana for kanji). |
| `note` | string | no | — | Short usage/register hint shown under the word. |

---

## 4. Rules & validation

A file is rejected on import if any of these are true:

- it is empty or larger than **2 MB**;
- it is not valid JSON, or the top level is not a JSON object;
- `name` is missing or empty;
- `language` is missing/not an object, or `language.code` is empty;
- `categories` is missing, not an array, or empty;
- a category has no (non-empty) `lessons`;
- a lesson has no (non-empty) `entries`;
- an entry has an empty `en` or an empty `bn`/`target`;
- another installed course already has the same `name` (same derived id).

The app also needs the following when the content is loaded, so **always include
them** even though the importer does not separately check them:

- `category.id`, `category.title`, `lesson.id` and `lesson.title` must be present
  strings;
- `category.id` and `lesson.id` values should be **unique** within the file;
- types are strict — `en`/`bn`/`roman` must be JSON strings (quote anything that
  looks like a number), and `entriesPerSession` must be a whole number.

---

## 5. Authoring guidelines

- **Sessions:** keep `entriesPerSession` modest for grammar-heavy lessons (5–10)
  and larger for plain word lists (15–20); `0` shows the whole lesson at once.
- **Order matters for Learn:** words are introduced in the order they appear, so
  put the simplest/most useful entries first, and place word lists just before the
  phrase lessons that use them.
- **`roman`:** required for non-Latin scripts (Bengali, Japanese, …); omit it for
  Latin-script languages. Keep it phonetic and readable for English speakers, not
  a strict transliteration standard.
- **`note`:** one short sentence about register/etiquette beats a long explanation
  (e.g. "Formal; use with staff. Casual with friends: …").
- **Synonyms:** use `" / "` in `bn` for anything a learner might reasonably type.
- **`tts`:** mainly for Japanese (kanji → kana). Only add it when the engine would
  otherwise mispronounce the text.
- **`ttsLocales`:** put a regional locale first (e.g. `ja-JP`, `es-US`, `bn-IN`)
  and the bare code last. Audio needs a matching voice installed on the device.

---

## 6. Prompt template for an AI

Copy the block below, fill in the topic, and give it to an AI. It will produce a
file you can import directly.

```text
Generate ONE valid JSON course file for the "Jangla" language-learning app.
Output ONLY the JSON object — no markdown, no code fences, no commentary.

Exact schema:
{
  "name": "<unique course name, e.g. 'Business Japanese'>",
  "language": {
    "code": "<ISO code, e.g. ja>",
    "nativeName": "<name in its own script>",
    "ttsLocales": ["<region-locale>", "<language-code>"]
  },
  "defaults": { "entriesPerSession": <integer 5-20> },
  "categories": [
    {
      "id": "<slug, unique, no spaces>",
      "title": "<category title>",
      "lessons": [
        {
          "id": "<slug, unique in the file>",
          "title": "<lesson title>",
          "entriesPerSession": <optional integer>,
          "entries": [
            {
              "en": "<English prompt>",
              "bn": "<text in the target language>",
              "roman": "<pronunciation; OMIT for Latin-script languages>",
              "tts": "<optional spoken text, e.g. kana>",
              "note": "<optional one-line usage hint>"
            }
          ]
        }
      ]
    }
  ]
}

Rules:
- "bn" always holds the TARGET-language text (even for non-Bengali courses).
- Use " / " inside "bn" to list accepted synonyms.
- Every entry needs a non-empty "en" and "bn"; "roman" is optional but required
  for non-Latin scripts.
- Category and lesson "id" values must be unique and contain no spaces.
- Make "name" unique (it becomes the course's identity).
- Valid JSON only: double quotes, no trailing commas, no comments.

Course to generate:
- Language: <language>
- Name: <course name>
- Level: <beginner / travel / business / ...>
- Categories and lessons: <list them, with roughly how many entries each>
```

---

## 7. Using the file

- **Import in the app (no rebuild):** open the language menu → the upload icon →
  **Import JSON** → pick the file → review → **Import**.
- **Ship it with the app:** drop `<anything>.json` into `assets/content/` and
  rebuild. The folder is bundled wholesale and discovered at runtime.
