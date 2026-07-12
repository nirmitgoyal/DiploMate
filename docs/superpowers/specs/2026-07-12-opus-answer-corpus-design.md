# Bedrock-Generated Answer Corpus -> New Heroku DB (26 specialities, <=$100)

**Date:** 2026-07-12
**Status:** DESIGN (awaiting spec review)

## Goal

For every question in every paper of 26 selected specialities in `Qs/`, generate
a structured DNB-style model answer with Claude on Amazon Bedrock, group the
questions into chapters that emerge from the questions, and store
`speciality -> chapter -> qna(answer)` in a NEW Heroku Postgres app so the
DiploMate app can render the answers. Total Anthropic/Bedrock spend must stay
UNDER $100.

## Decisions locked with founder (2026-07-12)

Later decisions here SUPERSEDE the first-pass ones (Opus/all-57/Batches). The
founder was shown cost math at each step and chose each explicitly.

1. **Provider: Amazon Bedrock**, authed by `AWS_BEARER_TOKEN_BEDROCK` (already in
   `~/.zshrc`). NOT the first-party Anthropic API.
2. **Model: Claude Haiku 4.5** (`claude-haiku-4-5` family; exact Bedrock model id
   resolved at the canary). It is the only Claude tier that fits the $100 cap at
   this scale: Opus 4.8 max ~= $6,000, Sonnet ~= $160, Haiku 4.5 ~= $60-75.
   Tradeoff accepted: shallower reasoning than Opus; adequate for factual DNB
   answers; canary verifies quality. No `effort` param (Haiku rejects it).
3. **Hard cost cap: $100**, enforced by a running cost meter that HALTS at a $90
   ceiling (margin) plus `max_tokens` ~= 2000 per answer. The token cap is exact
   even though the real Bedrock Haiku price is masked in the available reference.
4. **Scope: 26 specialities** (list below), NOT all 57.
5. **DB target: a NEW Heroku app + Postgres**, isolated from production.
6. **Answer shape: structured exam answer** (`sections[]` + `earns_marks[]`) - the
   exact shape `server/src/routes/chapters.js` serves.
7. **Run mode: live concurrent calls** (Batches dropped; Bedrock live is simpler
   and the cost fits without the 50% batch discount).

### The 26 specialities (slugs reconciled to real `Qs/` folders)

anaesthesiology, anatomy, biochemistry, cardiac-anaesthesia,
clinical-immunology-and-rheumatology, critical-care-medicine,
dermatology-venereology-and-leprosy, emergency-medicine, endocrinology,
forensic-medicine, general-medicine, general-surgery, microbiology,
**neuro-anaesthesia** (list said "neuro-anesthesia"), neurosurgery,
obstetrics-and-gynaecology, orthopaedics, otorhinolaryngology-ent,
palliative-medicine, pathology, **paediatrics** (list said "pediatrics"),
physiology, radiation-oncology, **radio-diagnosis** (list said "radiology";
founder picked radio-diagnosis), respiratory-medicine, urology.

Corpus size: 1,359 PDF papers -> ~13.6k gross questions -> ~6.8k unique after
dedup (measured 2026-07-12).

## Deliberate departures from existing strategy (recorded, not re-litigated)

- The documented moat is verbatim, license-gated Miller quotes with a substring
  verifier (`ingestion/generator/` plan D). This run discards that: answers are
  unverified LLM output. Founder accepts.
- A second DB the app does not read from is inert until the app is repointed.
  Isolation is intentional.

## Architecture

One resumable Node ESM tool under `ingestion/corpus/` (new folder; the existing
`ingestion/generator/` verbatim stages are NOT used). Reuses the built extraction

- dedup modules; adds Bedrock generation, chapter canonicalization, Postgres
  publish, and the cost meter.

