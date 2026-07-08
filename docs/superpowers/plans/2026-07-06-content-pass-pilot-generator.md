# Content Pass Pilot + Lane D: Offline Answer Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the offline four-stage content generator that turns 86 Anaesthesiology PYQ PDFs + Miller's Anesthesia into the graded, verbatim-cited, chapter-bucketed answer corpus - AFTER a by-hand pilot proves the flag rate, quote-quality bar, and tie-break thresholds on one chapter. Every generated quote passes a mechanical substring verifier; nothing stochastic runs at serve time; the license gate blocks publish throughout.

**Architecture:** A new `ingestion/generator/` package inside the existing `ingestion/` npm package (NOT a parallel worktree with lane B - same package). It reuses lane B's `build -> validate -> publish` unchanged: the generator emits authoring `chapter.json` v2 into the gitignored `ingestion/holding/` (Miller text lives ONLY there pre-license), then the shipped pipeline builds/validates/publishes it. Model calls (classification + extractive answer assembly) use the Anthropic SDK against a frozen page index; a non-LLM quote verifier is the enforcement point that makes "verbatim" checkable. The hand pilot (Task 0) is a no-code gate that MUST complete before Task 6 (Stage 3 generation) and whose license/quote-length answers gate the at-scale run.

**Tech Stack:** Node 22 LTS, ESM, `node:test`; `@anthropic-ai/sdk` (model calls); `pdftotext`/`pdftoppm`/`pdftoppm` via `poppler-utils` (shell out); `tesseract` (OCR fallback); `sharp` (already a dep, figure crops feed the existing resizer); no new runtime dependency (generator never runs in production).

**Source of truth:** design doc `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-claude-jolly-banach-f5aef8-design-20260706-134407.md` Stages 0-4 + "The Assignment" + "ENG REVIEW AMENDMENTS (2026-07-06)" (amendments SUPERSEDE the body); test plan `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-main-eng-review-test-plan-20260706-151544.md` (EVAL + verifier catalog).

## Global Constraints

Every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, or doc; plain hyphens only (user convention).
- **Publish stays blocked until `LICENSE_SIGNED=true`.** The generator NEVER calls `publish.js` past its gate and NEVER weakens `gateCheck`. The generator's own output stops at `ingestion/holding/`; a human runs `build -> validate` on holding artifacts, and `publish` only after the license is signed.
- **HARD ORDER: the hand pilot (Task 0) precedes ALL generator code that produces answers.** Tasks 1-5 (page index, OCR gate, extraction, classification scaffolding, verifier) may be built in parallel with the pilot because the pilot USES the verifier to calibrate normalization - but Task 6 (Stage 3 answer generation at any scale) and Task 10 (at-scale run) MUST NOT start until Task 0's scorecard exists and its go/no-go is GO.
- **Quote-length written terms are a PRECONDITION for the at-scale Stage 3 run (amendment 12) - RESOLVED: no cap.** Founder confirmed 2026-07-06 the signed Miller license imposes NO per-answer verbatim word cap. The marker gate STAYS as a safety interlock: Task 6's generator refuses `--scale` unless the `QUOTE_TERMS` env var is set (now `QUOTE_TERMS=no-cap`); it records per-answer verbatim word count as metadata regardless, so a later cap is auditable retroactively (amendment 12, T13). The hand pilot is exempt either way.
- **Miller license is SIGNED (founder, 2026-07-06).** `LICENSE_SIGNED=true` may be set legitimately at the publish step. This unblocks publish only; generation still stops at `ingestion/holding/` and a human runs `build -> validate -> publish` after reviewing the flag queue. Signing changes NO code - the gate is an env-var check.
- All generated content uses `speciality_slug` **`anaesthesiology`** and the authoring v2 shape lane B's `AUTHORING.md` documents (chapter.key, qnas hang off chapter, no topics).
- Miller text is licensed-source: generated artifacts containing it live ONLY under `ingestion/holding/` (gitignored, lane B Task 5). The book PDF is read from Google Drive / a local copy and is NEVER committed. `ids.lock` + the key ledger contain ZERO publisher text and ARE committed.
- Identity (amendments 1+2): the generator writes into the COMMITTED speciality `ids.lock` via lane B's `build.js`. Ledger reconciliation is PROVENANCE-FIRST: match new extractions to ledger entries by (paper, year, question position), then normalized-text similarity; the sha256-16 key mints ONLY on no-match; ambiguous matches go to a human review queue. Text edits/OCR fixes/dedup re-clusters NEVER re-key a published question.
- `exam_weight` = SUM of year-appearances of a chapter's assigned questions (amendment 8), NOT deduped qna count.
- TDD per task: failing test first, run it (expect FAIL), minimal implementation, run again (expect PASS), commit. The verifier, ledger reconciliation, slug hygiene, page-mapping, and exam_weight are non-trivial logic and MUST carry tests (test plan coverage). Model-calling stages carry a fixture-stubbed unit test plus the Stage 2 EVAL (Task 9).

**Working directory:** all commands run from `/Users/nirmit/Codebases/DiploMate/ingestion/`. Requires `poppler-utils` (`pdftotext`, `pdftoppm`) and `tesseract` on PATH; `ANTHROPIC_API_KEY` (or `ant auth login` profile) for model stages. Git commits from the repo root.

**Execution order:** this lane runs AFTER lane B merges (same `ingestion/` package). The hand pilot (Task 0) runs before/alongside the code tasks and gates Task 6. The at-scale run (Task 10) is the last gate and needs the license + quote terms + a GO scorecard.

---

### Task 0: The hand pilot (NO CODE - the go/no-go gate)

**Files:**

- Create: `ingestion/holding/pilot/scorecard.md` (gitignored location; the scorecard itself carries no verbatim Miller text beyond the 3-4 sample answers, which stay in holding)
- Modify: `TODOS.md` (sections 5, 8, 9 - record the pilot-measured numbers against the trigger-gated deferrals)

