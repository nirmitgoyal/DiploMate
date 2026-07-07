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
  return title
    .replace(LEADING_NUMBER_RE, "")
    .toLowerCase()
    .replace(NON_ALNUM_RUN_RE, "-")
    .replace(/^-+|-+$/g, "");
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
  const seen = new Map();
  return chapters.map((c) => {
    const count = (seen.get(c.slug) ?? 0) + 1;
    seen.set(c.slug, count);
    return count === 1 ? c : { ...c, slug: `${c.slug}-${count}` };
  });
}

export function precheckUnique(slugs) {
  const counts = new Map();
  for (const s of slugs) counts.set(s, (counts.get(s) ?? 0) + 1);
  return [...counts.keys()].filter((s) => counts.get(s) > 1);
}
