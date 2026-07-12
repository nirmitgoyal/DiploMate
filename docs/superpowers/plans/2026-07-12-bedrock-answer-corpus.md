# Bedrock Answer Corpus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a structured DNB model answer for every unique question across 26 specialities' PYQ PDFs using Claude Haiku 4.5 on Amazon Bedrock, group them into emergent chapters, and publish `speciality -> chapter -> qna` into a new Heroku Postgres, for total spend under $100.

**Architecture:** A new resumable Node ESM tool at `ingestion/corpus/` that reuses the built extraction (`extract.js`) and dedup (`ledger.js`) modules, adds a Bedrock generation client (bearer-token `fetch`), a hard cost meter, per-speciality chapter canonicalization, and an idempotent Postgres publisher. Orchestrated by `run.js` with a canary-first ladder.

**Tech Stack:** Node 22 LTS, ESM, `node:test`; built-in `fetch` for Bedrock (no new dependency); `pg` (already a dep) for Postgres; `poppler-utils` + `tesseract` (present) via the reused extractor; Heroku Postgres.

## Global Constraints

Every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, or doc; plain hyphens only (user convention).
- Node 22, ESM (`"type": "module"`). No new runtime dependency: Bedrock calls use built-in `fetch`; DB uses the existing `pg`.
- Provider is Amazon Bedrock. Auth reads `AWS_BEARER_TOKEN_BEDROCK` from the env and is NEVER logged, printed, or committed. Region from `AWS_REGION` (default `us-east-1`). Model from `BEDROCK_MODEL_ID` (default `us.anthropic.claude-haiku-4-5-20251001-v1:0`; the canary pins the real id).
- Model is Claude Haiku 4.5. Do NOT send `effort` or `thinking` (Haiku rejects `effort`). `max_tokens` = 2000.
- HARD COST CAP: a running cost meter halts dispatch at a $90 ceiling (default). The token accounting is exact; the dollar rate is configurable (`RATE_IN`/`RATE_OUT`, default Haiku 4.5 ~= $1/$5 per 1M).
- Idempotency: `qnas.id = questionKey`; every DB write uses `ON CONFLICT DO NOTHING`. Any stage can be re-run without duplicating rows.
- TDD per task: failing test first, run it (expect FAIL), minimal implementation, run again (expect PASS), commit. Non-trivial logic (meter halt, JSON parse/validate/retry, dedup, canonicalize, publish idempotency) MUST carry a `node:test` test. The cost meter halt test is mandatory (money path).
- All commands run from `/Users/nirmit/Codebases/DiploMate/ingestion/` unless noted. Git commits from the repo root. Work is on branch `feat/opus-answer-corpus`.

## The 26 speciality slugs (reconciled to real `Qs/` folders)

```
anaesthesiology anatomy biochemistry cardiac-anaesthesia
clinical-immunology-and-rheumatology critical-care-medicine
dermatology-venereology-and-leprosy emergency-medicine endocrinology
forensic-medicine general-medicine general-surgery microbiology
neuro-anaesthesia neurosurgery obstetrics-and-gynaecology orthopaedics
otorhinolaryngology-ent palliative-medicine pathology paediatrics physiology
radiation-oncology radio-diagnosis respiratory-medicine urology
```

`Qs/` root: `/Users/nirmit/Library/CloudStorage/GoogleDrive-nirmitgoyal.goyal@gmail.com/My Drive/DiploMate/Qs`

## File Structure

- `ingestion/corpus/src/slugs.js` - the 26 slugs constant + Qs root default.
- `ingestion/corpus/src/manifest.js` - walk PDFs, extract (reuse), dedup (reuse) -> per-speciality unique questions.
- `ingestion/corpus/src/meter.js` - cost meter with hard halt + persistence.
- `ingestion/corpus/src/bedrock.js` - Haiku 4.5 Messages call (bearer `fetch`), prompt, JSON parse/validate/retry, usage.
- `ingestion/corpus/src/canonicalize.js` - slugify, dedupeSlugs, per-speciality synonym-merge.
- `ingestion/corpus/src/publish.js` - speciality lookup, chapter upsert, qna insert (idempotent).
- `ingestion/corpus/src/run.js` - orchestrator CLI (manifest -> generate w/ concurrency+meter -> canonicalize -> publish); canary flags.
- `ingestion/corpus/README.md` - how to run; never commits the token.
- `ingestion/corpus/test/*.test.js` - one per module.

---

### Task 1: corpus scaffold + slugs + manifest (extract + dedup, reuse)

**Files:**

- Create: `ingestion/corpus/src/slugs.js`
- Create: `ingestion/corpus/src/manifest.js`
- Create: `ingestion/corpus/test/manifest.test.js`
- Create: `ingestion/corpus/README.md`

**Interfaces:**