**Interfaces:**

- Produces: the calibrated verifier normalization rules (Task 5 consumes), the confidence/ambiguity thresholds (Task 7 consumes), the go/no-go decision (Task 6 + Task 10 gate on it), and the projections that trigger (or do not) TODOS items 5/8/9.

This is "The Assignment" from the design doc plus the amendment-13 expanded scorecard. It is a founder/human task; the plan records WHAT to produce so the code tasks have their inputs.

- [ ] **Step 1: Record the license + quote-terms answers (BOTH RESOLVED 2026-07-06)**

Both legal preconditions are already answered by the founder - record them, do not re-chase them:

- (a) Miller/Elsevier license: **SIGNED**. `LICENSE_SIGNED=true` is now legitimate at publish.
- (b) Per-answer verbatim word cap: **none - "no cap"** (amendment 12).

Write both into `scorecard.md` under a `## Legal` heading, and set the marker the generator reads: `QUOTE_TERMS=no-cap` (env var at scale-run time; also noted in the scorecard). Neither blocks the hand pilot; both clear the at-scale run once the pilot reads GO.

- [ ] **Step 2: Pick one high-yield Miller chapter, hand-build 3-4 verbatim answers**

Pick a high-yield chapter; pull its ~10-20 mapped PYQ questions; hand-build 3-4 verbatim-cited answers in the authoring v2 shape (each `sections[].body_md` a verbatim Miller quote + inline citation line); mark which questions Miller cannot answer (the flag set). Confirm every citation against the PHYSICAL book page (amendment 6).

- [ ] **Step 3: Calibrate the verifier normalization rules on REAL scanned text**

Run the pilot quotes through the substring check (Task 5's verifier, or by hand if built later) against `pdftotext` output of the cited pages. Catalog every normalization the real Miller scan needs: EOL hyphenation joins, soft-hyphen stripping, two-column interleave, caption/footnote injection, table linearization, cross-page (N||N+1) spans (amendment 5). These become Task 5's normalization catalog + test cases.

- [ ] **Step 4: Record the amendment-13 scorecard numbers**

`scorecard.md` must carry:

- (a) flag rate on the high-yield chapter AND on a corpus-wide RANDOM ~10-question slice (the honest upper bound - amendment 13a / T17);
- (b) answer quality: 1-3 target DNB finalists read the 3-4 stitched verbatim answers - does it read as an exam answer? (amendment 13b / T17);
- (c) founder review throughput: minutes/question and minutes/figure, projected to the full ~1000-question corpus (the real critical path after the license - amendment 13c / T17);
- (d) figure bytes/chapter AND cross-qna figure duplication factor (distinct sha256 vs total), projected against the Essential-0 1GB cap with a ~700MB decision threshold (amendment 13d / T9 / TODOS 5);
- (e) ONE hand-built own-words fallback answer for the same question next to its verbatim twin (license-refusal hedge; verbatim architecture stands - amendment 13e / T18);
- the tie-break thresholds settled against real questions (confidence floor + "ambiguous" trigger - Open Q4, feeds Task 7);
- the GO / NO-GO decision for the full pass.

- [ ] **Step 5: Update TODOS with the measured triggers**

In `TODOS.md`: under item 5 record the measured figure bytes/chapter and the Essential-0 projection; under item 8 record the retrieval-miss share of `no-source-coverage` flags (does the embedding index trigger fire?); under item 9 record projected total figure-review time (does the batch-UI trigger fire?). These are DATA additions to existing deferrals, not new scope.

- [ ] **Step 6: Commit the TODOS update (scorecard stays in gitignored holding)**

```bash
git add TODOS.md
git commit -m "docs(todos): pilot-measured triggers for embedding index / figure UI / bytea budget"
```

---

### Task 1: generator package scaffold + page index (Stage 0 substrate)

**Files:**

- Create: `ingestion/generator/README.md` (how to run; NEVER commits Miller text)
- Create: `ingestion/generator/src/page_index.js`
- Create: `ingestion/generator/test/page_index.test.js`
- Create: `ingestion/generator/fixtures/` (tiny synthetic PDFs - NO Miller text)

**Interfaces:**

- Produces: `buildPageIndex(pdfPath) -> [{pdf_page, text}]` (one entry per PDF page, via `pdftotext -layout`); `pageText(index, pdfPage) -> string`. Tasks 3, 5, 6 consume the index.

- [ ] **Step 1: Failing test on a synthetic PDF**

Create `ingestion/generator/test/page_index.test.js`. Generate a 2-page text PDF in the test itself (shell `pdftoppm`-free path: write a known text PDF fixture with a tiny generator, or check in a synthetic `sample.pdf` created from owned text - NEVER Miller). Assert the index has 2 entries and `pageText(index, 1)` contains the known first-page string.

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPageIndex, pageText } from "../src/page_index.js";
import { fileURLToPath } from "node:url";

const SAMPLE = fileURLToPath(
  new URL("../fixtures/sample-2page.pdf", import.meta.url),
);

