export function slugify(title) {
  return title
    .toLowerCase()
    .replace(/^\s*\d+\.\s*/, "") // strip a leading "N."
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^-+|-+$/g, "");
}

// Deterministic suffixing: every returned slug is unique across the whole
// list, including collisions between a natural slug and a generated -N suffix.
export function dedupeSlugs(items) {
  const used = new Set();
  return items.map((c) => {
    let slug = c.slug;
    if (used.has(slug)) {
      let n = 2;
      while (used.has(`${c.slug}-${n}`)) n++;
      slug = `${c.slug}-${n}`;
    }
    used.add(slug);
    return slug === c.slug ? c : { ...c, slug };
  });
}

// One model call merges synonym/near-duplicate titles into canonical names.
// callModel(uniqueTitles) -> { rawTitle: canonicalTitle }. On zero/one title,
// or a model miss for a title, it maps to itself (never drops a chapter).
export async function canonicalizeChapters(rawTitles, { callModel }) {
  const uniq = [...new Set(rawTitles)];
  if (uniq.length <= 1) return new Map(uniq.map((t) => [t, t]));
  const mapping = await callModel(uniq);
  return new Map(uniq.map((t) => [t, mapping?.[t] || t]));
}