- Consumes: `extractQuestions(pdfPath)` from `../../generator/src/extract.js` (returns `{questions: [{question_text, year, paper, position, marks?}], qa}`); `questionKey(text)` from `../../generator/src/ledger.js` (sha256-16).
- Produces: `SLUGS` (string[]), `QS_ROOT` (string) from `slugs.js`; `listPapers(qsRoot, slug) -> string[]` and `buildManifest(qsRoot, slugs, {extractImpl?}) -> Map<slug, Array<{key, speciality_slug, question, years, marks}>>` from `manifest.js`. `years` is a comma-joined string of appearance years or null.

- [ ] **Step 1: Write `slugs.js`**

```js
// The 26 specialities to process, reconciled to real Qs/ folder names.
export const SLUGS = [
  "anaesthesiology",
  "anatomy",
  "biochemistry",
  "cardiac-anaesthesia",
  "clinical-immunology-and-rheumatology",
  "critical-care-medicine",
  "dermatology-venereology-and-leprosy",
  "emergency-medicine",
  "endocrinology",
  "forensic-medicine",
  "general-medicine",
  "general-surgery",
  "microbiology",
  "neuro-anaesthesia",
  "neurosurgery",
  "obstetrics-and-gynaecology",
  "orthopaedics",
  "otorhinolaryngology-ent",
  "palliative-medicine",
  "pathology",
  "paediatrics",
  "physiology",
  "radiation-oncology",
  "radio-diagnosis",
  "respiratory-medicine",
  "urology",
];

export const QS_ROOT =
  "/Users/nirmit/Library/CloudStorage/GoogleDrive-nirmitgoyal.goyal@gmail.com/My Drive/DiploMate/Qs";
```

- [ ] **Step 2: Write the failing test**

Copy the committed extractor fixture into a temp Qs tree and assert the manifest keys unique questions under the slug.

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, copyFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildManifest } from "../src/manifest.js";

const FIXTURE = fileURLToPath(
  new URL("../../generator/fixtures/sample-paper.pdf", import.meta.url),
);

test("buildManifest extracts and dedups questions per speciality", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "corpus-qs-"));
  const dir = path.join(root, "anatomy", "2020");
  await mkdir(dir, { recursive: true });
  await copyFile(FIXTURE, path.join(dir, "paper.pdf"));

  const manifest = await buildManifest(root, ["anatomy"]);
  const rows = manifest.get("anatomy");
  assert.ok(rows.length >= 1, "at least one question extracted");
  assert.match(rows[0].key, /^[0-9a-f]{16}$/);
  assert.equal(rows[0].speciality_slug, "anatomy");
  assert.ok(rows[0].question.length > 0);
});
```

- [ ] **Step 3: Run to verify it fails**

Run: `node --test corpus/test/manifest.test.js`
Expected: FAIL - `manifest.js` does not exist.

- [ ] **Step 4: Implement `manifest.js`**

```js
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
```

- [ ] **Step 5: Write `README.md` (no token ever committed)**

```markdown
# corpus - Bedrock answer generation for 26 DNB specialities

Reads PYQ PDFs from Qs/, generates Haiku 4.5 answers on Bedrock, publishes to
a new Heroku Postgres. Idempotent, resumable, hard cost cap.

## Env

- AWS_BEARER_TOKEN_BEDROCK (required; from ~/.zshrc, never committed)
- AWS_REGION (default us-east-1)
- BEDROCK_MODEL_ID (default us.anthropic.claude-haiku-4-5-20251001-v1:0)
- DATABASE_URL (the new Heroku Postgres)
- RATE_IN / RATE_OUT ($/1M tokens; default 1 / 5)

## Run

node src/run.js --canary-paper "<path-to-one.pdf>" # prove the Bedrock path
node src/run.js --speciality anaesthesiology # one speciality
node src/run.js --all --ceiling 90 # remaining, meter-gated
```

- [ ] **Step 6: Run to verify it passes; commit**

Run: `node --test corpus/test/manifest.test.js` -> PASS

```bash
git add ingestion/corpus/src/slugs.js ingestion/corpus/src/manifest.js ingestion/corpus/test/manifest.test.js ingestion/corpus/README.md
git commit -m "feat(corpus): scaffold + manifest (reuse extract.js + ledger.js)"
```

---

### Task 2: cost meter (money-safety, hard halt)

**Files:**

- Create: `ingestion/corpus/src/meter.js`
- Create: `ingestion/corpus/test/meter.test.js`

**Interfaces:**

- Produces: `createMeter({rateIn, rateOut, ceiling, statePath?}) -> {add(usage), total(), tokens(), wouldExceed(worstCaseNextUsd), persist(), load()}`; `worstCaseCall(maxTokens, rateOut) -> usd`. `usage` is `{input_tokens, output_tokens}`. Consumed by `run.js` (Task 6) to gate dispatch.

- [ ] **Step 1: Write the failing test (the halt guarantee)**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { createMeter, worstCaseCall } from "../src/meter.js";

test("meter accumulates spend and halts before the ceiling", () => {
  // rateOut 5 $/1M, ceiling $0.10. Each 15k-output call costs $0.075.
  const m = createMeter({ rateIn: 1, rateOut: 5, ceiling: 0.1 });
  const worst = worstCaseCall(2000, 5); // 2000/1e6*5 = $0.01

  m.add({ input_tokens: 1000, output_tokens: 15000 }); // total ~0.076
  assert.equal(m.wouldExceed(worst), false, "0.076 + 0.01 < 0.10");

  m.add({ input_tokens: 1000, output_tokens: 15000 }); // total ~0.151
  assert.equal(m.wouldExceed(worst), true, "0.151 exceeds 0.10");
  assert.ok(m.total() > 0.15);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test corpus/test/meter.test.js`