```
Qs/<speciality-slug>/<year>/*.pdf   (26 slugs only)
  |
  |  STAGE 1  extract (local, hours; OCR for scans)        [REUSE extract.js]
  v  { question_text, year, paper, position, marks? } per paper
  |
  |  STAGE 2  dedup to unique questions                     [REUSE ledger.js]
  v  manifest.jsonl: { key, speciality_slug, question, years, marks? }
  |
  |  STAGE 3  Bedrock Haiku 4.5, LIVE concurrent            [NEW]
  v  cost meter gates every dispatch; one call per unique key ->
  |  { key, chapter_title, sections[], earns_marks[] }
  |
  |  STAGE 4  canonicalize chapters per speciality          [NEW]
  v  (one cheap Haiku call/speciality merges synonym titles)
  |
  |  STAGE 5  publish to new Heroku Postgres                [NEW]
  v  upsert speciality, upsert chapter, insert qna (idempotent by key)
new DB: specialities -> chapters -> qnas
```

### Stage 1 - extraction (reuse)

`extractQuestions(pdfPath)` from `ingestion/generator/src/extract.js` handles text
PDFs and OCR fallback (poppler + tesseract, both present), splits numbered
questions, stamps year/paper, and emits a per-paper QA report flagging
zero-question / high-garble / count-mismatch papers. Walk only the 26
`Qs/<slug>/<year>/*.pdf` trees. Scanned papers OCR slowly, so Stage 1 may run for
hours; the QA report is the loud gate for bad papers.

### Stage 2 - dedup (reuse)

DNB repeats questions across years. `ledger.js` gives `normalizeQuestion` and
`questionKey` (sha256-16 of normalized text). Collapse duplicates within a
speciality to one unique question; accumulate its years into a `years` string.
`key` is the stable identity used downstream and as `qnas.id`, making every later
step idempotent.

### Stage 3 - Bedrock generation (new)

Live concurrent calls (concurrency ~= 8), each a Messages request to the Bedrock
runtime with bearer-token auth:

- Endpoint: `POST https://bedrock-runtime.<region>.amazonaws.com/model/<modelId>/invoke`
  with header `Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK`.
- Body: native Anthropic Messages shape with `anthropic_version: "bedrock-2023-05-31"`,
  `max_tokens: 2000`, the prompt, and NO `effort`/`thinking` (Haiku rejects effort;
  keep it simple and cheap).
- Region default `us-east-1`; canary confirms Haiku 4.5 model access is enabled
  and pins the exact Bedrock model id.
- SDK vs raw: the canary decides. Preference is `@anthropic-ai/bedrock-sdk`
  (`AnthropicBedrockMantle`) IF it honors `AWS_BEARER_TOKEN_BEDROCK`; otherwise a
  raw `https` POST with the Bearer header. Do not block the design on SDK auth
  behavior; the canary proves one working call first.

Structured output: do NOT depend on the `output_config.format` beta on Bedrock.
The prompt instructs Haiku to return STRICT JSON matching this schema; the tool
parses + validates it, retries once on parse failure, else flags the question:

```jsonc
{
  "chapter_title": "string", // e.g. "Airway Management"
  "sections": [{ "key": "string", "heading": "string", "body_md": "string" }],
  "earns_marks": [{ "label": "string", "section_key": "string" }],
}
```

`PROMPT` gives Haiku the speciality name, DNB exam context (structured model
answer with a marks scheme, be concise to respect the 2000-token budget), the
question text and marks, and asks it to (a) name the single best chapter and
(b) write titled sections with `earns_marks` anchoring each scoring point.

### The cost meter (money-safety, tested)

- Rates are configurable (`RATE_IN`, `RATE_OUT` per 1M tokens; default to public
  Haiku 4.5 ~= $1 in / $5 out, since the reference is masked). After each response,
  read `usage.input_tokens` / `usage.output_tokens`, add
  `in*RATE_IN + out*RATE_OUT` to a running total persisted to `spend.json`.
- Before dispatching any new call, if `total + worstCaseNext >= CEILING` ($90
  default), STOP dispatching and drain in-flight calls. Worst-case overshoot =
  concurrency _ (2000 out _ RATE_OUT) ~= $0.08, so the true stop is far under $100.
