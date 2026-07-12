import { readdir } from "node:fs/promises";
import path from "node:path";
import { extractQuestions } from "../../generator/src/extract.js";
import { questionKey } from "../../generator/src/ledger.js";

// Recursively collect *.pdf under Qs/<slug>.
export async function listPapers(qsRoot, slug) {
  const out = [];
  async function walk(dir) {
    let entries;
    try {
      entries = await readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) await walk(full);
      else if (e.name.toLowerCase().endsWith(".pdf")) out.push(full);
    }
  }
  await walk(path.join(qsRoot, slug));
  return out.sort();
}

// Per speciality: extract every paper, collapse duplicate questions by
// questionKey, accumulate the years each question appeared.
export async function buildManifest(
  qsRoot,
  slugs,
  { extractImpl = extractQuestions } = {},
) {
  const bySlug = new Map();
  for (const slug of slugs) {
    const uniq = new Map();
    for (const pdf of await listPapers(qsRoot, slug)) {
      const { questions } = await extractImpl(pdf);
      for (const q of questions) {
        const key = questionKey(q.question_text);
        const rec = uniq.get(key) ?? {
          key,
          speciality_slug: slug,
          question: q.question_text,
          years: new Set(),
          marks: q.marks ?? null,
        };
        if (q.year) rec.years.add(q.year);
        uniq.set(key, rec);
      }
    }
    bySlug.set(
      slug,
      [...uniq.values()].map((r) => ({
        ...r,
        years: [...r.years].sort().join(", ") || null,
      })),
    );
  }
  return bySlug;
}
