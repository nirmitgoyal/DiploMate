// Stage 0: turn the Miller TOC page text into a chapter list, and make sure
// every slug is valid and unique BEFORE any chapter.json is emitted -
// collisions must be caught here, not at publish's UNIQUE(speciality_id,
// slug) constraint (sql/0001_content_v0.sql; C3).
//
// SLUG_RE duplicated from ingestion/src/validate.js:10 (source of truth) -
// not imported, since that module also pulls in sharp/pg for chapter.json
// validation and this file only needs the one regex shape.
// const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const LEADING_NUMBER_RE = /^\d+\.\s*/;
const NON_ALNUM_RUN_RE = /[^a-z0-9]+/g;
const TOC_LINE_RE = /^(\d+)\.\s+(.+?)\s*\.{2,}\s*(\d+)\s*$/;

export function slugify(title) {
  const slug = title
    .replace(LEADING_NUMBER_RE, "")
    .toLowerCase()
    .replace(NON_ALNUM_RUN_RE, "-")
    .replace(/^-+|-+$/g, "");
  // A punctuation-only or bare-"N." title collapses to "" (SLUG_RE needs >=1
  // leading alnum). dedupe/precheck compare equality, not format, so an empty
  // slug would emit unnoticed - fail loud here like the count/monotonic gates.
  if (slug === "")
    throw new Error(
      `slugify: title ${JSON.stringify(title)} has no slug-able characters`,
    );
  return slug;
}

export function parseToc(tocText) {
  return tocText
    .split("\n")
    .map((line) => line.match(TOC_LINE_RE))
    .filter(Boolean)
    .map((m) => ({
      title: m[2],
      sort_order: Number(m[1]),
      book_page_start: Number(m[3]),
    }));
}

export function dedupeSlugs(chapters) {
  // Track EVERY assigned output slug (originals + generated), not just a
  // per-base count: a generated "x-2" must also skip a pre-existing literal
  // "x-2", or the deduper itself emits a collision.
  const assigned = new Set();
  return chapters.map((c) => {
    let candidate = c.slug;
    let n = 1;
    while (assigned.has(candidate)) {
      n++;
      candidate = `${c.slug}-${n}`;
    }
    assigned.add(candidate);
    return candidate === c.slug ? c : { ...c, slug: candidate };
  });
}

export function precheckUnique(slugs) {
  const counts = new Map();
  for (const s of slugs) counts.set(s, (counts.get(s) ?? 0) + 1);
  return [...counts.keys()].filter((s) => counts.get(s) > 1);
}