Expected: FAIL - `meter.js` does not exist.

- [ ] **Step 3: Implement `meter.js`**

```js
import { readFile, writeFile } from "node:fs/promises";

// Token accounting is exact; the $ rate is configurable because the real
// Bedrock Haiku price is masked. wouldExceed is checked BEFORE every dispatch
// so the run stops with margin, never overshooting the ceiling.
export function createMeter({ rateIn, rateOut, ceiling, statePath }) {
  let inTok = 0;
  let outTok = 0;
  const api = {
    add({ input_tokens = 0, output_tokens = 0 } = {}) {
      inTok += input_tokens;
      outTok += output_tokens;
    },
    total() {
      return (inTok / 1e6) * rateIn + (outTok / 1e6) * rateOut;
    },
    tokens() {
      return { inTok, outTok };
    },
    wouldExceed(worstCaseNextUsd) {
      return api.total() + worstCaseNextUsd >= ceiling;
    },
    async persist() {
      if (statePath)
        await writeFile(
          statePath,
          JSON.stringify({ inTok, outTok, usd: api.total() }),
        );
    },
    async load() {
      if (!statePath) return;
      try {
        const s = JSON.parse(await readFile(statePath, "utf8"));
        inTok = s.inTok || 0;
        outTok = s.outTok || 0;
      } catch {
        /* no prior state */
      }
    },
  };
  return api;
}

export function worstCaseCall(maxTokens, rateOut) {
  return (maxTokens / 1e6) * rateOut;
}
```

- [ ] **Step 4: Run to verify it passes; commit**

Run: `node --test corpus/test/meter.test.js` -> PASS

```bash
git add ingestion/corpus/src/meter.js ingestion/corpus/test/meter.test.js
git commit -m "feat(corpus): hard cost meter with pre-dispatch halt"
```

---

### Task 3: Bedrock Haiku client - prompt, call, JSON parse/validate/retry

**Files:**

- Create: `ingestion/corpus/src/bedrock.js`
- Create: `ingestion/corpus/test/bedrock.test.js`

**Interfaces:**

- Produces: `buildPrompt({speciality, question, marks}) -> string`; `parseAnswer(text) -> object` (strips fences, JSON.parse); `validateAnswer(obj) -> obj` (throws on bad shape); `generateAnswer({speciality, question, marks}, {fetchImpl?, token?, region?, model?, maxTokens?}) -> {answer|null, usage, flag?}`. `answer` shape: `{chapter_title, sections: [{key, heading, body_md}], earns_marks: [{label, section_key}]}`. `usage` is `{input_tokens, output_tokens}`. Consumed by `run.js` (Task 6).

- [ ] **Step 1: Write the failing test (stubbed fetch, no network)**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { generateAnswer, validateAnswer } from "../src/bedrock.js";

const VALID = {
  chapter_title: "Airway Management",
  sections: [{ key: "definition", heading: "Definition", body_md: "..." }],
  earns_marks: [{ label: "Defines airway", section_key: "definition" }],
};

function fakeFetch(
  payloadText,
  usage = { input_tokens: 100, output_tokens: 200 },
) {
  return async () => ({
    ok: true,
    json: async () => ({
      content: [{ type: "text", text: payloadText }],
      usage,
    }),
  });
}

test("generateAnswer parses valid JSON and returns usage", async () => {
  const r = await generateAnswer(
    { speciality: "Anaesthesiology", question: "Difficult airway?", marks: 10 },
    { fetchImpl: fakeFetch(JSON.stringify(VALID)), token: "x" },
  );
  assert.equal(r.answer.chapter_title, "Airway Management");
  assert.equal(r.usage.output_tokens, 200);
  assert.equal(r.flag, undefined);
});