test("page index has one entry per page and returns page text", async () => {
  const index = await buildPageIndex(SAMPLE);
  assert.equal(index.length, 2);
  assert.match(pageText(index, 1), /owned sample page one/i);
  assert.match(pageText(index, 2), /owned sample page two/i);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test generator/test/page_index.test.js`
Expected: FAIL - `page_index.js` does not exist (and the fixture PDF must be created; if `pdftotext` is absent, the test errors with the spawn failure - install `poppler-utils`).

- [ ] **Step 3: Implement `page_index.js`**

```js
import { execFile } from "node:child_process";
import { promisify } from "node:util";
const exec = promisify(execFile);

// One entry per PDF page from the text layer. -layout preserves column
// geometry so the verifier's two-column normalization has something to work
// with; the page delimiter is the form feed pdftotext emits between pages.
export async function buildPageIndex(pdfPath) {
  const { stdout } = await exec("pdftotext", ["-layout", pdfPath, "-"], {
    maxBuffer: 512 * 1024 * 1024,
  });
  return stdout.split("\f").map((text, i) => ({ pdf_page: i + 1, text }));
}

export function pageText(index, pdfPage) {
  return index.find((p) => p.pdf_page === pdfPage)?.text ?? "";
}
```

- [ ] **Step 4: Run to verify it passes; commit**

Run: `node --test generator/test/page_index.test.js` -> PASS

```bash
git add ingestion/generator/README.md ingestion/generator/src/page_index.js ingestion/generator/test ingestion/generator/fixtures
git commit -m "feat(generator): Stage 0 page index over pdftotext text layer"
```

---

### Task 2: book_page to pdf_page mapping, monotonic per volume (T14)

**Files:**

- Create: `ingestion/generator/src/page_map.js`
- Create: `ingestion/generator/test/page_map.test.js`

**Interfaces:**

- Consumes: page index (Task 1).
- Produces: `buildPageMap(index, {volumes}) -> {bookToPdf(bookPage) -> pdfPage, validate() -> string[]}`; derives printed page labels from each page's text, validates STRICTLY MONOTONIC per volume (Miller 9e is two volumes with front matter - amendment 6), returns error strings for non-monotonic runs.

- [ ] **Step 1: Failing test - monotonic pass + a planted inversion**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPageMap } from "../src/page_map.js";

// Synthetic index: printed labels that rise monotonically, then one volume
// boundary reset (front matter -> page 1 again), then a planted inversion.
const good = [
  { pdf_page: 1, text: "front matter ii" },
  { pdf_page: 2, text: "1\nchapter one" },
  { pdf_page: 3, text: "2\nchapter one cont" },
];
const inverted = [
  { pdf_page: 1, text: "1\na" },
  { pdf_page: 2, text: "5\nb" },
  { pdf_page: 3, text: "3\nc" }, // goes backwards -> flagged
];

test("monotonic map resolves book page to pdf page", () => {
  const map = buildPageMap(good, { volumes: [{ startPdfPage: 2 }] });
  assert.deepEqual(map.validate(), []);
  assert.equal(map.bookToPdf(1), 2);
  assert.equal(map.bookToPdf(2), 3);
});

test("a non-monotonic run is flagged, not silently mapped", () => {
  const map = buildPageMap(inverted, { volumes: [{ startPdfPage: 1 }] });
  assert.ok(map.validate().some((e) => /non-monotonic|decreas/i.test(e)));
});
```

- [ ] **Step 2: Run to verify it fails, then implement**

Run: `node --test generator/test/page_map.test.js` -> FAIL (module missing).

Implement `page_map.js`: scan each page's leading numeric label, build an ordered `[{pdfPage, bookPage}]` per volume window, `validate()` returns an error for any book-page sequence that does not strictly increase within a volume, `bookToPdf` does a lookup (nearest-preceding label for pages whose own label did not parse). Keep it a heuristic with a clear ceiling:

```js
// ponytail: leading-integer page-label heuristic; the pilot spot-checks 10
// random pages against the physical book (amendment 6) and the per-volume
// monotonic assertion catches drift. Upgrade to a labelled-index parse only
// if the pilot shows the heuristic misreads material pages.
```

- [ ] **Step 3: Run to verify it passes; commit**

```bash
git add ingestion/generator/src/page_map.js ingestion/generator/test/page_map.test.js
git commit -m "feat(generator): book-to-pdf page map with per-volume monotonic validation (T14)"
```

---

### Task 3: Stage 1 extraction + OCR gate + per-paper QA (T15)

**Files:**

- Create: `ingestion/generator/src/extract.js`
- Create: `ingestion/generator/test/extract.test.js`

**Interfaces:**

- Consumes: page index (Task 1).
- Produces: `probeTextLayer(pdfPath) -> {hasText, coverage}` (fraction of pages with real text); `extractQuestions(pdfPath, {ocr}) -> {questions: [{question_text, year, paper, marks?}], qa: {count, garbleScore}}`; a per-paper QA report. Scanned papers (`coverage` below a floor) route through `tesseract`. Task 4 (dedup/ledger) consumes the questions.

- [ ] **Step 1: Failing test - text PDF vs scanned image PDF**

Using synthetic fixtures (a text `sample.pdf`, an image-only `scan.pdf` created by rasterizing owned text): assert `probeTextLayer` reports `hasText: true` for the text PDF and `hasText: false` for the scan; assert `extractQuestions` on the text PDF returns the known questions with a low garble score.

```js
test("probe distinguishes a text PDF from a scanned image PDF", async () => {
  assert.equal((await probeTextLayer(TEXT_PDF)).hasText, true);
  assert.equal((await probeTextLayer(SCAN_PDF)).hasText, false);
});

test("extraction returns structured questions with a QA report", async () => {
  const { questions, qa } = await extractQuestions(TEXT_PDF, { ocr: false });
  assert.ok(questions.length >= 1);
  assert.ok(questions[0].question_text.length > 0);
  assert.ok(qa.garbleScore < 0.2, "clean text has low garble");
});
```

- [ ] **Step 2: Run to verify it fails, then implement**

`extract.js`: `probeTextLayer` = pages-with-nonwhitespace / total via the page index; below a floor (e.g. 0.5) route the paper through `tesseract` (shell out per page via `pdftoppm` then `tesseract`). `extractQuestions` splits question blocks (numbered-item heuristic + marks-suffix), stamps `year`/`paper` from the filename or first-page header, and computes a garble score (share of non-dictionary tokens / bad-char ratio). QA report = extracted count vs an optional expected count + the garble score + the question list for human skim. Question text anchors permanent keys, so the QA gate is loud, not silent (amendment 7 / OV6).

```js
// ponytail: numbered-item split + marks-suffix heuristic; per-paper QA
// (count vs expected, garble score, human skim) is the gate. Upgrade the
// splitter only for papers the QA report flags.
```

- [ ] **Step 3: Run to verify it passes; commit**

```bash
git add ingestion/generator/src/extract.js ingestion/generator/test/extract.test.js
git commit -m "feat(generator): Stage 1 extraction + OCR gate + per-paper QA report (T15)"
```

---

### Task 4: provenance-first ledger reconciliation + dedup + exam_weight (T12, T16)

**Files:**

- Create: `ingestion/generator/src/ledger.js`
- Create: `ingestion/generator/test/ledger.test.js`

**Interfaces:**

- Consumes: extracted questions (Task 3); the committed speciality `ids.lock` (lane B).
- Produces: `normalizeQuestion(text) -> string` (lowercase, collapse whitespace, strip punctuation + marks-suffix); `questionKey(text) -> string` (first 16 hex of sha256 of the normalized text); `reconcile(extracted, ledger, prevArtifacts) -> {matched: [{key, ...}], minted: [...], ambiguous: [...]}` (provenance-first: (paper, year, position) match, then normalized-text similarity, then mint); `dedupYears(clusters) -> combined years string`; `examWeight(assignedQuestions) -> int` (SUM of year-appearances).

- [ ] **Step 1: Failing tests - the identity guarantees**

```js
test("a typo-edited question reconciles to its existing ledger key (no re-key)", () => {
  const prev = [
    {
      key: "abcd1234abcd1234",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia",
    },
  ]; // trailing period gone
  const r = reconcile(extracted, {}, prev);
  assert.equal(
    r.matched[0].key,
    "abcd1234abcd1234",
    "provenance match wins - text edit must not re-key",
  );
  assert.equal(r.minted.length, 0);
});

test("a genuinely new question mints a fresh sha256-16 key", () => {
  const r = reconcile(
    [
      {
        paper: "2024-II",
        year: 2024,
        position: 1,
        text: "A brand new question about capnography.",
      },
    ],
    {},
    [],
  );
  assert.equal(r.matched.length, 0);
  assert.match(r.minted[0].key, /^[0-9a-f]{16}$/);
});

test("an ambiguous match (same provenance, very different text) queues for review", () => {
  const prev = [
    {
      key: "aaaa1111aaaa1111",
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Define spinal anaesthesia.",
    },
  ];
  const extracted = [
    {
      paper: "2019-I",
      year: 2019,
      position: 3,
      text: "Describe the anatomy of the brachial plexus in full.",
    },
  ];
  const r = reconcile(extracted, {}, prev);
  assert.equal(
    r.ambiguous.length,
    1,
    "same slot, unrelated text -> human decides, never auto re-key",
  );
});

test("exam_weight sums year-appearances, not deduped count (amendment 8)", () => {
  // one question, 6 year-appearances -> contributes 6.
  assert.equal(
    examWeight([{ years: "2015, 2017, 2019, 2021, 2022, 2024" }]),
    6,
  );
  assert.equal(examWeight([{ years: "2019, 2022" }, { years: "2020" }]), 3);
});
```

- [ ] **Step 2: Run to verify they fail, then implement `ledger.js`**

`normalizeQuestion`, `questionKey` (sha256-16), `reconcile` (provenance-first per amendment 2: exact (paper,year,position) hit -> reuse ledger key; else normalized-similarity above a high threshold -> reuse; else if same provenance slot but low similarity -> `ambiguous`; else -> mint), `dedupYears`, `examWeight` (parse each cluster's years string, sum the appearance counts). The sha256-16 mints ONLY on no-match - the failure the ledger exists to prevent is a re-key on any edit.

- [ ] **Step 3: Run to verify they pass; commit**

```bash
git add ingestion/generator/src/ledger.js ingestion/generator/test/ledger.test.js
git commit -m "feat(generator): provenance-first ledger reconciliation + year-appearance exam_weight (T12, T16)"
```

---

### Task 5: the quote verifier - normalization catalog + cross-page (T3)

**Files:**

- Create: `ingestion/generator/src/verifier.js`
- Create: `ingestion/generator/test/verifier.test.js`
- Create: `ingestion/generator/fixtures/layout_cases.json` (content: `[]` - the pilot populates it in Task 0 step 3 with `{name, pageText, quote, expectOk}` triples from real Miller scans)

**Interfaces:**

- Consumes: page index (Task 1), page map (Task 2).
- Produces: `normalize(text) -> string` (the calibrated catalog from the pilot); `verifyQuote(quote, {index, map, bookPage}) -> {ok, citationPage|citationRange, reason?}` - exact substring after normalization against page N, then against N||N+1 concatenation; a boundary match upgrades the citation to a page range; failure returns `reason: 'quote-verification-failed'`. This is the mechanical, non-LLM enforcement point - Task 6 kills any answer whose quote fails.

- [ ] **Step 1: Failing tests - the normalization catalog (amendment 5, test-plan edge cases)**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyQuote, normalize } from "../src/verifier.js";

const idx = (pages) => pages.map((text, i) => ({ pdf_page: i + 1, text }));
const map = { bookToPdf: (n) => n, validate: () => [] };

test("plain exact substring verifies against its page", () => {
  const index = idx(["The trachea bifurcates at the carina."]);
  const r = verifyQuote("The trachea bifurcates at the carina.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
  assert.equal(r.citationPage, 1);
});

test("EOL hyphenation is joined before matching", () => {
  const index = idx(["The laryn-\ngoscope blade is inserted."]);
  const r = verifyQuote("The laryngoscope blade is inserted.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
});

test("soft hyphens are stripped", () => {
  const index = idx(["Pre­oxygenation is essential."]);
  assert.equal(
    verifyQuote("Preoxygenation is essential.", { index, map, bookPage: 1 }).ok,
    true,
  );
});

// The two-column interleave / caption-injection / table-linearization rules
// are calibrated on REAL Miller scans during the pilot (Task 0 step 3), so
// their cases are data-driven from a committed fixture rather than guessed
// here. The fixture carries {pageText, quote, expectOk} triples the pilot
// recorded; it starts EMPTY (this test is skipped until the pilot populates
// it), so there is never a synthetic always-pass standing in for a real case.
test("pilot-cataloged layout cases verify as recorded", async () => {
  const cases = JSON.parse(
    await readFile(new URL("../fixtures/layout_cases.json", import.meta.url)),
  );
  if (cases.length === 0) return; // populated by Task 0 step 3; skip until then
  for (const c of cases) {
    const r = verifyQuote(c.quote, {
      index: idx([c.pageText]),
      map,
      bookPage: 1,
    });
    assert.equal(r.ok, c.expectOk, `layout case "${c.name}"`);
  }
});

test("a quote spanning a page break verifies via N||N+1 and cites a range", () => {
  const index = idx([
    "...ends at the end of page one ",
    "and continues on page two.",
  ]);
  const r = verifyQuote("end of page one and continues on page two.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, true);
  assert.equal(r.citationRange, "1-2");
});

test("a quote absent from the page fails with quote-verification-failed", () => {
  const index = idx(["Nothing relevant here."]);
  const r = verifyQuote("This sentence is not in the book.", {
    index,
    map,
    bookPage: 1,
  });
  assert.equal(r.ok, false);
  assert.equal(r.reason, "quote-verification-failed");
});
```

- [ ] **Step 2: Run to verify they fail, then implement `verifier.js`**

`normalize`: collapse all whitespace runs to single spaces, join EOL hyphenation (`-\n` -> ``), strip soft hyphens (`­`), plus the pilot-cataloged column-interleave + caption/footnote + table-linearization rules (Task 0 step 3 supplies the exact transforms - encode each as a documented step). `verifyQuote`: normalize both quote and `pageText(index, map.bookToPdf(bookPage))`; substring check; on miss, check against the normalized concat of page N and N+1 and set `citationRange` when it matches across the boundary; else fail. Name the ceiling:

```js
// ponytail: fixed normalization catalog calibrated on the pilot's real
// scans (amendment 5). pdftotext-plus-plus is the named fallback ONLY if
// layout-garble flags dominate the pilot - do not add it speculatively.
```

Human review spot-checks quotes against the RENDERED PAGE IMAGE (`pdftoppm`), not the text layer - the verifier alone only proves "substring of the extraction" (amendment 5). That spot-check is a review-process step, recorded in the pilot scorecard, not code here.

- [ ] **Step 3: Run to verify they pass; commit**

```bash
git add ingestion/generator/src/verifier.js ingestion/generator/test/verifier.test.js
git commit -m "feat(generator): quote verifier - normalization catalog + cross-page range citations (T3)"
```

---

### Task 6: Stage 2 classification + Stage 3 answer assembly + flag taxonomy (gated by Task 0)

**PRECONDITION: Task 0 scorecard exists with a GO decision (the ONLY open gate - license signed + `QUOTE_TERMS=no-cap` are both already resolved). At `--scale`, the `QUOTE_TERMS` marker is still checked as a safety interlock (amendment 12); set `QUOTE_TERMS=no-cap`.**

**Files:**

- Create: `ingestion/generator/src/classify.js`
- Create: `ingestion/generator/src/generate.js`
- Create: `ingestion/generator/src/flags.js`
- Create: `ingestion/generator/test/classify.test.js`, `ingestion/generator/test/generate.test.js`, `ingestion/generator/test/flags.test.js`

**Interfaces:**

- Consumes: page index/map (1,2), extraction (3), ledger (4), verifier (5); Miller chapter list (Task 7 seed); Anthropic SDK.
- Produces: `classify(question, chapters, {retrieve}) -> {chapterKey, confidence}` (primary Miller chapter; ambiguous cases run joint Stage 2+3 - primary = the chapter whose pages supply the verifier-passing passages); `generateAnswer(question, {index, map, chapterPages}) -> {sections, earns_marks, verbatimWordCount, flags}` (extractive, verifier-gated); `flag(reason, question)` writing the two-kind taxonomy to the flag queue.

- [ ] **Step 1: Model-call config uses the current SDK surface**

The classification/extraction calls use `@anthropic-ai/sdk`. Per the claude-api skill: default model `claude-opus-4-8`, adaptive thinking (`thinking: {type: "adaptive"}`), structured output via `output_config: {format: {...}}` for the `{chapterKey, confidence}` and section-extraction shapes, and `messages.parse()` for validated returns. Offline batch work MAY use the Batches API (50% cost, unordered - key by question id). No `budget_tokens`. Add `@anthropic-ai/sdk` to `ingestion/package.json` devDependencies (generator-only; never imported by build/validate/publish).

- [ ] **Step 2: Failing tests with a STUBBED model client**

Model calls are injected so tests are deterministic (no network). Example for classification:

```js
test("classify assigns the primary chapter the model returns", async () => {
  const fakeModel = {
    classify: async () => ({
      chapterKey: "airway-management",
      confidence: 0.94,
    }),
  };
  const r = await classify({ question_text: "difficult airway?" }, CHAPTERS, {
    model: fakeModel,
    retrieve: () => [],
  });
  assert.equal(r.chapterKey, "airway-management");
});

test("below-threshold confidence flags low-classification-confidence", async () => {
  const fakeModel = {
    classify: async () => ({ chapterKey: "x", confidence: 0.3 }),
  };
  const r = await classify({ question_text: "?" }, CHAPTERS, {
    model: fakeModel,
    retrieve: () => [],
    threshold: 0.6,
  });
  assert.equal(r.flag, "low-classification-confidence");
});
```

Example for answer assembly (the verifier is REAL, the model stubbed):

```js
test("an answer whose quote fails verification is flagged, not emitted", async () => {
  const index = [{ pdf_page: 1, text: "Only this real sentence exists." }];
  const fakeModel = {
    extract: async () => ({
      sections: [
        {
          key: "definition",
          heading: "Definition",
          body_md: "A fabricated sentence not in the book.",
        },
      ],
    }),
  };
  const r = await generateAnswer(
    { question_text: "?" },
    { index, map: { bookToPdf: (n) => n }, bookPage: 1, model: fakeModel },
  );
  assert.equal(r.sections, undefined);
  assert.equal(r.flags[0].reason, "quote-verification-failed");
});

test("a verifiable answer records its verbatim word count metadata (amendment 12)", async () => {
  const index = [
    { pdf_page: 1, text: "The carina is the point of tracheal bifurcation." },
  ];
  const fakeModel = {
    extract: async () => ({
      sections: [
        {
          key: "definition",
          heading: "Definition",
          body_md: "The carina is the point of tracheal bifurcation.",
        },
      ],
      earns_marks: [{ label: "Carina defined", section_key: "definition" }],
    }),
  };
  const r = await generateAnswer(
    { question_text: "?" },
    { index, map: { bookToPdf: (n) => n }, bookPage: 1, model: fakeModel },
  );
  assert.ok(r.sections.length === 1);
  assert.equal(r.verbatimWordCount, 8);
});
```

Flag taxonomy test:

```js
test("flag taxonomy: answer-blocking withholds the answer; figure-only publishes text", () => {
  assert.equal(flag("no-source-coverage").blocksAnswer, true);
  assert.equal(flag("quote-verification-failed").blocksAnswer, true);
  assert.equal(flag("low-classification-confidence").blocksAnswer, true);
  assert.equal(flag("figure-license-unclear").blocksAnswer, false); // text still publishes
});
```

- [ ] **Step 3: Run to verify they fail, then implement**

- `classify.js`: single model call returns `{chapterKey, confidence}` against the chapter list; below threshold -> `low-classification-confidence`; ambiguous (two near-tie candidates) -> run retrieval for the top candidates and set primary = the chapter whose pages supply the winning verifier-passing passage (joint Stage 2+3, design Stage 2). Thresholds come from Task 0.
- `generate.js`: retrieve candidate passages (keyword/section over the page index - lazy, no embedding index; TODOS 8 is the trigger-gated upgrade), model does EXTRACTIVE assembly into `sections[]` per D16 anatomy, EVERY `body_md` passes `verifyQuote` or the whole answer is flagged `quote-verification-failed`; build `earns_marks[]` pointing at section keys; record `verbatimWordCount` (amendment 12). At `--scale`, refuse to run unless the QUOTE_TERMS marker is present.
- `flags.js`: the two-kind taxonomy - answer-blocking (`no-source-coverage`, `quote-verification-failed`, `low-classification-confidence`) writes to the flag queue and emits NO answer; figure-only (`figure-license-unclear`) records the flag but the text answer publishes.

- [ ] **Step 4: Run to verify they pass; commit**

```bash
git add ingestion/generator/src/classify.js ingestion/generator/src/generate.js ingestion/generator/src/flags.js ingestion/generator/test ingestion/package.json ingestion/package-lock.json
git commit -m "feat(generator): Stage 2 classify + Stage 3 verifier-gated extractive answers + flag taxonomy"
```

---

### Task 7: Stage 0 chapter seed - TOC parse + slug hygiene (T7)

**Files:**

- Create: `ingestion/generator/src/chapters_seed.js`
- Create: `ingestion/generator/test/chapters_seed.test.js`

**Interfaces:**

- Consumes: page index of the Miller TOC (Task 1).
- Produces: `parseToc(tocText) -> [{title, sort_order, book_page_start}]`; `slugify(title) -> slug` (SLUG_RE-valid); `dedupeSlugs(chapters) -> chapters` (deterministic `-2` suffix); `precheckUnique(slugs) -> string[]` (collisions against `UNIQUE(speciality_id, slug)` BEFORE any chapter.json emits). Classification (Task 6) buckets into these chapters; only populated chapters ever emit.

- [ ] **Step 1: Failing tests - slug hygiene (amendment 11 / C3)**

```js
test("slugify produces SLUG_RE-valid slugs from messy titles", () => {
  assert.equal(
    slugify("1. The Scope of Modern Anesthetic Practice"),
    "the-scope-of-modern-anesthetic-practice",
  );
  assert.equal(
    slugify("Pharmacology of Local Anaesthetics (Part II)"),
    "pharmacology-of-local-anaesthetics-part-ii",
  );
  assert.match(
    slugify("Cardiovascular Physiology & Anaesthesia"),
    /^[a-z0-9]+(-[a-z0-9]+)*$/,
  );
});

test("two titles slugifying identically get a deterministic -2 suffix", () => {
  const out = dedupeSlugs([
    { title: "Airway Management", slug: "airway-management" },
    { title: "Airway Management", slug: "airway-management" },
  ]);
  assert.deepEqual(
    out.map((c) => c.slug),
    ["airway-management", "airway-management-2"],
  );
});

test("precheck catches a collision before emit (not at publish)", () => {
  assert.deepEqual(precheckUnique(["a", "b", "a"]), ["a"]);
});

test("parseToc reads title + book page from TOC lines", () => {
  const toc =
    "1. The Scope of Modern Anesthetic Practice ..... 3\n19. Pulmonary Pharmacology ..... 512";
  const rows = parseToc(toc);
  assert.equal(rows[0].title, "The Scope of Modern Anesthetic Practice");
  assert.equal(rows[0].sort_order, 1);
  assert.equal(rows[0].book_page_start, 3);
});
```

- [ ] **Step 2: Run to verify they fail, then implement**

`parseToc`: line regex capturing `<n>. <title> ... <page>` (the design confirmed these lines parse cleanly); `slugify`: lowercase, strip a leading `N.`, replace non-alnum runs with a single hyphen, trim hyphens; `dedupeSlugs`: stable pass appending `-2`, `-3` on repeat; `precheckUnique`: return the list of slugs that appear more than once. All ~150 titles pre-checked before any emit (collisions must not wait for publish - C3). Count-vs-150 and per-volume monotonic page assertions (Task 2) are the loud Stage 0 failures.

- [ ] **Step 3: Run to verify they pass; commit**

```bash
git add ingestion/generator/src/chapters_seed.js ingestion/generator/test/chapters_seed.test.js
git commit -m "feat(generator): Stage 0 TOC parse + slug sanitize/dedupe/precheck (T7)"
```

---

### Task 8: figure extraction sub-task - render, crop, feed the resizer

**Files:**

- Create: `ingestion/generator/src/figures.js`
- Create: `ingestion/generator/test/figures.test.js`

**Interfaces:**

- Consumes: the cited page + a proposed crop box; the existing `processImage` from `ingestion/src/build.js` (REUSED - it already does WebP + quality ladder + 200KB cap).
- Produces: `renderPage(pdfPath, pdfPage, outPng) -> path` (via `pdftoppm`); `cropFigure(pngPath, bbox, outPng) -> path` (via `sharp` extract); the human-verified bbox is the input (design: model proposes, human verifies). The cropped PNG then feeds the UNCHANGED `processImage`.

- [ ] **Step 1: Failing test - render + crop on a synthetic page**

```js
test("cropFigure extracts the bbox region and processImage takes it to WebP <=200KB", async () => {
  // synthetic 1000x1400 png fixture (owned, not Miller)
  const cropped = await cropFigure(
    SAMPLE_PNG,
    { left: 100, top: 200, width: 400, height: 300 },
    tmpOut,
  );
  const meta = await sharp(cropped).metadata();
  assert.equal(meta.width, 400);
  const webp = await processImage(cropped); // reused from ../../src/build.js
  assert.ok(webp.length <= 204800);
});
```

- [ ] **Step 2: Run to verify it fails, then implement**

`figures.js`: `renderPage` shells `pdftoppm -png -f <page> -l <page> -r <dpi>`; `cropFigure` uses `sharp(png).extract({left, top, width, height})`. Import `processImage` from `../../src/build.js` - do NOT reimplement the quality ladder. Caption + `content_description` (TalkBack) + page citation are authored per figure (design Stage 3). The batch-review UI is trigger-gated (TODOS 9) - this task emits the page PNG + bbox JSON that a future UI would consume, but the pilot uses hand-verified boxes.

```js
// ponytail: hand-verified crop boxes (pilot). The page-PNG + bbox JSON this
// emits IS the exact input the trigger-gated batch UI (TODOS 9) would take -
// build the UI only if the pilot's figure-review time projection demands it.
```

- [ ] **Step 3: Run to verify it passes; commit**

```bash
git add ingestion/generator/src/figures.js ingestion/generator/test/figures.test.js
git commit -m "feat(generator): figure render+crop feeding the reused build.js resizer"
```

---

### Task 9: Stage 2 classification EVAL vs pilot ground truth (T10 EVAL)

**Files:**

- Create: `ingestion/generator/test/classify_eval.test.js`
- Create: `ingestion/generator/fixtures/pilot_ground_truth.json` (the pilot chapter's hand-labeled question->chapter map, NO Miller answer text - just question text + expected chapter key)

**Interfaces:**

- Consumes: `classify` (Task 6), the pilot's hand-labeled ground truth (Task 0).
- Produces: a reported classification accuracy + threshold-flag precision number, gating the scale run.

- [ ] **Step 1: Write the EVAL**

The EVAL runs `classify` over the pilot chapter's ~10-20 hand-labeled questions and reports accuracy + how often the confidence threshold correctly flags vs wrongly flags. It is a REPORTING test (prints the numbers; asserts a floor the pilot sets, e.g. accuracy >= the go/no-go bar from scorecard.md). It may call the real model (guarded by `ANTHROPIC_API_KEY` presence, skipped otherwise) or a recorded-response fixture:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { classify } from "../src/classify.js";

const skip =
  !process.env.ANTHROPIC_API_KEY &&
  "set ANTHROPIC_API_KEY to run the classification EVAL";

test(
  "Stage 2 classification meets the pilot accuracy bar",
  { skip },
  async () => {
    const truth = JSON.parse(
      await readFile(
        new URL("../fixtures/pilot_ground_truth.json", import.meta.url),
      ),
    );
    let correct = 0;
    for (const item of truth.questions) {
      const r = await classify(
        { question_text: item.question_text },
        truth.chapters,
        {},
      );
      if (r.chapterKey === item.expected_chapter_key) correct++;
    }
    const accuracy = correct / truth.questions.length;
    console.log(
      `Stage 2 classification accuracy: ${(accuracy * 100).toFixed(1)}%`,
    );
    assert.ok(
      accuracy >= truth.accuracy_floor,
      `accuracy ${accuracy} below pilot floor ${truth.accuracy_floor}`,
    );
  },
);
```

- [ ] **Step 2: Run it (or confirm it skips cleanly without a key); commit**

Run: `node --test generator/test/classify_eval.test.js`
Expected: SKIP without a key, or reports accuracy and passes the floor with one.

```bash
git add ingestion/generator/test/classify_eval.test.js ingestion/generator/fixtures/pilot_ground_truth.json
git commit -m "test(generator): Stage 2 classification EVAL vs pilot ground truth (T10 EVAL)"
```

---

### Task 10: at-scale orchestration + publish-pipeline dry run (T10 E2E) - FINAL GATE

**PRECONDITION: Task 0 GO (the only open gate - license SIGNED and `QUOTE_TERMS=no-cap` are both resolved as of 2026-07-06). This is the last task; do not start the at-scale run until the pilot reads GO.**

**Files:**

- Create: `ingestion/generator/src/run.js` (the Stage 0-4 orchestrator CLI)
- Create: `ingestion/generator/test/dry_run.test.js` (E2E: generated chapter.json -> build -> validate -> publish scratch DB -> serve-shape parse)

**Interfaces:**

- Consumes: every stage (Tasks 1-8); lane B's `buildChapter`/`validateCanonical`/`publishChapter`.
- Produces: `run.js` orchestrating extraction -> reconciliation -> classification -> answer generation -> holding-area chapter.json emission, with `--scale` gating on QUOTE_TERMS; the dry-run E2E proving the whole pipeline end to end on a SYNTHETIC (owned, non-Miller) chapter.

- [ ] **Step 1: Write the publish-pipeline dry-run E2E**

Using an owned synthetic chapter (NO Miller text - so it can run in CI and even publish to a scratch DB with `LICENSE_SIGNED=true` set in the test's own env, exercising the gate without weakening it):

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { buildChapter } from "../../src/build.js";
import { validateCanonical } from "../../src/validate.js";
import { publishChapter } from "../../src/publish.js";
import { testClient } from "../../test/db.js";

const skipDb =
  !process.env.DATABASE_URL && "set DATABASE_URL for the publish dry run";

test(
  "generated authoring chapter -> build -> validate -> publish -> serve shape",
  { skip: skipDb },
  async () => {
    // 1. an owned synthetic authoring chapter in v2 shape (stands in for a
    //    generator-emitted holding artifact; carries NO licensed text).
    const src = await mkdtemp(path.join(tmpdir(), "gen-src-"));
    await mkdir(path.join(src, "images"), { recursive: true });
    await writeFile(
      path.join(src, "chapter.json"),
      JSON.stringify(
        {
          speciality_slug: "anaesthesiology",
          chapter: {
            key: "dry-run",
            title: "Dry Run",
            slug: "dry-run",
            sort_order: 1,
            exam_weight: 3,
          },
          qnas: [
            {
              key: "dr-q1",
              question: "Owned synthetic question?",
              years: "2019, 2022",
              marks: 10,
              sort_order: 1,
              earns_marks: [{ label: "Point", section_key: "definition" }],
              sections: [
                {
                  key: "definition",
                  heading: "Definition",
                  body_md: "Owned synthetic answer text.",
                },
              ],
              images: [],
            },
          ],
        },
        null,
        2,
      ),
    );

    // 2. build (mints ULIDs), 3. validate (v2), 4. publish (gate satisfied in-env).
    const out = await mkdtemp(path.join(tmpdir(), "gen-out-"));
    const lock = path.join(
      await mkdtemp(path.join(tmpdir(), "gen-lock-")),
      "ids.lock",
    );
    const built = await buildChapter(src, out, lock);
    assert.equal(built.schema_version, 2);
    assert.deepEqual(await validateCanonical(out), []);

    const client = await testClient();
    try {
      const { chapterId } = await publishChapter(client, out);
      // 5. serve-shape parse: the row is readable at chapter grain, no topics.
      const rows = await client.query(
        `SELECT chapter_id FROM qnas WHERE chapter_id = $1`,
        [chapterId],
      );
      assert.equal(rows.rows[0].chapter_id, chapterId);
    } finally {
      await client.end();
    }
  },
);
```

- [ ] **Step 2: Implement `run.js` orchestration**

`run.js` wires the stages: for each paper -> `extractQuestions` (OCR gate) -> `reconcile` against the committed ledger -> per question `classify` -> `generateAnswer` (verifier-gated) -> group verifier-passing answers by chapter -> compute `examWeight` -> emit ONLY populated chapters as authoring `chapter.json` into `ingestion/holding/<chapter-slug>/`. Flags go to `ingestion/holding/flag-queue.jsonl`. `--scale` refuses without the QUOTE_TERMS marker (amendment 12). It NEVER publishes - a human runs `build -> validate -> publish` on the holding artifacts after the license is signed. Keep the orchestrator thin:

```js
// ponytail: thin orchestrator - each stage is its own tested module. run.js
// only wires them + writes holding artifacts. No stage logic lives here.
```

- [ ] **Step 3: Run the dry-run E2E; commit**

Run: `DATABASE_URL=<disposable> node --test generator/test/dry_run.test.js`
Expected: PASS (build v2, validate clean, publish to scratch DB, chapter-grain read back). Skips cleanly without a DB.

```bash
git add ingestion/generator/src/run.js ingestion/generator/test/dry_run.test.js
git commit -m "feat(generator): at-scale orchestrator + publish-pipeline dry-run E2E (T10)"
```

- [ ] **Step 4: The at-scale run itself (human-operated, gated)**

License signed and `QUOTE_TERMS=no-cap` are both cleared (2026-07-06); once Task 0 reads GO: run `QUOTE_TERMS=no-cap node generator/src/run.js --scale` over all 86 papers; review the flag queue + drafts; then `LICENSE_SIGNED=true node src/publish.js ingestion/holding/<chapter> ... --allow-publish` per reviewed chapter. This is operational, not a code step - the plan's code deliverables end at Task 10 Step 3.

---

## Self-review checklist (run before declaring the lane done)

- Task 0 scorecard exists and reads GO before any Task 6/Task 10 answer generation ran.
- The verifier's normalization catalog matches the pilot's real cataloged cases (Task 0 step 3), not synthetic guesses.
- `reconcile` re-keys NOTHING on a text edit (provenance-first test green); mints only on true no-match.
- `exam_weight` sums year-appearances (6-appearance question contributes 6).
- Every generator artifact with Miller text lands ONLY in `ingestion/holding/` (gitignored); `ids.lock` + ledger are committed and publisher-text-free.
- `--scale` refuses without QUOTE_TERMS; per-answer verbatim word count is recorded regardless.
- The dry-run E2E publishes through the UNWEAKENED gate (`LICENSE_SIGNED=true` set in the test's own env is exercising it, not bypassing it).
- No new runtime dependency: `@anthropic-ai/sdk` and poppler/tesseract are generator-only; build/validate/publish import none of them.
