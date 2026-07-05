# DiploMate Content Authoring Format

Read this before writing or editing any chapter. The pipeline is
build -> validate -> publish (see CLI usage below). Identity rules here are
load-bearing: recall history hangs off the ULIDs this pipeline mints.

An authoring chapter is a directory:

```
<chapter-dir>/
  chapter.json      the whole chapter: metadata, topics, qnas, image references
  images/           source images (png, jpg, or webp; any size - the build resizes/converts)
  ids.lock          machine-written ULID ledger; created by the first build; COMMITTED; never hand-edited
```

`chapter.json`:

```json
{
  "speciality_slug": "anaesthesia",
  "chapter": {
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
  "topics": [
    {
      "key": "spinal-anaesthesia",
      "title": "Spinal Anaesthesia",
      "slug": "spinal-anaesthesia",
      "exam_theme": "Regional techniques",
      "sort_order": 1,
      "qnas": [
        {
          "key": "spinal-definition",
          "question": "Define spinal anaesthesia. List its indications and contraindications.",
          "years": "2019, 2022",
          "marks": 10,
          "sort_order": 1,
          "earns_marks": [
            {
              "label": "Definition of subarachnoid block",
              "section_key": "definition"
            },
            {
              "label": "Absolute contraindications",
              "section_key": "indications"
            }
          ],
          "sections": [
            { "key": "definition", "heading": "Definition", "body_md": "..." },
            {
              "key": "indications",
              "heading": "Indications and contraindications",
              "body_md": "..."
            },
            { "key": "summary", "heading": "Summary", "body_md": "..." }
          ],
          "images": [
            {
              "file": "spinal-levels.png",
              "caption": "Vertebral levels relevant to spinal anaesthesia (sample diagram)",
              "content_description": "Sample placeholder panel standing in for a labelled vertebral column diagram.",
              "sort_order": 1
            }
          ]
        }
      ]
    }
  ]
}
```

Field rules:

- `speciality_slug` - must match a slug seeded by `sql/0002_seed_specialities.sql` (beta content: `anaesthesia`). The publisher resolves it to the seeded speciality ULID; it never creates specialities.
- `key` (topics and qnas) - PERMANENT identity handle, unique within the chapter, never renamed once published. `ids.lock` maps keys to minted ULIDs; SR state hangs off those ULIDs. Renaming a `key` mints a new identity and orphans recall history - do not do it.
- `slug`, `title` - mutable path metadata (A4). Rename freely; identity is the ULID.
- Slug format: lowercase `a-z0-9` groups separated by single hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- `sections` - non-empty array; `key` unique within the qna; recommended keys follow the D16 answer anatomy: `definition`, `indications`, `technique`, `complications`, `summary` (free-form allowed; the validator checks shape, not vocabulary). `body_md` is Markdown.
- `earns_marks` - the "What earns marks" outline; every `section_key` must match a `sections[].key` in the same qna. May be `[]`.
- `years` - optional freeform PYQ string, e.g. `"2019, 2022"`. `marks` - optional integer. `exam_theme` - optional string.
- `images[].file` - path relative to `<chapter-dir>/images/`. The build converts to WebP, resizes to fit 1600x1600, and re-encodes down the quality ladder (80, 60, 40) until <= 204800 bytes; if still over, the build fails. `caption` and `content_description` are mandatory (TalkBack, D20).
- De-brand rule (outside voice #2): until the content term sheet is signed (PG1), author ONLY de-branded owned sample content - no publisher text, no scanned figures. Publishing to any database is additionally gated: `node src/publish.js <dir> --allow-publish` with env `LICENSE_SIGNED=true`.

CLI usage:

```
node src/build.js <chapterDir> <outDir>        # authoring -> canonical (mints/reuses ULIDs via ids.lock)
node src/validate.js <canonicalDir>            # CI gate; exit 0 = OK, exit 1 = ERROR lines on stderr
LICENSE_SIGNED=true node src/publish.js <canonicalDir> --allow-publish   # DATABASE_URL env required
```

Canonical output (`<outDir>/chapter.json` + `<outDir>/images/<image-ulid>.webp`) mirrors the DB row shape:

```json
{
  "schema_version": 1,
  "speciality_slug": "anaesthesia",
  "chapter": {"id": "<ULID>", "title": "...", "slug": "...", "sort_order": 1, "exam_weight": 10},
  "topics": [{"id": "<ULID>", "chapter_id": "<ULID>", "title": "...", "slug": "...", "exam_theme": "...", "sort_order": 1}],
  "qnas": [{"id": "<ULID>", "topic_id": "<ULID>", "question": "...", "years": "2019, 2022", "marks": 10, "earns_marks": [...], "sections": [...], "sort_order": 1}],
  "images": [{"id": "<ULID>", "qna_id": "<ULID>", "caption": "...", "content_description": "...", "file": "images/<ULID>.webp", "byte_size": 12345, "sha256": "<hex>", "sort_order": 1}]
}
```
