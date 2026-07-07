import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, mkdir, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { buildPageIndex } from "./page_index.js";

const exec = promisify(execFile);

// Below this fraction of pages carrying real text, treat the paper as a
// scan rather than a text PDF.
const TEXT_COVERAGE_FLOOR = 0.5;
// Matches the brief's "clean text has low garble" bar.
const GARBLE_FLOOR = 0.2;

export async function probeTextLayer(pdfPath) {
  const index = await buildPageIndex(pdfPath);
  const withText = index.filter(
    (p) => p.text.replace(/\s/g, "").length > 0,
  ).length;
  const coverage = index.length ? withText / index.length : 0;
  return { hasText: coverage >= TEXT_COVERAGE_FLOOR, coverage };
}

// ponytail: numbered-item split + marks-suffix heuristic; per-paper QA
// (count vs expected, garble score, human skim) is the gate. Upgrade the
// splitter only for papers the QA report flags.
export async function extractQuestions(
  pdfPath,
  { ocr = true, expectedCount } = {},
) {
  const probe = await probeTextLayer(pdfPath);
  let index;
  if (probe.hasText) {
    index = await buildPageIndex(pdfPath);
  } else if (ocr) {
    const textIndex = await buildPageIndex(pdfPath); // page count only
    index = await ocrPageIndex(pdfPath, textIndex.length);
  } else {
    index = await buildPageIndex(pdfPath); // near-empty; QA gate flags it
  }

  const fullText = index.map((p) => p.text).join("\n");
  const { year, paper } = stampProvenance(pdfPath, index[0]?.text ?? "");
  const questions = splitQuestionBlocks(fullText).map(
    ({ text, marks, position }) => ({
      question_text: text,
      year,
      paper,
      position,
      ...(marks === undefined ? {} : { marks }),
    }),
  );

  return { questions, qa: buildQaReport(questions, fullText, expectedCount) };
}

function buildQaReport(questions, fullText, expectedCount) {
  const garble = garbleScore(fullText);
  const reasons = [];
  if (questions.length === 0) reasons.push("zero-questions-extracted");
  if (expectedCount !== undefined && questions.length !== expectedCount) {
    reasons.push(
      `count-mismatch: extracted ${questions.length}, expected ${expectedCount}`,
    );
  }
  if (garble >= GARBLE_FLOOR) reasons.push("high-garble-score");

  return {
    count: questions.length,
    garbleScore: garble,
    expectedCount,
    flagged: reasons.length > 0,
    reasons,
    questions, // human skim list - the QA gate is loud, never silent
  };
}

const QUESTION_START_RE = /^\s*(\d{1,2})\.\s+/gm;
const MARKS_SUFFIX_RE = /\(\s*(\d+)\s*marks?\s*\)\s*$/i;

// Exported for the discriminating position test: printed number vs array
// index only diverge when the printed numbers skip, and the committed
// sample PDF numbers 1,2,3 consecutively, so the split is exercised on a
// hand-written gapped text input rather than a second binary fixture.
export function splitQuestionBlocks(text) {
  const starts = [...text.matchAll(QUESTION_START_RE)];
  const blocks = [];
  for (let i = 0; i < starts.length; i++) {
    const start = starts[i].index + starts[i][0].length;
    const end = i + 1 < starts.length ? starts[i + 1].index : text.length;
    let body = text.slice(start, end).trim();
    // Printed item number, not the loop index i - stable across extraction
    // drift (a question printed "3." stays position 3 even if question 2
    // is dropped from a later re-run), which the ledger's provenance match
    // (paper, year, position) depends on.
    const position = Number(starts[i][1]);

    const marksMatch = body.match(MARKS_SUFFIX_RE);
    let marks;
    if (marksMatch) {
      marks = Number(marksMatch[1]);
      body = body.slice(0, marksMatch.index).trim();
    }
    if (body) blocks.push({ text: body, marks, position });
  }
  return blocks;
}

// Year/paper stamp: prefer a header line on the first page (real papers
// carry one), fall back to the filename. Neither found -> null, not a
// guess - the QA skim is where a human catches an unstamped paper.
const PROVENANCE_RE = /(\d{4})[^\n\d]{0,10}paper[^\n\d]{0,5}([ivxlcdm\d]+)/i;

function stampProvenance(pdfPath, firstPageText) {
  const match =
    firstPageText.match(PROVENANCE_RE) ??
    path.basename(pdfPath, path.extname(pdfPath)).match(PROVENANCE_RE);
  return match
    ? { year: Number(match[1]), paper: match[2].toUpperCase() }
    : { year: null, paper: null };
}

// ponytail: garble score is a token-shape heuristic (letters-only or a bare
// number counts as "good"), not a real dictionary lookup - no word-list
// dependency for a generator script. Combined with the ratio of
// non-printable-ASCII characters (whichever is worse wins), so a handful of
// control-character garbage on otherwise clean text still trips the gate.
// Upgrade to a real dictionary only if the pilot shows this heuristic
// passes genuinely garbled OCR output.
function garbleScore(text) {
  const badChars = (text.match(/[^\x09\x0A\x0D\x20-\x7E]/g) ?? []).length;
  const badCharRatio = badChars / (text.length || 1);

  const tokens = text.split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return badCharRatio;
  const badTokens = tokens.filter((t) => !looksLikeAWord(t)).length;

  return Math.max(badCharRatio, badTokens / tokens.length);
}

function looksLikeAWord(token) {
  const stripped = token.replace(/[.,;:()'"?!]/g, "");
  return (
    stripped === "" ||
    /^[A-Za-z][A-Za-z'-]*$/.test(stripped) ||
    /^\d+$/.test(stripped)
  );
}

// OCR fallback for scanned papers: render each page to a PNG (pdftoppm)
// then run tesseract on it, producing the same [{pdf_page, text}] shape as
// buildPageIndex so the splitter above works unchanged on either source.
async function ocrPageIndex(pdfPath, pageCount) {
  const base = await mkdtemp(path.join(tmpdir(), "diplomate-ocr-"));
  try {
    const pages = [];
    for (let page = 1; page <= pageCount; page++) {
      const pageDir = path.join(base, String(page));
      await mkdir(pageDir);
      await exec("pdftoppm", [
        "-png",
        "-r",
        "200",
        "-f",
        String(page),
        "-l",
        String(page),
        pdfPath,
        path.join(pageDir, "p"),
      ]);
      const [png] = await readdir(pageDir);
      const { stdout } = await exec("tesseract", [
        path.join(pageDir, png),
        "stdout",
      ]);
      pages.push({ pdf_page: page, text: stdout });
    }
    return pages;
  } finally {
    await rm(base, { recursive: true, force: true });
  }
}