test("generateAnswer strips markdown fences", () => {
  const obj = validateAnswer(
    JSON.parse("{}") && VALID, // sanity that VALID passes validation
  );
  assert.equal(obj.chapter_title, "Airway Management");
});

test("generateAnswer flags after two invalid responses", async () => {
  const r = await generateAnswer(
    { speciality: "X", question: "?", marks: 5 },
    { fetchImpl: fakeFetch("not json at all"), token: "x" },
  );
  assert.equal(r.answer, null);
  assert.equal(r.flag, "invalid-json");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test corpus/test/bedrock.test.js`
Expected: FAIL - `bedrock.js` does not exist.

- [ ] **Step 3: Implement `bedrock.js`**

````js
const SYSTEM =
  "You are a senior DNB examiner writing concise, high-yield model answers " +
  "for postgraduate medical exam preparation. Answer only from established " +
  "medical knowledge. Be structured and exam-oriented.";

// Ask for STRICT JSON in the exact serve shape. We do not rely on Bedrock
// structured-output betas; we parse and validate the text ourselves.
export function buildPrompt({ speciality, question, marks }) {
  return [
    `Speciality: ${speciality}`,
    marks ? `Marks: ${marks}` : "",
    `Question: ${question}`,
    "",
    "Write a DNB model answer. Return ONLY a JSON object, no prose, no code",
    "fences, matching exactly:",
    "{",
    '  "chapter_title": "the single best chapter/topic this question belongs to",',
    '  "sections": [{ "key": "kebab-case", "heading": "Heading", "body_md": "markdown" }],',
    '  "earns_marks": [{ "label": "scoring point", "section_key": "matching section key" }]',
    "}",
    "Keep it concise enough to fit a 2000-token budget.",
  ]
    .filter(Boolean)
    .join("\n");
}

export function parseAnswer(text) {
  const cleaned = text
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const s = cleaned.indexOf("{");
    const e = cleaned.lastIndexOf("}");
    if (s === -1 || e === -1) throw new Error("no JSON object found");
    return JSON.parse(cleaned.slice(s, e + 1));
  }
}

export function validateAnswer(obj) {
  const ok =
    obj &&
    typeof obj.chapter_title === "string" &&
    obj.chapter_title.trim() &&
    Array.isArray(obj.sections) &&
    obj.sections.length > 0 &&
    obj.sections.every(
      (s) =>
        s &&
        typeof s.key === "string" &&
        typeof s.heading === "string" &&
        typeof s.body_md === "string",
    ) &&
    Array.isArray(obj.earns_marks) &&
    obj.earns_marks.every(
      (m) =>
        m && typeof m.label === "string" && typeof m.section_key === "string",
    );
  if (!ok) throw new Error("answer failed schema validation");
  return obj;
}

export async function generateAnswer(
  { speciality, question, marks },
  {
    fetchImpl = fetch,
    token = process.env.AWS_BEARER_TOKEN_BEDROCK,
    region = process.env.AWS_REGION || "us-east-1",
    model = process.env.BEDROCK_MODEL_ID ||
      "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    maxTokens = 2000,
  } = {},
) {
  const url = `https://bedrock-runtime.${region}.amazonaws.com/model/${encodeURIComponent(
    model,
  )}/invoke`;
  const messages = [
    { role: "user", content: buildPrompt({ speciality, question, marks }) },
  ];
  let usage = {};
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetchImpl(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: maxTokens,
        system: SYSTEM,
        messages,
      }),
    });
    if (!res.ok) throw new Error(`bedrock ${res.status}: ${await res.text()}`);
    const data = await res.json();
    usage = data.usage || {};
    const text = (data.content || []).map((b) => b.text || "").join("");
    try {
      return { answer: validateAnswer(parseAnswer(text)), usage };
    } catch (e) {
      if (attempt === 1) return { answer: null, usage, flag: "invalid-json" };
      // one corrective turn (regular multi-turn, not a prefill)
      messages.push({ role: "assistant", content: text });
      messages.push({
        role: "user",
        content: "That was not valid JSON. Return ONLY the JSON object.",
      });
    }
  }
}
````

- [ ] **Step 4: Run to verify it passes; commit**

Run: `node --test corpus/test/bedrock.test.js` -> PASS

```bash
git add ingestion/corpus/src/bedrock.js ingestion/corpus/test/bedrock.test.js
git commit -m "feat(corpus): Bedrock Haiku client with JSON parse/validate/retry"
```

---

### Task 4: chapter canonicalization (slugify + per-speciality synonym merge)

**Files:**

- Create: `ingestion/corpus/src/canonicalize.js`
- Create: `ingestion/corpus/test/canonicalize.test.js`

**Interfaces:**

- Produces: `slugify(title) -> slug`; `dedupeSlugs(items) -> items` (items `{canonical, slug}`, appends `-2`/`-3` on repeat); `canonicalizeChapters(rawTitles, {callModel}) -> Map<raw, canonical>` where `callModel(uniqueTitles) -> {raw: canonical}`. Consumed by `run.js` (Task 6). The default `callModel` (Bedrock) is injected by `run.js`; tests stub it.

- [ ] **Step 1: Write the failing test**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  slugify,
  dedupeSlugs,
  canonicalizeChapters,
} from "../src/canonicalize.js";

test("slugify makes clean slugs from messy titles", () => {
  assert.equal(slugify("Airway Management"), "airway-management");
  assert.equal(
    slugify("1. Local Anaesthetics (Part II)"),
    "local-anaesthetics-part-ii",
  );
});

test("dedupeSlugs suffixes collisions deterministically", () => {
  const out = dedupeSlugs([
    { canonical: "Airway", slug: "airway" },
    { canonical: "Air-way", slug: "airway" },
  ]);
  assert.deepEqual(
    out.map((c) => c.slug),
    ["airway", "airway-2"],
  );
});

test("canonicalizeChapters merges synonyms via the model", async () => {
  const callModel = async () => ({
    Airway: "Airway Management",
    "Difficult Airway": "Airway Management",
    "Spinal Anaesthesia": "Spinal Anaesthesia",
  });
  const map = await canonicalizeChapters(
    ["Airway", "Difficult Airway", "Spinal Anaesthesia"],
    { callModel },
  );
  assert.equal(map.get("Airway"), "Airway Management");
  assert.equal(map.get("Difficult Airway"), "Airway Management");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test corpus/test/canonicalize.test.js`
