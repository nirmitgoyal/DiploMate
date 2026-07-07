import { createHash } from "node:crypto";

// Strips a trailing "(N marks)" annotation before generic punctuation
// stripping runs - otherwise the parens are gone and "10 marks" reads as
// ordinary question text. Same shape as extract.js's MARKS_SUFFIX_RE, kept
// independent here since ledger/prevArtifacts text can predate Task 3's
// splitter and may still carry the suffix.
const MARKS_SUFFIX_RE = /\(\s*\d+\s*marks?\s*\)\s*$/i;

export function normalizeQuestion(text) {
  return text
    .toLowerCase()
    .replace(MARKS_SUFFIX_RE, "")
    .replace(/[^\w\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function questionKey(text) {
  return createHash("sha256")
    .update(normalizeQuestion(text))
    .digest("hex")
    .slice(0, 16);
}

// ponytail: O(len_a * len_b) Levenshtein - question text tops out at a few
// hundred characters and reconcile() runs offline per generator pass, so
// the DP table is cheap. Upgrade to a faster/approximate algorithm only if
// an at-scale run against a large prevArtifacts list measurably drags.
function levenshteinDistance(a, b) {
  const rows = a.length + 1;
  const cols = b.length + 1;
  const dp = Array.from({ length: rows }, () => new Array(cols).fill(0));
  for (let i = 0; i < rows; i++) dp[i][0] = i;
  for (let j = 0; j < cols; j++) dp[0][j] = j;
  for (let i = 1; i < rows; i++) {
    for (let j = 1; j < cols; j++) {
      dp[i][j] =
        a[i - 1] === b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + Math.min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[rows - 1][cols - 1];
}

// 1 = identical normalized text, 0 = nothing in common.
function textSimilarity(a, b) {
  if (a === b) return 1;
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  return 1 - levenshteinDistance(a, b) / maxLen;
}

// Measured against the brief's own two same-provenance fixtures (both
// normalized via normalizeQuestion above):
//   "Define spinal anaesthesia." vs "Define spinal anaesthesia" (period
//   dropped) -> normalize to the SAME string -> similarity 1.0.
//   "Define spinal anaesthesia." vs "Describe the anatomy of the brachial
//   plexus in full." (same slot, unrelated question) -> similarity 0.25.
// 0.7 sits well clear of both: comfortable headroom above 0.25 for a
// genuinely different question, and comfortable headroom below 1.0 for a
// multi-character OCR fix on a longer question.
const SIMILARITY_THRESHOLD = 0.7;

// Cross-slot reuse bar (no (paper,year,position) corroboration - text is
// the ONLY signal). Measured against real DNB-shaped stems, all normalized:
//   "Define spinal..." vs "Define epidural..."          -> 0.85
//   "Define spinal..." vs "Define local..."             -> 0.84
//   "...complications of spinal" vs "...of epidural"     -> 0.92
//   verbatim reappearance (identical normalized text)    -> 1.00
//   a single-character OCR slip on a full-length stem    -> 0.96
// The one content word that differs ("spinal"/"epidural") IS the question
// but barely moves Levenshtein on a long shared template, so any bar that
// admits those templated pairs re-keys distinct questions. 0.95 sits above
// every false-merge (max 0.92) and below a genuine verbatim repeat (>=0.96),
// so cross-slot auto-reuse means "essentially the same text in a later
// paper," never "same template." The 0.7-0.95 middle band is human review.
const NEAR_IDENTICAL = 0.95;

// Provenance-first reconciliation (amendment 2). `ledger` is accepted for
// interface parity with Task 10's future orchestrator wiring against the
// committed ids.lock; these self-contained tests drive everything off
// prevArtifacts, which already carries key + provenance + text, so ledger
// is not consulted here.
export function reconcile(extracted, ledger, prevArtifacts) {
  const matched = [];
  const minted = [];
  const ambiguous = [];
  // Keys already reused in THIS call. Consulted by the cross-slot branch
  // below only (text is the sole signal there, so a key already spent this
  // call cannot be spent again). The same-slot branch below adds to this
  // Set too but never consults it - two extracted items landing on the
  // identical (paper, year, position) triple would collide there, but that
  // indicates an upstream extraction bug, not a case this Set needs to
  // catch: provenance already scopes each slot to one question.
  const claimed = new Set();

  for (const q of extracted) {
    // extracted items come from extract.js, which emits `question_text`;
    // prevArtifacts (below) come from ledger storage, which uses `text` -
    // two different sources, two different shapes, both correct.
    const norm = normalizeQuestion(q.question_text);

    // 1. Exact provenance hit: a prior artifact already published at this
    // exact (paper, year, position) slot. High similarity -> the same
    // question, edited - reuse its key. Low similarity -> the slot holds a
    // genuinely different question now; a human decides, never auto-rekey.
    const sameSlot = prevArtifacts.find(
      (p) =>
        p.paper === q.paper && p.year === q.year && p.position === q.position,
    );
    if (sameSlot) {
      const sim = textSimilarity(norm, normalizeQuestion(sameSlot.text));
      if (sim >= SIMILARITY_THRESHOLD) {
        claimed.add(sameSlot.key);
        matched.push({ ...q, key: sameSlot.key });
      } else {
        ambiguous.push({ ...q, candidateKey: sameSlot.key, similarity: sim });
      }
      continue;
    }

    // 2. No provenance hit at this slot: the same question may still appear
    // under a different (paper, year, position) - a verbatim reappearance in
    // a later exam. Text is the ONLY signal here (no provenance to
    // corroborate), so the bar to auto-reuse is NEAR_IDENTICAL, not mere
    // template similarity. Best match by normalized text, then band it.
    let best = null;
    for (const p of prevArtifacts) {
      const sim = textSimilarity(norm, normalizeQuestion(p.text));
      if (!best || sim > best.sim) best = { key: p.key, sim };
    }
    if (best && best.sim >= NEAR_IDENTICAL && !claimed.has(best.key)) {
      // Essentially the same text in another paper -> genuine reappearance.
      claimed.add(best.key);
      matched.push({ ...q, key: best.key });
    } else if (best && best.sim >= SIMILARITY_THRESHOLD) {
      // Middle band (templated look-alike) OR a near-identical match whose
      // key was already claimed this call (many-to-one) - a human decides,
      // never auto-reuse over it, never auto-mint a duplicate under it.
      ambiguous.push({ ...q, candidateKey: best.key, similarity: best.sim });
    } else {
      // 3. No match anywhere (or below the review floor): genuinely new.
      minted.push({ ...q, key: questionKey(q.question_text) });
    }
  }

  return { matched, minted, ambiguous };
}

// Collapses one question's raw appearance years (possibly repeated, e.g.
// the same question in both papers of one year) into the unique, sorted,
// comma-joined string examWeight expects.
export function dedupYears(clusters) {
  const years = [...new Set(clusters.map((c) => c.year))].sort((a, b) => a - b);
  return years.join(", ");
}

// SUM of year-appearances across assigned questions, NOT deduped qna count
// (amendment 8) - a question deduped down to one qna still weighs by every
// distinct exam year it showed up in.
export function examWeight(assignedQuestions) {
  return assignedQuestions.reduce((sum, q) => {
    const count = q.years
      .split(",")
      .map((y) => y.trim())
      .filter(Boolean).length;
    return sum + count;
  }, 0);
}