- A halt is resumable: qnas already inserted are skipped (idempotency), so a later
  run with fresh budget continues where it stopped.
- This meter is the hard guarantee. The canary-derived tokens/question is the
  soft pre-check that the full 26 will fit before we start them.

### Stage 4 - chapter canonicalization (new)

Concurrent generation cannot grow the chapter list live, so each answer proposes a
free-form `chapter_title` that drifts across names. Per speciality, after its
questions are generated: collect distinct titles, one cheap Haiku call returns a
canonical mapping `{ raw -> canonical }` merging synonyms, then `slugify` +
dedupe. Chapters still come from the questions, reconciled after generation. 26
cleanup calls, negligible cost. Canary checks this is good enough.

### Stage 5 - publish (new)

New DB schema = the existing app schema applied verbatim: run
`sql/0001_content_v0.sql` then `sql/0004_drop_topics.sql` (net: `specialities`,
`chapters`, `qnas`, `images`, `app_config`; `topics` dropped; indexes added). No
new DDL.

- Seed specialities: reuse `sql/0002_seed_specialities.sql`; the 26 slugs all
  exist in that seed, so no minting needed.
- Upsert chapter: `id = sha256-16(speciality_id + '|' + slug)`;
  `ON CONFLICT (speciality_id, slug) DO NOTHING`.
- Insert qna: `id = key`, plus `chapter_id`, `question`, `years`, `marks`,
  `earns_marks` (JSONB), `sections` (JSONB), `sort_order`;
  `ON CONFLICT (id) DO NOTHING` -> re-runs never duplicate; pipeline is resumable.

## Canary-first ladder

1. **1 paper** (~10 questions): proves the whole Bedrock path end to end - bearer
   auth, region, exact model id, JSON parse, sections/earns_marks shape. Measures
   real tokens/question. Cost ~cents.
2. **1 speciality** (anaesthesiology, ~500 unique questions): proves extraction
   coverage, chapter canonicalization, publish, and the cost meter. Extrapolate
   tokens/question across the other 25 and CONFIRM the full 26 stays < $100 before
   proceeding.
3. **Remaining 25 specialities**, under the live meter (auto-halts at $90).

## Preconditions

1. **`AWS_BEARER_TOKEN_BEDROCK`** - present in `~/.zshrc`. The tool reads it from
   the env. Never printed or committed.
2. **Bedrock region + model access** - default `us-east-1`; canary confirms Haiku
   4.5 is enabled for the account there (else enable access or fall back to Haiku
   3.5 / another enabled model).
3. **Heroku account** - CLI is authed as `parth.mitblr2023@learner.manipal.edu`
   (not the founder's Google email). The new app and its Postgres monthly charge
   land there unless the founder switches first.
4. **Cost ceiling** - $90 meter default; confirm real tokens/question after the
   canary before the remaining 25.

## Out of scope (explicitly skipped)

Opus 4.8, `effort=max`, the Batches API, Miller ingestion, the quote verifier, the
license gate, figure extraction, `images` population, ULID minting via `build.js`,
and the existing `ingestion/generator/` classify/generate stages. None apply.

## Success criteria

- Extraction produces a QA report per paper; flagged papers are listed, not
  silently dropped.
- Canary answers render in the app's qna shape (sections + earns_marks) and read
  as DNB model answers to a human check.
- The cost meter provably stops before $100 (unit test on the halt logic).
- Re-running any stage inserts zero duplicate qnas.
- Full run: every non-flagged unique question across the 26 specialities has a
  qna row under an emergent chapter in the new DB, for total spend < $100.

## Open risks

- Extraction quality on scanned/garbled papers caps completeness; the QA report
  surfaces it, does not fix it.
- Free-generated Haiku answers are unverified medical content; correctness is the
  founder's editorial risk, and Haiku is shallower than Opus.
- If real Haiku tokens/question run high, the $90 meter may stop before all 26
  finish; the run is resumable but may need the founder to raise the ceiling
  (still their call, still under their $100 intent).
- Bedrock bearer-token auth path (SDK vs raw) unproven until the canary.