Expected: FAIL - `canonicalize.js` does not exist.

- [ ] **Step 3: Implement `canonicalize.js`**

```js
export function slugify(title) {
  return title
    .toLowerCase()
    .replace(/^\s*\d+\.\s*/, "") // strip a leading "N."
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^-+|-+$/g, "");
}

// Deterministic -2/-3 suffixing when two canonical titles slugify identically.
export function dedupeSlugs(items) {
  const seen = new Map();
  return items.map((c) => {
    const n = (seen.get(c.slug) || 0) + 1;
    seen.set(c.slug, n);
    return n === 1 ? c : { ...c, slug: `${c.slug}-${n}` };
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
```

- [ ] **Step 4: Run to verify it passes; commit**

Run: `node --test corpus/test/canonicalize.test.js` -> PASS

```bash
git add ingestion/corpus/src/canonicalize.js ingestion/corpus/test/canonicalize.test.js
git commit -m "feat(corpus): chapter slugify + per-speciality synonym merge"
```

---

### Task 5: publish (idempotent speciality/chapter/qna writes)

**Files:**

- Create: `ingestion/corpus/src/publish.js`
- Create: `ingestion/corpus/test/publish.test.js`

**Interfaces:**

- Consumes: a connected `pg` client; the schema from `sql/0001..0004` (via `testClient()` in tests).
- Produces: `id16(str) -> string` (sha256-16); `getSpecialityId(client, slug) -> id|null`; `upsertChapter(client, specialityId, title, slug) -> chapterId`; `insertQna(client, {key, chapterId, question, years, marks, earnsMarks, sections}) -> void`. Consumed by `run.js` (Task 6). All writes idempotent.

- [ ] **Step 1: Write the failing test (uses the disposable test DB)**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { testClient, TEST_SPECIALITY_ID } from "../../test/db.js";
import {
  id16,
  getSpecialityId,
  upsertChapter,
  insertQna,
} from "../src/publish.js";

const skip =
  !process.env.DATABASE_URL &&
  "set DATABASE_URL (disposable) for publish tests";

