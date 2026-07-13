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

// Group per-question chapter titles into a compact set of real chapters, in two
// phases so it scales to hundreds of titles without truncating:
//   1. buildTaxonomy(allTitles) -> string[]  ONE global pass. It sees every
//      title at once (the input fits Haiku's context; the OUTPUT is just the
//      ~40 chapter names, so it never truncates the way a full per-title map
//      of hundreds of entries would).
//   2. classify(batch, taxonomy) -> { title: chapter }  output-bounded batches
//      that assign each title to the closest taxonomy chapter.
// A title the model fails to place (not a real taxonomy name, or a null batch
// result) keeps its own title, so a chapter is never dropped. If phase 1 yields
// nothing, every title maps to itself - the same non-destructive fallback.
export async function canonicalizeChapters(
  rawTitles,
  { buildTaxonomy, classify, batchSize = 40 },
) {
  const uniq = [...new Set(rawTitles)];
  if (uniq.length <= 1) return new Map(uniq.map((t) => [t, t]));

  const taxonomy = await buildTaxonomy(uniq);
  if (!taxonomy || taxonomy.length === 0) {
    return new Map(uniq.map((t) => [t, t]));
  }
  const allowed = new Set(taxonomy);

  const map = new Map();
  for (let i = 0; i < uniq.length; i += batchSize) {
    const batch = uniq.slice(i, i + batchSize);
    const assigned = (await classify(batch, taxonomy)) || {};
    for (const t of batch) {
      const c = assigned[t];
      map.set(t, allowed.has(c) ? c : t); // a real taxonomy chapter, else keep own
    }
  }
  return map;
}
