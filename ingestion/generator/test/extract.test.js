import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import {
  probeTextLayer,
  extractQuestions,
  splitQuestionBlocks,
} from "../src/extract.js";

// Mirrors fixtures/make-paper.js's SAMPLE_QUESTIONS. Not imported from
// there directly - that module's top level regenerates both PDFs (shells
// to pdftoppm/magick) as a side effect of import, which would make every
// test run re-run fixture generation. Fixtures are committed and static;
// only re-run `node fixtures/make-paper.js` by hand to regenerate them.
const SAMPLE_QUESTIONS = [
  "Describe the pharmacology of local anaesthetics.",
  "Discuss the management of a difficult airway in a trauma patient.",
  "Write short notes on spinal anaesthesia.",
];

const TEXT_PDF = fileURLToPath(
  new URL("../fixtures/sample-paper.pdf", import.meta.url),
);
const SCAN_PDF = fileURLToPath(
  new URL("../fixtures/scan-paper.pdf", import.meta.url),
);

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

test("extraction splits all numbered questions and parses their marks", async () => {
  const { questions, qa } = await extractQuestions(TEXT_PDF, { ocr: false });
  assert.equal(questions.length, SAMPLE_QUESTIONS.length);
  assert.deepEqual(
    questions.map((q) => q.question_text),
    SAMPLE_QUESTIONS,
  );
  assert.deepEqual(
    questions.map((q) => q.marks),
    [10, 10, 5],
  );
  assert.deepEqual(
    questions.map((q) => q.position),
    [1, 2, 3],
    "position is the printed item number, not the array index",
  );
  assert.equal(qa.count, SAMPLE_QUESTIONS.length);
});

// The PDF test above numbers 1,2,3 consecutively, so printed-number and
// array-index+1 give the same answer and cannot tell the two apart. This
// feeds owned synthetic text whose printed numbers SKIP (2, 5, 6): position
// must equal the printed number, so [2,5,6]. Were position the array index
// it would read [1,2,3] and every assertion here would fail - the guard
// against a future regression to `i + 1`.
test("position is the printed item number even when the printed numbers skip", () => {
  const blocks = splitQuestionBlocks(
    "2. First stem, printed two.\n" +
      "5. Second stem, printed five.\n" +
      "6. Third stem, printed six.",
  );
  assert.deepEqual(
    blocks.map((b) => b.position),
    [2, 5, 6],
    "printed numbers, not array indices [1,2,3]",
  );
});

test("year and paper are stamped from the first-page header", async () => {
  const { questions } = await extractQuestions(TEXT_PDF, { ocr: false });
  for (const q of questions) {
    assert.equal(q.year, 2021);
    assert.equal(q.paper, "I");
  }
});

test("an expected count mismatch is flagged loudly, not silently dropped", async () => {
  const { qa } = await extractQuestions(TEXT_PDF, {
    ocr: false,
    expectedCount: 99,
  });
  assert.equal(qa.flagged, true);
  assert.ok(qa.reasons.some((r) => /count-mismatch/.test(r)));
});

// Gated: exercises the real tesseract OCR path end to end. Skipped by
// default so `npm test` stays fast (multi-second OCR invocation); run with
// RUN_OCR_TEST=1 node --test generator/test/extract.test.js to check it.
const skipOcr =
  !process.env.RUN_OCR_TEST &&
  "set RUN_OCR_TEST=1 to run the tesseract OCR smoke test (slow)";

test(
  "a scanned paper routes through tesseract and recovers the known questions",
  { skip: skipOcr },
  async () => {
    const { questions, qa } = await extractQuestions(SCAN_PDF, { ocr: true });
    assert.equal(questions.length, SAMPLE_QUESTIONS.length);
    assert.match(questions[0].question_text, /pharmacology/i);
    assert.ok(qa.garbleScore < 0.3, "ocr noise stays well under the floor");
  },
);