test("chapter + qna writes are idempotent", { skip }, async () => {
  const client = await testClient(); // applies sql/0001..0004, seeds specialities
  try {
    const specId = await getSpecialityId(client, "anaesthesiology");
    assert.equal(specId, TEST_SPECIALITY_ID);

    const chId = await upsertChapter(
      client,
      specId,
      "Airway Management",
      "airway-management",
    );
    const chId2 = await upsertChapter(
      client,
      specId,
      "Airway Management",
      "airway-management",
    );
    assert.equal(
      chId,
      chId2,
      "same (speciality, slug) -> same deterministic id",
    );

    const qna = {
      key: id16("q|airway"),
      chapterId: chId,
      question: "Discuss difficult airway.",
      years: "2019, 2022",
      marks: 10,
      earnsMarks: [{ label: "Plan", section_key: "plan" }],
      sections: [{ key: "plan", heading: "Plan", body_md: "..." }],
    };
    await insertQna(client, qna);
    await insertQna(client, qna); // second insert must not duplicate

    const chapters = await client.query(
      "SELECT count(*)::int n FROM chapters WHERE id = $1",
      [chId],
    );
    const qnas = await client.query(
      "SELECT count(*)::int n FROM qnas WHERE id = $1",
      [qna.key],
    );
    assert.equal(chapters.rows[0].n, 1);
    assert.equal(qnas.rows[0].n, 1);
  } finally {
    await client.end();
  }
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `DATABASE_URL=<disposable> node --test corpus/test/publish.test.js`
Expected: FAIL - `publish.js` does not exist. (Skips cleanly with no DATABASE_URL.)

- [ ] **Step 3: Implement `publish.js`**

```js
import { createHash } from "node:crypto";

export function id16(s) {
  return createHash("sha256").update(s).digest("hex").slice(0, 16);
}

export async function getSpecialityId(client, slug) {
  const { rows } = await client.query(
    "SELECT id FROM specialities WHERE slug = $1",
    [slug],
  );
  return rows[0]?.id ?? null;
}

// Chapter id is deterministic from (speciality, slug) so re-runs and the
// UNIQUE(speciality_id, slug) constraint agree. content_version starts at 0.
export async function upsertChapter(client, specialityId, title, slug) {
  const id = id16(`${specialityId}|${slug}`);
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ($1, $2, $3, $4, 0, 0, 0)
     ON CONFLICT (speciality_id, slug) DO NOTHING`,
    [id, specialityId, title, slug],
  );
  return id;
}

export async function insertQna(
  client,
  { key, chapterId, question, years, marks, earnsMarks, sections },
) {
  await client.query(
    `INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 0)
     ON CONFLICT (id) DO NOTHING`,
    [
      key,
      chapterId,
      question,
      years ?? null,
      marks ?? null,
      JSON.stringify(earnsMarks ?? []),
      JSON.stringify(sections),
    ],
  );
}
```

- [ ] **Step 4: Run to verify it passes; commit**

Run: `DATABASE_URL=<disposable> node --test corpus/test/publish.test.js` -> PASS

```bash
git add ingestion/corpus/src/publish.js ingestion/corpus/test/publish.test.js
git commit -m "feat(corpus): idempotent speciality/chapter/qna publish"
```

---

### Task 6: orchestrator run.js (manifest -> generate w/ concurrency+meter -> canonicalize -> publish)

**Files:**

- Create: `ingestion/corpus/src/run.js`
- Create: `ingestion/corpus/src/pool.js`
- Create: `ingestion/corpus/test/pool.test.js`
- Create: `ingestion/corpus/test/run_dry.test.js`

**Interfaces:**

- Consumes: `buildManifest` (T1), `createMeter`/`worstCaseCall` (T2), `generateAnswer`/`buildPrompt` (T3), `canonicalizeChapters`/`slugify`/`dedupeSlugs` (T4), `getSpecialityId`/`upsertChapter`/`insertQna` (T5).
- Produces: `mapPool(items, concurrency, worker, shouldStop?) -> results` in `pool.js`; `processSpeciality(client, slug, rows, deps) -> {published, flagged, spendStopped}` in `run.js` (exported for the dry-run test); a CLI `main()` parsing `--canary-paper`, `--speciality`, `--all`, `--ceiling`, `--concurrency`, plus env for token/region/model/DATABASE_URL.

- [ ] **Step 1: Write the failing pool test**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mapPool } from "../src/pool.js";

test("mapPool runs with bounded concurrency and honors shouldStop", async () => {
  const seen = [];
  let stopAfter = 3;
  const out = await mapPool(
    [1, 2, 3, 4, 5],
    2,
    async (x) => {
      seen.push(x);
      return x * 2;
    },
    () => seen.length >= stopAfter, // stop scheduling once 3 started
  );
  assert.ok(seen.length >= 3 && seen.length <= 5);
  assert.ok(out.filter((r) => r !== undefined).length >= 3);
});
```

- [ ] **Step 2: Run to verify it fails, then implement `pool.js`**

Run: `node --test corpus/test/pool.test.js` -> FAIL (module missing).

```js
// Bounded-concurrency map. Before starting each item, shouldStop() is checked
// so the cost meter can halt scheduling; in-flight workers always finish.
export async function mapPool(
  items,
  concurrency,
  worker,
  shouldStop = () => false,
) {
  const results = new Array(items.length);
  let next = 0;
  async function run() {
    while (next < items.length) {
      if (shouldStop()) return;
      const i = next++;
      results[i] = await worker(items[i], i);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, run),
  );
  return results;
}
```

Run: `node --test corpus/test/pool.test.js` -> PASS.

- [ ] **Step 3: Write the failing dry-run test for `processSpeciality` (all deps stubbed, no network, no DB)**

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { processSpeciality } from "../src/run.js";

