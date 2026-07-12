# Opus-Generated Answer Corpus -> New Heroku DB

**Date:** 2026-07-12
**Status:** DESIGN (awaiting spec review)

## Goal

For every question in every paper of every speciality in `Qs/`, generate a
structured DNB-style model answer with Claude Opus 4.8 (effort=max), group the
questions into chapters that emerge from the questions themselves, and store
`speciality -> chapter -> qna(answer)` in a NEW Heroku Postgres app so the
DiploMate app can render the answers.

## Decisions locked with founder (2026-07-12)

These OVERRIDE the documented content strategy for this run. The founder was
shown the conflicts (see "Deliberate departures") and chose each anyway.

1. **Answer source: free Opus generation.** Opus writes each answer from its own
   knowledge. No textbook, no license gate, no verbatim quote verifier.
2. **Scope: all 57 specialities** in `Qs/` (the full corpus), not the
   Anaesthesia-only pilot.
3. **DB target: a NEW Heroku app + Postgres**, isolated from the existing
   DiploMate production DB.
4. **Answer shape: structured exam answer** (`sections[]` + `earns_marks[]`) -
   the exact shape `server/src/routes/chapters.js` already serves.
5. **Run mode: Batches API** (50% cheaper, async, <=24h, unordered).

## Deliberate departures from existing strategy (recorded, not re-litigated)

- The documented moat is verbatim, license-gated Miller quotes with a mechanical
  substring verifier (`ingestion/generator/` plan D, memory
  `diplomate-content-pass-design`). This run discards that: answers are
  unverified LLM output. Founder accepts.
- The approved plan is Anaesthesia beachhead, pilot-first. This run is 30x that.
- A second DB the app does not read from is inert until the app is repointed.
  Isolation is intentional (staging / fork / teardown-safe experiment).

## Architecture

One resumable Node ESM tool under `ingestion/corpus/` (new folder; the existing
`ingestion/generator/` verbatim stages are NOT used). Reuses the built
extraction + dedup modules; adds Opus generation, chapter canonicalization, and
Postgres publish.

```
Qs/<speciality-slug>/<year>/*.pdf
  |
  |  STAGE 1  extract (local, hours; OCR for scans)         [REUSE extract.js]
  v
  { question_text, year, paper, position, marks? } per paper
  |
  |  STAGE 2  dedup to unique questions                     [REUSE ledger.js]
  v
  manifest.jsonl: { key, speciality_slug, question, years, marks? }
  |            (key = sha256-16 of normalized question text)
  |
  |  STAGE 3  Opus 4.8 effort=max, Batches API              [NEW]
  v          one request per unique key ->
  { key, chapter_title, sections[], earns_marks[] }
  |
  |  STAGE 4  canonicalize chapters per speciality          [NEW]
  v          (merge synonym/near-dup titles -> chapter set)
  |
  |  STAGE 5  publish to new Heroku Postgres                [NEW]
  v          upsert speciality, upsert chapter, insert qna (idempotent)
new DB: specialities -> chapters -> qnas
```

### Stage 1 - extraction (reuse)

`extractQuestions(pdfPath)` from `ingestion/generator/src/extract.js` already
handles text PDFs and OCR fallback (poppler + tesseract, both present), splits
numbered questions, stamps year/paper, and emits a per-paper QA report that
flags zero-question / high-garble / count-mismatch papers. Walk all
`Qs/<slug>/<year>/*.pdf`. Scanned papers OCR slowly (per-page render + tesseract)
so Stage 1 may run for hours; the QA report is the loud gate for bad papers.

### Stage 2 - dedup (reuse)

DNB repeats questions across years. `ledger.js` provides `normalizeQuestion` and
`questionKey` (sha256-16 of normalized text). Collapse duplicates within a
speciality to one unique question; accumulate the set of years it appeared into a
`years` string. `key` is the stable identity used everywhere downstream and as
the `qnas.id` primary key, which makes every later step idempotent.

### Stage 3 - Opus generation (new)

One Batches API request per unique question. Per-request params:

```js
{
  custom_id: key,
  params: {
    model: "claude-opus-4-8",
    max_tokens: 16000,
    thinking: { type: "adaptive" },
    output_config: {
      effort: "max",
      format: { /* JSON schema below */ }
    },
    messages: [{ role: "user", content: PROMPT }]
  }
}
```

Structured-output schema each answer must match:

```jsonc
{
  "chapter_title": "string", // e.g. "Airway Management"
  "sections": [
    // the answer body the app renders
    { "key": "string", "heading": "string", "body_md": "string" },
  ],
  "earns_marks": [
    // mark-scheme anchors -> section keys
    { "label": "string", "section_key": "string" },
  ],
}
```

`PROMPT` gives Opus: the speciality name, the exam context (DNB/DrNB theory
paper, structured model answer with a marks scheme), the question text and its
marks, and instructs it to (a) name the single best chapter/topic the question
belongs to and (b) write the answer as titled sections with `earns_marks`
anchoring each scoring point to a section. Batch chunks respect the API limits
(<=100k requests / 256MB per batch); the full corpus is chunked across batches.

