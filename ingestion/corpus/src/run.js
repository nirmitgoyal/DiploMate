import { parseArgs } from "node:util";
import pg from "pg";
import { buildManifest } from "./manifest.js";
import { SLUGS, QS_ROOT } from "./slugs.js";
import { createMeter, worstCaseCall } from "./meter.js";
import { generateAnswer, callJson } from "./bedrock.js";
import { canonicalizeChapters, slugify, dedupeSlugs } from "./canonicalize.js";
import {
  getSpecialityId,
  getExistingQnaIds,
  upsertChapter,
  insertQna,
} from "./publish.js";

const MAX_TOKENS = 2000;

// Title-case a slug for the model prompt: "neuro-anaesthesia" -> "Neuro Anaesthesia".
function nameFromSlug(slug) {
  return slug
    .split("-")
    .map((w) => (w[0]?.toUpperCase() ?? "") + w.slice(1))
    .join(" ");
}

// Generate answers for a speciality's questions under the meter, canonicalize
// the proposed chapter titles, then publish. Returns counts. All external
// effects come through `deps` so the dry-run test needs no network or DB.
export async function processSpeciality(client, slug, rows, deps) {
  const {
    specialityName,
    getSpecialityId,
    getExistingQnaIds,
    generate,
    canonicalize,
    upsertChapter,
    insertQna,
    meter,
    concurrency = 1,
  } = deps;

  // ponytail: default concurrency 1 - the Bedrock on-demand Haiku tokens/min cap
  // throttles hard above it (a live run at 4 lost ~25-30% of calls to 429 and
  // starved canonicalization; serial stays under the cap: 651 published / 13
  // flagged). Raise --concurrency only with a higher quota. Overshoot note: up to
  // (concurrency-1) in-flight calls can pass this pre-check before their spend
  // registers, so spend can exceed the ceiling by at most (concurrency-1)*worst
  // (0 at the default 1), absorbed by the ceiling-to-cap margin ($90 vs $100). If
  // MAX_TOKENS/rateOut/concurrency grow, switch to a reservation model.
  const worst = worstCaseCall(MAX_TOKENS, deps.rateOut ?? 5);
  const specialityId = await getSpecialityId(client, slug);
  const existing = await getExistingQnaIds(client, specialityId);
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
      if (existing.has(row.key)) return; // already generated + published: skip, no re-spend
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
  const concurrency = Number(values.concurrency || 1);
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
    getExistingQnaIds,
    generate: (q) => generateAnswer(q, { maxTokens: MAX_TOKENS }),
    canonicalize: (titles) =>
      canonicalizeChapters(titles, {
        buildTaxonomy: (t) => buildTaxonomy(t, meter),
        classify: (batch, taxonomy) => classifyTitles(batch, taxonomy, meter),
      }),
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

// Canonicalization runs right after a speciality's whole generation burst has
// saturated the Bedrock rate limit, so its few calls MUST out-wait the throttle
// - a failed taxonomy call falls back to identity (no grouping at all). Give the
// aux calls a much larger retry budget than a single generation call.
const AUX_CALL_OPTS = {
  maxTokens: MAX_TOKENS,
  maxTransportRetries: 10,
  retryBaseMs: 1000,
};

// Phase 1 of canonicalization: ONE Bedrock call that reads every proposed title
// and returns a compact canonical chapter list. The output is just the chapter
// names (small), so hundreds of titles fit in one call without truncating. One
// pass often overshoots the 30-60 ask on a large, varied input, so a second
// pass over the result compacts it. Any failure returns [] so canonicalize falls
// back to identity - a paid run is never crashed by best-effort grouping.
async function buildTaxonomy(titles, meter) {
  const ask = async (items) => {
    const { value, usage } = await callJson(
      "You are organizing a medical exam question bank. Below are chapter " +
        "titles proposed for individual questions. Return ONLY a JSON array of " +
        "30 to 60 canonical chapter names that together cover all of them, " +
        "grouping synonyms and closely-related topics under one broad chapter. " +
        "No prose, just the JSON array. Titles: " +
        JSON.stringify(items),
      AUX_CALL_OPTS,
    );
    if (meter) meter.add(usage);
    return Array.isArray(value)
      ? value.filter((s) => typeof s === "string" && s.trim())
      : [];
  };
  try {
    let tax = await ask(titles);
    if (tax.length > 70) {
      const tighter = await ask(tax); // re-merge the taxonomy onto itself
      if (tighter.length >= 20 && tighter.length < tax.length) tax = tighter;
    }
    return tax;
  } catch {
    return [];
  }
}

// Phase 2 of canonicalization: assign a batch of titles to the fixed taxonomy.
// One Bedrock call per batch (output-bounded). Any failure returns {} so each
// unclassified title keeps its own name (never dropped). Usage is metered.
async function classifyTitles(titles, taxonomy, meter) {
  try {
    const { value, usage } = await callJson(
      "Assign each question title to the single best-matching chapter from the " +
        "allowed list. Use ONLY chapter names from the list, verbatim. Return " +
        "ONLY a JSON object mapping each title to its chapter, no prose. " +
        "Allowed chapters: " +
        JSON.stringify(taxonomy) +
        " Titles: " +
        JSON.stringify(titles),
      AUX_CALL_OPTS,
    );
    if (meter) meter.add(usage);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value
      : {};
  } catch {
    return {};
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