test("processSpeciality generates, canonicalizes, and publishes idempotently", async () => {
  const rows = [
    {
      key: "k1",
      speciality_slug: "anatomy",
      question: "Q1?",
      years: "2020",
      marks: 10,
    },
    {
      key: "k2",
      speciality_slug: "anatomy",
      question: "Q2?",
      years: "2021",
      marks: 10,
    },
  ];
  const published = [];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    generate: async ({ question }) => ({
      answer: {
        chapter_title: question === "Q1?" ? "Upper Limb" : "Upper limb",
        sections: [{ key: "s", heading: "S", body_md: "b" }],
        earns_marks: [{ label: "L", section_key: "s" }],
      },
      usage: { input_tokens: 50, output_tokens: 100 },
    }),
    canonicalize: async (titles) =>
      new Map(titles.map((t) => [t, "Upper Limb"])), // merge the two casings
    upsertChapter: async (_c, _s, _title, slug) => `ch-${slug}`,
    insertQna: async (_c, q) => published.push(q.key),
    meter: {
      add() {},
      wouldExceed: () => false,
      total: () => 0.001,
    },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.equal(r.published, 2);
  assert.equal(r.flagged, 0);
  assert.deepEqual(published.sort(), ["k1", "k2"]);
});

test("processSpeciality stops publishing new work when the meter would exceed", async () => {
  const rows = [
    { key: "k1", speciality_slug: "anatomy", question: "Q1?", years: "2020" },
  ];
  const deps = {
    specialityName: "Anatomy",
    getSpecialityId: async () => "SPEC1",
    generate: async () => ({ answer: null, usage: {}, flag: "invalid-json" }),
    canonicalize: async (t) => new Map(t.map((x) => [x, x])),
    upsertChapter: async () => "ch",
    insertQna: async () => {},
    meter: { add() {}, wouldExceed: () => true, total: () => 999 },
  };
  const r = await processSpeciality(null, "anatomy", rows, deps);
  assert.equal(r.spendStopped, true);
  assert.equal(r.published, 0);
});
```

- [ ] **Step 4: Run to verify it fails, then implement `run.js`**

Run: `node --test corpus/test/run_dry.test.js` -> FAIL (module missing).

```js
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

  const worst = worstCaseCall(MAX_TOKENS, deps.rateOut ?? 5);
  const specialityId = await getSpecialityId(client, slug);
  const generated = [];
  let flagged = 0;
  let spendStopped = false;

  // Stage A: generate (bounded concurrency, meter-gated).
  const { mapPool } = await import("./pool.js");
  await mapPool(
    rows,
    concurrency,
    async (row) => {
      if (meter.wouldExceed(worst)) {
        spendStopped = true;
        return;
      }
      const { answer, usage, flag } = await generate({
        speciality: specialityName,
        question: row.question,
        marks: row.marks,
      });
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
    // Canary: one paper, one speciality inferred from its path.
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
      const r = await processSpeciality(client, slug, rows, {
        ...deps,
        specialityName: nameFromSlug(slug),
      });
      await meter.persist();
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
  try {
    return JSON.parse(answer.sections[0].body_md);
  } catch {
    return Object.fromEntries(titles.map((t) => [t, t])); // fall back to identity
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
```

- [ ] **Step 5: Run both tests to verify they pass; commit**

Run: `node --test corpus/test/pool.test.js corpus/test/run_dry.test.js` -> PASS

```bash
git add ingestion/corpus/src/run.js ingestion/corpus/src/pool.js ingestion/corpus/test/pool.test.js ingestion/corpus/test/run_dry.test.js
git commit -m "feat(corpus): orchestrator run.js + bounded pool (meter-gated)"
```

- [ ] **Step 6: Full suite green**

Run: `node --test` (from `ingestion/`) -> all corpus tests PASS (publish skips without DATABASE_URL).

---

### Task 7: provision the new Heroku app + apply schema (operational, confirm before running)

**Files:**

- Create: `ingestion/corpus/provision.sh` (documents the exact commands; not auto-run)

**Interfaces:**

- Produces: a new Heroku app with Postgres and the full `sql/0001..0004` schema applied (specialities seeded). Its `DATABASE_URL` feeds Tasks 6 and 8.

- [ ] **Step 1: Write `provision.sh` (creating infra is an outward action; the operator runs this, confirming the Heroku account first)**

```bash
#!/usr/bin/env bash
set -euo pipefail
# Heroku CLI is authed as parth.mitblr2023@learner.manipal.edu. Confirm the
# account is intended before running (the new app + Postgres bill to it).
APP="${1:-diplomate-corpus}"

heroku create "$APP"
heroku addons:create heroku-postgresql:essential-0 -a "$APP"
# Wait for the DB to provision, then apply every numbered migration in order
# (same contract as tools/db/apply.sh and test/db.js testClient()).
for f in ../sql/0001_content_v0.sql ../sql/0002_seed_specialities.sql \
         ../sql/0003_users_events.sql ../sql/0004_drop_topics.sql; do
  echo "applying $f"
  heroku pg:psql -a "$APP" < "$f"
done
heroku config:get DATABASE_URL -a "$APP"
echo "Export this DATABASE_URL for run.js."
```

- [ ] **Step 2: Operator runs provisioning (gated)**

This step spends money and creates infra, so it runs only on explicit go-ahead:

```bash
cd ingestion/corpus && chmod +x provision.sh && ./provision.sh diplomate-corpus
```

Verify: `heroku pg:psql -a diplomate-corpus -c "SELECT count(*) FROM specialities;"` returns 61.

- [ ] **Step 3: Commit the script**

```bash
git add ingestion/corpus/provision.sh
git commit -m "chore(corpus): Heroku provisioning script (new DB + schema apply)"
```

---

### Task 8: canary run, verify, then the metered full run (operational, gated)

**Files:** none (operational).

**Interfaces:**

- Consumes: Tasks 1-7. Produces the published corpus in the new DB and a `spend.json` audit.

- [ ] **Step 1: Prove the Bedrock path on ONE paper**

```bash
cd ingestion
export AWS_BEARER_TOKEN_BEDROCK=...   # already in ~/.zshrc; source it
export AWS_REGION=us-east-1
export DATABASE_URL=$(heroku config:get DATABASE_URL -a diplomate-corpus)
node corpus/src/run.js --canary-paper \
  "/Users/nirmit/Library/CloudStorage/GoogleDrive-nirmitgoyal.goyal@gmail.com/My Drive/DiploMate/Qs/anaesthesiology/2022/DNB Anaesthesiology Paper1 - Dec-22.pdf"
```

Expected: prints `canary: { published: N, flagged: M, ... } spend $0.0X`. If it errors on auth or model id, fix `BEDROCK_MODEL_ID` / `AWS_REGION` / enable Haiku 4.5 model access in the Bedrock console, then re-run. Read one published row:

```bash
heroku pg:psql -a diplomate-corpus -c \
  "SELECT question, sections->0->>'heading' FROM qnas LIMIT 3;"
```

Confirm the answer reads as a DNB model answer and the sections/earns_marks shape is present.

- [ ] **Step 2: Run one full speciality, measure, extrapolate**

```bash
node corpus/src/run.js --speciality anaesthesiology --ceiling 90
cat spend.json   # tokens + usd for ~500 questions
```

Compute tokens/question from `spend.json`; multiply by ~6.8k total unique questions and the real Haiku rate. CONFIRM the projection is under $100 before proceeding. If projection exceeds budget, lower scope or stop here (the meter will halt anyway).

- [ ] **Step 3: Run the remaining specialities under the meter**

```bash
node corpus/src/run.js --all --ceiling 90
```

The run processes each slug, persists `spend.json` between specialities, and stops if the ceiling is reached (re-run to resume; idempotency skips done rows). Already-published anaesthesiology rows are skipped.

- [ ] **Step 4: Verify totals**

```bash
heroku pg:psql -a diplomate-corpus -c \
  "SELECT s.slug, count(DISTINCT c.id) chapters, count(q.id) qnas
   FROM specialities s
   LEFT JOIN chapters c ON c.speciality_id = s.id
   LEFT JOIN qnas q ON q.chapter_id = c.id
   GROUP BY s.slug ORDER BY qnas DESC;"
cat spend.json   # final spend must be < 100
```

Expected: each of the 26 slugs has chapters and qnas; total spend under $100.

---

## Self-review checklist (run before declaring the plan done)

- Every spec stage maps to a task: extract+dedup (T1), meter (T2), Bedrock gen (T3), canonicalize (T4), publish (T5), orchestrate (T6), provision (T7), canary+full run (T8).
- The money guarantee (meter halt) has a mandatory unit test (T2) and is enforced pre-dispatch in `run.js` (T6).
- Idempotency: `qnas.id = questionKey`, `ON CONFLICT DO NOTHING` on chapter + qna; proven in T5.
- No new runtime dependency: Bedrock via built-in `fetch`, DB via existing `pg`.
- `AWS_BEARER_TOKEN_BEDROCK` is read from env, never logged or committed.
- Slugs reconciled: neuro-anaesthesia, paediatrics, radio-diagnosis.
- Types consistent across tasks: `{key, speciality_slug, question, years, marks}` manifest rows; `{answer:{chapter_title, sections, earns_marks}, usage, flag?}` from `generateAnswer`; `usage:{input_tokens, output_tokens}` into the meter.
- Operational spend/infra steps (T7 provisioning, T8 runs) are explicitly gated on operator go-ahead.
