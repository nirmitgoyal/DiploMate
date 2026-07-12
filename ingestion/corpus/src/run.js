import { parseArgs } from "node:util";
import pg from "pg";
import { buildManifest } from "./manifest.js";
import { SLUGS, QS_ROOT } from "./slugs.js";
import { createMeter, worstCaseCall } from "./meter.js";
import { generateAnswer } from "./bedrock.js";
import { canonicalizeChapters, slugify, dedupeSlugs } from "./canonicalize.js";
import { getSpecialityId, upsertChapter, insertQna } from "./publish.js";

const MAX_TOKENS = 2000;

// Title-case a slug for the model prompt: "neuro-anaesthesia" -> "Neuro Anaesthesia".
function nameFromSlug(slug) {
  return slug
    .split("-")
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(" ");
}

// Generate answers for a speciality's questions under the meter, canonicalize
// the proposed chapter titles, then publish. Returns counts. All external
// effects come through `deps` so the dry-run test needs no network or DB.
export async function processSpeciality(client, slug, rows, deps) {
  const {
    specialityName,
    getSpecialityId,
    generate,
    canonicalize,
    upsertChapter,
    insertQna,
    meter,
    concurrency = 8,
  } = deps;

  // ponytail: bounded overshoot - up to (concurrency-1) in-flight calls can each
  // pass this pre-check before their spend registers via meter.add(), so real
  // spend can exceed the ceiling by at most (concurrency-1)*worst (~$0.08 at
  // defaults 8 / 2000 / $5), absorbed by the ceiling-to-cap margin ($90 vs $100).
  // If MAX_TOKENS/rateOut/concurrency grow, switch to a reservation model
  // (reserve worst before dispatch, reconcile actual usage after).
  const worst = worstCaseCall(MAX_TOKENS, deps.rateOut ?? 5);
  const specialityId = await getSpecialityId(client, slug);
  const generated = [];
  let flagged = 0;
  let spendStopped = false;

  // Stage A: generate (bounded concurrency, meter-gated).
  if (meter.wouldExceed(worst)) spendStopped = true;
  const { mapPool } = await import("./pool.js");
  await mapPool(
    rows,
    concurrency,
    async (row) => {
      if (meter.wouldExceed(worst)) {
        spendStopped = true;
        return;
      }
      let result;
      try {
        result = await generate({
          speciality: specialityName,
          question: row.question,
          marks: row.marks,
        });
      } catch {
        // transport failure (429/5xx/network): flag this question and continue -
        // never abort the whole metered batch on one transient error.
        flagged++;
        return;
      }
      const { answer, usage } = result;
      meter.add(usage);
      if (!answer) {
        flagged++;
        return;
      }
      generated.push({ row, answer });
    },
    () => spendStopped || meter.wouldExceed(worst),
  );

  // Stage B: canonicalize the proposed chapter titles for this speciality.
  const rawTitles = generated.map((g) => g.answer.chapter_title);
  const canon = await canonicalize(rawTitles);
  const slugMap = dedupeSlugs(
    [...new Set([...canon.values()])].map((canonical) => ({
      canonical,
      slug: slugify(canonical),
    })),
  );
  const canonToSlug = new Map(slugMap.map((c) => [c.canonical, c.slug]));

  // Stage C: publish each generated answer under its canonical chapter.
  let published = 0;
  for (const { row, answer } of generated) {
    const canonical = canon.get(answer.chapter_title) || answer.chapter_title;
    const chapterId = await upsertChapter(
      client,
      specialityId,
      canonical,
      canonToSlug.get(canonical) || slugify(canonical),
    );
    await insertQna(client, {
      key: row.key,
      chapterId,
      question: row.question,
      years: row.years,
      marks: row.marks,
      earnsMarks: answer.earns_marks,
      sections: answer.sections,
    });
    published++;
  }

  return { published, flagged, spendStopped };
}

