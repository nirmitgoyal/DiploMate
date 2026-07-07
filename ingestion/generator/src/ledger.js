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

// Provenance-first reconciliation (amendment 2). `ledger` is accepted for
// interface parity with Task 10's future orchestrator wiring against the
// committed ids.lock; these self-contained tests drive everything off
// prevArtifacts, which already carries key + provenance + text, so ledger
// is not consulted here.
export function reconcile(extracted, ledger, prevArtifacts) {
  const matched = [];
  const minted = [];
  const ambiguous = [];

  for (const q of extracted) {
    const norm = normalizeQuestion(q.text);

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
        matched.push({ ...q, key: sameSlot.key });
      } else {
        ambiguous.push({ ...q, candidateKey: sameSlot.key, similarity: sim });
      }
      continue;
    }

    // 2. No provenance hit at this slot: the same question may still exist
    // under a different (paper, year, position) - e.g. repeated in a later
    // exam. Best normalized-text match above the threshold -> reuse its key.
    let best = null;
    for (const p of prevArtifacts) {
      const sim = textSimilarity(norm, normalizeQuestion(p.text));
      if (sim >= SIMILARITY_THRESHOLD && (!best || sim > best.sim)) {
        best = { key: p.key, sim };
      }
    }
    if (best) {
      matched.push({ ...q, key: best.key });
      continue;
    }

    // 3. No match anywhere: genuinely new question - mint a fresh key.
    minted.push({ ...q, key: questionKey(q.text) });
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
