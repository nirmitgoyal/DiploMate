# DiploMate Content Authoring Format (schema v2)

Read this before writing or editing any chapter. The pipeline is
build -> validate -> publish (see CLI usage below). Identity rules here are
load-bearing: recall history hangs off the ULIDs this pipeline mints.

Schema v2 (2026-07-06, sql/0004): the topics layer is REMOVED. Questions
hang directly off chapters; chapters mirror the source book's own chapter
list (Miller's Anesthesia for Anaesthesiology).

## Directory layout

A SPECIALITY is a directory of chapter directories sharing ONE ledger:

```
<speciality-dir>/
  ids.lock          machine-written ULID ledger for the WHOLE speciality;
                    created by the first build; COMMITTED; never hand-edited.
                    One ledger per speciality means a question moved between
                    chapters keeps its ULID (chapter membership is placement,
                    not identity).
  <chapter-dir>/
    chapter.json    the chapter: metadata + qnas + image references
    images/         source images (png/jpg/webp; any size - the build
                    resizes/converts)
```

`chapter.json`:

```json
{
  "speciality_slug": "anaesthesiology",
  "chapter": {
    "key": "regional-anaesthesia-sample",
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
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
        }
      ],
      "sections": [
        { "key": "definition", "heading": "Definition", "body_md": "..." },
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
```

## Field rules

- `speciality_slug` - must match a slug seeded by `sql/0002_seed_specialities.sql`
  (beta content: `anaesthesiology`). The publisher resolves it to the seeded
  speciality ULID; it never creates specialities.
- `key` (chapter and qnas) - PERMANENT identity handle, unique within the
  SPECIALITY, never renamed once published. `ids.lock` maps keys to minted
  ULIDs; SR state hangs off those ULIDs. Renaming a `key` mints a new
  identity and orphans recall history - do not do it. Generated content keys
  are minted by the generator's ledger (first 16 hex chars of sha256 of the
  normalized question text, reconciled provenance-first on re-runs); hand
  content uses stable slugs.
- `slug`, `title` - mutable path metadata. Rename freely; identity is the ULID.
- Slug format: lowercase `a-z0-9` groups separated by single hyphens
  (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- `sections` - non-empty array; `key` unique within the qna; recommended keys
  follow the D16 answer anatomy: `definition`, `indications`, `technique`,
  `complications`, `summary` (free-form allowed; the validator checks shape,
  not vocabulary). `body_md` is Markdown. Book-grounded answers carry
  verbatim quotes with inline citation lines
  ("- Miller's Anesthesia, Ch.44, p.1413").
- `earns_marks` - the "What earns marks" outline; every `section_key` must
  match a `sections[].key` in the same qna. May be `[]`.
- `years` - optional freeform PYQ string, e.g. `"2019, 2022"`. `marks` -
  optional integer.
- `chapter.exam_weight` - yield signal: the SUM of year-appearances of the
  questions assigned to the chapter (a question asked 6 times contributes 6).
- `images[].file` - path relative to `<chapter-dir>/images/`. The build
  converts to WebP, resizes to fit 1600x1600, and re-encodes down the quality
  ladder (80, 60, 40) until <= 204800 bytes; if still over, the build fails.
  `caption` and `content_description` are mandatory (TalkBack, D20).

## Licensing: de-brand rule + holding area (amended 2026-07-06)

Founder-signed amendment (office hours + eng review amendment 3, 2026-07-06):

- The REPO and every DATABASE stay absolutely publisher-text-free until the
  Miller/Elsevier license is signed: no verbatim book text, no scanned
  figures, anywhere git tracks or publish writes.
- HOLDING-AREA GENERATION of licensed-source artifacts is explicitly allowed
  pre-license: the generator writes chapter.json drafts containing Miller
  text ONLY under `ingestion/holding/` (gitignored) and mirrors them to the
  same Google Drive folder that holds the book PDF. The PDF itself is never
  committed.
- `ids.lock` and the generator's key ledger contain ZERO publisher text and
  ARE committed - identity must survive even if the holding area is lost.
- Publishing to any database is additionally gated:
  `node src/publish.js <dir> --allow-publish` with env `LICENSE_SIGNED=true`.
  This gate is never weakened; it is the legal enforcement point.

## CLI usage

```
node src/build.js <chapterDir> <outDir> [lockPath]
    authoring -> canonical (mints/reuses ULIDs via the speciality ids.lock;
    lockPath defaults to <chapterDir>/../ids.lock)
node src/validate.js <canonicalDir>
    CI gate; exit 0 = OK, exit 1 = ERROR lines on stderr
LICENSE_SIGNED=true node src/publish.js <canonicalDir> [more dirs...] --allow-publish
    DATABASE_URL env required. After a cross-chapter move, pass BOTH affected
    chapters in ONE invocation (batch-republish rule): identity survives
    either order, and the batch shrinks the transient-absence window.
```

## Canonical output (schema v2)

`<outDir>/chapter.json` + `<outDir>/images/<image-ulid>.webp` mirror the DB
row shape:

```json
{
  "schema_version": 2,
  "speciality_slug": "anaesthesiology",
  "chapter": {"id": "<ULID>", "title": "...", "slug": "...", "sort_order": 1, "exam_weight": 10},
  "qnas": [{"id": "<ULID>", "chapter_id": "<ULID>", "question": "...", "years": "2019, 2022", "marks": 10, "earns_marks": [...], "sections": [...], "sort_order": 1}],
  "images": [{"id": "<ULID>", "qna_id": "<ULID>", "caption": "...", "content_description": "...", "file": "images/<ULID>.webp", "byte_size": 12345, "sha256": "<hex>", "sort_order": 1}]
}
```