- API facts (from claude-api skill): effort=max is supported on Opus 4.8 via
  `output_config.effort`; adaptive thinking only (no `budget_tokens`);
  structured output via `output_config.format` + `messages.parse()`; batch
  results are UNORDERED, keyed by `custom_id`. SDK: `@anthropic-ai/sdk`.

### Stage 4 - chapter canonicalization (new)

The Batches choice creates a real tension: batch requests are submitted
all-at-once and unordered, so the chapter list CANNOT grow live "as each Q is
encountered." Each request independently proposes a `chapter_title`, so the same
topic drifts across names ("Airway", "Difficult Airway", "Airway Management").

Resolution, per speciality, after its batch returns:

1. Collect the distinct proposed `chapter_title`s.
2. One cheap Opus call (effort high, small input) returns a canonical mapping
   `{ raw_title -> canonical_title }` that merges synonyms and near-duplicates.
   57 such calls total, negligible cost.
3. `slugify(canonical_title)` -> chapter slug; dedupe slugs deterministically.

Chapters therefore still come from the questions ("created as encountered"),
just reconciled after the batch rather than grown live. **Alternative considered:**
live-incremental generation (process questions sequentially, pass the growing
chapter list into each prompt) yields cleaner emergent chapters but forfeits
batching, roughly doubling cost. Rejected given the Batches decision; revisit
only if canonicalization proves weak on the canary.

### Stage 5 - publish (new)

New DB schema = the existing app schema, applied verbatim so the app renders
unchanged: run `sql/0001_content_v0.sql` then `sql/0004_drop_topics.sql` on the
new database (net: `specialities`, `chapters`, `qnas`, `images`, `app_config`;
`topics` dropped; indexes added). No new DDL invented.

- Seed specialities: reuse `sql/0002_seed_specialities.sql` (61 rows, slugs match
  `Qs/` dir names). For any `Qs/` dir whose slug is absent from the seed, mint a
  speciality row (slug = dir name, name = title-cased, exam_type = 'DNB').
- Upsert chapter: deterministic `id = sha256-16(speciality_id + '|' + slug)`;
  `ON CONFLICT (speciality_id, slug) DO NOTHING`.
- Insert qna: `id = key` (Stage 2), `chapter_id`, `question`, `years`, `marks`,
  `earns_marks` (JSONB), `sections` (JSONB), `sort_order`. `ON CONFLICT (id) DO
NOTHING` -> re-runs never duplicate, the whole pipeline is resumable.

## Resumability

- Stage 1/2 write `manifest.jsonl` (all unique questions). Regenerating is cheap
  and deterministic; delete to force a re-extract.
- A local `batches.jsonl` ledger maps `batch_id -> {speciality, status}` so a
  restart resumes polling instead of resubmitting.
- Stage 5 idempotency (qnas.id = key, ON CONFLICT DO NOTHING) means an
  interrupted publish resumes by re-streaming batch results; already-inserted
  rows are skipped.

## Canary-first ladder (the spend is real)

1. **1 paper** (~10 questions, live calls not batch, for speed): eyeball answer
   quality and the sections/earns_marks shape. Measures real tokens/question.
2. **1 speciality** (Anaesthesiology, ~500 unique questions, via Batches):
   proves extraction coverage, chapter canonicalization, and end-to-end publish.
3. **All 57 specialities** (Batches), only after 1-2 look right.

**Cost:** Opus 4.8 pricing is masked in the available API reference, so no dollar
figure is quoted here. The canary reports actual input+output tokens per
question; multiply by the founder's Opus rate (batch = 50% off) for the real
number before authorizing the full run. Order-of-magnitude corpus size:
~15k-30k unique questions after dedup.

## Preconditions (blockers before Stage 3 can run)

1. **`ANTHROPIC_API_KEY`.** No `ant` CLI and no profile on this machine, so there
   are genuinely no credentials. Founder sets the key in the env or a gitignored
   `.env` the tool reads. Not pasted in chat.
2. **Cost ceiling approved** after the canary reports real tokens/question.
3. **Heroku account.** CLI is authed as `parth.mitblr2023@learner.manipal.edu`
   (not the founder's Google email). The new app and its Postgres monthly charge
   land on that account unless the founder switches first.

## Out of scope (explicitly skipped)

Miller ingestion, the quote verifier, the license gate, figure extraction, the
`images` table population, ULID minting via `build.js`, and the existing
`ingestion/generator/` classify/generate stages. None apply to free generation.
DESIGN.md answer-on-white / examiner-red rendering is the app's concern; this
run only produces the `sections` data it renders.

## Success criteria

- `pdftotext`/OCR extraction produces a QA report per paper; flagged papers are
  listed, not silently dropped.
- Canary answers render in the app's qna shape (sections + earns_marks) and read
  as DNB model answers to a human check.
- Re-running any stage inserts zero duplicate qnas (idempotency proven).
- Full run: every non-flagged unique question across 57 specialities has a qna
  row under an emergent chapter, in the new DB.

## Open risks

- Extraction quality on scanned/garbled papers caps corpus completeness; the QA
  report surfaces it but does not fix it.
- Free-generated answers are unverified medical content. No verifier exists in
  this path by design; correctness is the founder's editorial risk.
- Chapter canonicalization is heuristic + one cleanup call; messy taxonomies may
  need a second pass. Canary is the checkpoint.