// ponytail: thin CLI. Each stage is its own tested module; main() only wires
// them + parses flags. Canary paths short-circuit before the full manifest.
export async function main(argv = process.argv.slice(2)) {
  const { values } = parseArgs({
    args: argv,
    options: {
      "canary-paper": { type: "string" },
      speciality: { type: "string", multiple: true },
      all: { type: "boolean" },
      ceiling: { type: "string" },
      concurrency: { type: "string" },
    },
  });

  const rateIn = Number(process.env.RATE_IN || 1);
  const rateOut = Number(process.env.RATE_OUT || 5);
  const ceiling = Number(values.ceiling || 90);
  const concurrency = Number(values.concurrency || 8);
  const meter = createMeter({
    rateIn,
    rateOut,
    ceiling,
    statePath: "spend.json",
  });
  await meter.load();

  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();

  const deps = {
    getSpecialityId,
    generate: (q) => generateAnswer(q, { maxTokens: MAX_TOKENS }),
    canonicalize: (titles) =>
      canonicalizeChapters(titles, { callModel: chapterMergeModel }),
    upsertChapter,
    insertQna,
    meter,
    concurrency,
    rateOut,
  };

  try {
    // Canary: one paper. Speciality is intentionally hardcoded to
    // anaesthesiology (the beachhead) for the canary run - not inferred.
    if (values["canary-paper"]) {
      const { extractQuestions } =
        await import("../../generator/src/extract.js");
      const { questionKey } = await import("../../generator/src/ledger.js");
      const { questions } = await extractQuestions(values["canary-paper"]);
      const rows = questions.map((q) => ({
        key: questionKey(q.question_text),
        speciality_slug: "canary",
        question: q.question_text,
        years: q.year ? String(q.year) : null,
        marks: q.marks ?? null,
      }));
      const r = await processSpeciality(client, "anaesthesiology", rows, {
        ...deps,
        specialityName: "Anaesthesiology",
      });
      console.log("canary:", r, "spend $" + meter.total().toFixed(4));
      return;
    }

    const slugs = values.all ? SLUGS : values.speciality || [];
    if (slugs.length === 0)
      throw new Error("pass --canary-paper, --speciality, or --all");
    const manifest = await buildManifest(QS_ROOT, slugs);
    for (const slug of slugs) {
      const rows = manifest.get(slug) || [];
      let r;
      try {
        r = await processSpeciality(client, slug, rows, {
          ...deps,
          specialityName: nameFromSlug(slug),
        });
      } finally {
        // persist on every exit path, including an unexpected throw, so a resumed
        // run never under-counts money already spent this speciality.
        await meter.persist();
      }
      console.log(slug, r, "spend $" + meter.total().toFixed(2));
      if (r.spendStopped) {
        console.log("cost ceiling reached; stopping. Re-run to resume.");
        break;
      }
    }
  } finally {
    await client.end();
  }
}

// One Bedrock call that merges a speciality's proposed chapter titles into
// canonical names. Reuses generateAnswer's transport indirectly via a small
// dedicated request. Kept here (not in canonicalize.js) so canonicalize stays
// model-agnostic and unit-testable.
async function chapterMergeModel(titles) {
  try {
    const { answer } = await generateAnswer(
      {
        speciality: "chapter-canonicalization",
        question:
          "Merge these chapter titles into canonical names. Return JSON with " +
          "chapter_title='map', sections=[{key:'map',heading:'map',body_md:JSON " +
          "string of {original: canonical}}], earns_marks=[]. Titles: " +
          JSON.stringify(titles),
        marks: null,
      },
      { maxTokens: MAX_TOKENS },
    );
    return JSON.parse(answer.sections[0].body_md);
  } catch {
    // any failure (transport 429/5xx, null answer, bad JSON) -> identity:
    // each title stays its own chapter. Canonicalization is best-effort and
    // must never abort or crash a paid run.
    return Object.fromEntries(titles.map((t) => [t, t]));
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
