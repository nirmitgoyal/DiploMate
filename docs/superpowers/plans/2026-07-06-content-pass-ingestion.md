# Content Pass Lane B: Ingestion Rewrites (Speciality Ledger, Validate v2, Publish v2, AUTHORING) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the shipped `build -> validate -> publish` pipeline for the topics-less schema v2: one speciality-level `ids.lock` (a question moved between chapters keeps its ULID), `validate.js` enforcing canonical `schema_version: 2` with `qnas[]` directly under the chapter, `publish.js` orphan-deleting by `chapter_id` with a batch-republish CLI, the fixture migrated in place with ZERO ULID churn, and `AUTHORING.md` rewritten (de-brand amendment + holding area + the `anaesthesia` -> `anaesthesiology` slug fix).

**Architecture:** Same three ESM modules, same CLI surface, no new dependencies. The identity ledger widens from per-chapter to per-speciality (eng amendment 1): `build.js` takes an explicit lock path (default: `ids.lock` in the chapter dir's PARENT, so sibling chapters of one speciality share it) and the lock maps `chapters/qnas/images` keys to ULIDs with NO topics map. `validate.js` and `publish.js` lose their topics passes wholesale. This is eng-review tasks T1, T2, the ingestion half of T6, and the ingestion slices of T10.

**Tech Stack:** Node 22 LTS, ESM, `node:test`, `ulid`, `sharp`, `pg`.

**Source of truth:** design doc `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-claude-jolly-banach-f5aef8-design-20260706-134407.md` - the "ENG REVIEW AMENDMENTS (2026-07-06)" section SUPERSEDES the doc body wherever they conflict.

## Global Constraints

Every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, or doc; plain hyphens only (user convention).
- **Publish stays blocked until `LICENSE_SIGNED=true`: `gateCheck` in `ingestion/src/publish.js` is NEVER weakened, renamed, or bypassed.** Its three tests in `publish.test.js` must remain green verbatim. Integration tests may SET `LICENSE_SIGNED=true` in their own env to exercise `publishChapter` against a scratch DB - that exercises the gate, it does not weaken it.
- All content uses `speciality_slug` **`anaesthesiology`** (seeded `sql/0002_seed_specialities.sql:8`, id `01JZSP3C00DNB0000000000001`). The `anaesthesia` slug in `AUTHORING.md:77` and the fixtures is a known bug fixed HERE (T2); the old slug would fail publish against the real seed.
- Content IDs are ULIDs minted once into a COMMITTED `ids.lock`; keys are permanent; re-runs must produce ZERO key churn for published questions. The fixture migration in Task 4 carries every existing qna/image/chapter ULID over byte-identically.
- Migrations are append-only; this lane touches NO `sql/` files. It CONSUMES `sql/0004_drop_topics.sql` (lane A Task 1) for publish integration tests - that file must exist in this worktree before Task 1 here runs.
- Canonical v2 contract (shared with lanes A/D - copy exactly): `{"schema_version": 2, "speciality_slug": "anaesthesiology", "chapter": {"id", "title", "slug", "sort_order", "exam_weight"}, "qnas": [{"id", "chapter_id", "question", "years", "marks", "earns_marks", "sections", "sort_order"}], "images": [{"id", "qna_id", "caption", "content_description", "file", "byte_size", "sha256", "sort_order"}]}` - NO `topics` key anywhere; `validate.js` REJECTS a canonical that carries one.
- Image laws unchanged: WebP only, `byte_size <= 204800`, edge cap 1600px, `caption` + `content_description` mandatory, quality ladder 80/60/40.
- D16 sections/earns_marks shape unchanged: every `earns_marks[].section_key` resolves to a `sections[].key`.
- Identifier-level sweep (amendment 14): after this lane, `grep -rniE 'topic_id|topic_count|topicId|topics?\b' ingestion/src ingestion/test ingestion/fixtures ingestion/AUTHORING.md | grep -viE 'topical|topic_opened'` returns zero lines. The fixture DELIBERATELY contains the medical phrase "topical anaesthesia" (T19's false-positive guard) - the `topical` filter must exempt it.
- TDD per task: failing test first, run it (expect FAIL with the stated reason), minimal implementation, run again (expect PASS), commit. Conventional commits.

**Working directory:** all `node`/`npm` commands run from `/Users/nirmit/Codebases/DiploMate/ingestion/`. Git commits from the repo root. Publish integration tests need `DATABASE_URL` pointing at a disposable Postgres (they rebuild its schema themselves after Task 1).

**Execution order across lanes:** lane B runs in parallel with A and C in separate worktrees (superpowers:using-git-worktrees), AFTER lane A's Task 1 (the 0004 file) is available. Lane D (generator) extends this same `ingestion/` package - do NOT run B and D in parallel worktrees.

---

### Task 1: test DB helper applies the full migration chain

**Files:**

- Modify: `ingestion/test/db.js`

**Interfaces:**

- Consumes: `sql/0001` - `sql/0004` (lane A Task 1).
- Produces: `testClient()` returning a `pg.Client` on a from-zero schema with ALL migrations applied; `TEST_SPECIALITY_ID = "01JZSP3C00DNB0000000000001"` (the seeded anaesthesiology row - tests no longer pin their own).

- [ ] **Step 1: Rewrite the helper**

Replace `ingestion/test/db.js` with:

```js
import { readdir, readFile } from "node:fs/promises";
import pg from "pg";

// The seeded Anaesthesiology row (sql/0002) - the beta content anchor.
export const TEST_SPECIALITY_ID = "01JZSP3C00DNB0000000000001";

// Rebuilds the disposable test database from zero with EVERY numbered
// migration, in filename order - the same contract tools/db/apply.sh
// enforces, so publish tests always run against the real current schema.
export async function testClient() {
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  await client.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public");
  const sqlDir = new URL("../../sql/", import.meta.url);
  const files = (await readdir(sqlDir))
    .filter((f) => /^\d{4}_.*\.sql$/.test(f))
    .sort();
  for (const f of files) {
    await client.query(await readFile(new URL(f, sqlDir), "utf8"));
  }
  return client;
}
```

- [ ] **Step 2: Run the existing suite to observe the expected breakage**

Run: `DATABASE_URL=<disposable> npm test`
Expected: `publish.test.js` integration tests now FAIL (they publish the OLD topics-shaped fixture against the NEW post-0004 schema - `relation "topics" does not exist` / validation errors). `build`, `validate`, `fixture` tests still pass (fs-only, still v1). This red is the lane's working state until Task 5.

- [ ] **Step 3: Commit**

```bash
git add ingestion/test/db.js
git commit -m "test(ingestion): db helper applies full migration chain incl 0004; use seeded anaesthesiology"
```

---

### Task 2: `build.js` v2 - speciality-level ledger + canonical v2

**Files:**

- Modify: `ingestion/src/build.js`
- Test: `ingestion/test/build.test.js`

**Interfaces:**

- Consumes: authoring v2 shape (defined here, documented in Task 5's AUTHORING.md): `{"speciality_slug", "chapter": {"key", "title", "slug", "sort_order", "exam_weight"}, "qnas": [{"key", "question", "years?", "marks?", "sort_order", "earns_marks", "sections", "images?"}]}`.
- Produces: `buildChapter(chapterDir, outDir, lockPath?) -> canonical` (canonical v2 per Global Constraints); `defaultLockPath(chapterDir)` = `path.join(path.dirname(path.resolve(chapterDir)), "ids.lock")`; lock file shape `{"chapters": {<chapter.key>: ULID}, "qnas": {<qna.key>: ULID}, "images": {"<qna.key>/<file>": ULID}}`. `processImage` unchanged. CLI: `node src/build.js <chapterDir> <outDir> [lockPath]`.

- [ ] **Step 1: Rewrite the test fixture helper and the identity tests (failing first)**

In `ingestion/test/build.test.js`, replace `sourceChapter()` with the v2 authoring shape and add the ledger tests. Keep every `processImage`-related test in the file untouched (quality ladder, oversize failure, EXIF rotate - they do not mention topics). Delete any test that asserts `canonical.topics` or `lock.topics`.

```js
function sourceChapter() {
  return {
    speciality_slug: "anaesthesiology",
    chapter: {
      key: "sample-chapter",
      title: "Sample Chapter",
      slug: "sample-chapter",
      sort_order: 1,
      exam_weight: 10,
    },
    qnas: [
      {
        key: "q-one",
        question: "Question one?",
        years: "2022",
        marks: 10,
        sort_order: 1,
        earns_marks: [{ label: "Definition point", section_key: "definition" }],
        sections: [
          { key: "definition", heading: "Definition", body_md: "Body one." },
        ],
        images: [],
      },
    ],
  };
}
```

`makeChapterDir(source)` stays as-is (tmpdir + images/ + chapter.json). Add a sibling-dir helper so two chapters share one speciality parent:

```js
async function makeSpecialityDir(...sources) {
  const parent = await mkdtemp(path.join(tmpdir(), "ingest-spec-"));
  const dirs = [];
  for (const [i, source] of sources.entries()) {
    const dir = path.join(parent, `ch${i}`);
    await mkdir(path.join(dir, "images"), { recursive: true });
    await writeFile(
      path.join(dir, "chapter.json"),
      JSON.stringify(source, null, 2),
    );
    dirs.push(dir);
  }
  return { parent, dirs };
}
```

New/updated tests:

```js
test("build mints ULIDs into a speciality-level lock beside the chapter dirs", async () => {
  const { parent, dirs } = await makeSpecialityDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const canonical = await buildChapter(dirs[0], out);
  assert.equal(canonical.schema_version, 2);
  assert.match(canonical.chapter.id, ULID_RE);
  assert.equal(canonical.qnas[0].chapter_id, canonical.chapter.id);
  assert.equal("topics" in canonical, false);
  const lock = JSON.parse(
    await readFile(path.join(parent, "ids.lock"), "utf8"),
  );
  assert.equal(lock.chapters["sample-chapter"], canonical.chapter.id);
  assert.equal(lock.qnas["q-one"], canonical.qnas[0].id);
  assert.equal("topics" in lock, false);
});

test("re-run produces zero key churn (ledger stability)", async () => {
  const { parent, dirs } = await makeSpecialityDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  await buildChapter(dirs[0], out);
  const first = await readFile(path.join(parent, "ids.lock"), "utf8");
  await buildChapter(dirs[0], out);
  const second = await readFile(path.join(parent, "ids.lock"), "utf8");
  assert.equal(
    second,
    first,
    "second build must not re-mint or reorder anything",
  );
});

test("a qna moved between chapters keeps its ULID (speciality ledger, amendment 1)", async () => {
  const chapterA = sourceChapter();
  const chapterB = {
    ...sourceChapter(),
    chapter: {
      key: "other-chapter",
      title: "Other",
      slug: "other-chapter",
      sort_order: 2,
      exam_weight: 5,
    },
    qnas: [],
  };
  const { parent, dirs } = await makeSpecialityDir(chapterA, chapterB);
  const out1 = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const builtA = await buildChapter(dirs[0], out1);
  const movedId = builtA.qnas[0].id;

  // Move q-one: gone from A, present in B. Same speciality lock -> same ULID.
  const aWithout = { ...chapterA, qnas: [] };
  const bWith = { ...chapterB, qnas: chapterA.qnas };
  await writeFile(
    path.join(dirs[0], "chapter.json"),
    JSON.stringify(aWithout, null, 2),
  );
  await writeFile(
    path.join(dirs[1], "chapter.json"),
    JSON.stringify(bWith, null, 2),
  );
  const out2 = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const builtB = await buildChapter(dirs[1], out2);
  assert.equal(
    builtB.qnas[0].id,
    movedId,
    "reclassification must not re-mint identity",
  );
  assert.equal(builtB.qnas[0].chapter_id, builtB.chapter.id);
});

test("missing chapter.key or qna.key fails loudly", async () => {
  const noChapterKey = sourceChapter();
  delete noChapterKey.chapter.key;
  const dir1 = await makeChapterDir(noChapterKey);
  await assert.rejects(
    () => buildChapter(dir1, dir1 + "-out"),
    /chapter .*missing "key"/,
  );
  const noQnaKey = sourceChapter();
  delete noQnaKey.qnas[0].key;
  const dir2 = await makeChapterDir(noQnaKey);
  await assert.rejects(
    () => buildChapter(dir2, dir2 + "-out"),
    /qna .*missing "key"/,
  );
});

test("an explicit lockPath overrides the default (generator hands the committed ledger in)", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const out = await mkdtemp(path.join(tmpdir(), "ingest-out-"));
  const lockPath = path.join(
    await mkdtemp(path.join(tmpdir(), "ledger-")),
    "anaesthesiology.ids.lock",
  );
  const canonical = await buildChapter(dir, out, lockPath);
  const lock = JSON.parse(await readFile(lockPath, "utf8"));
  assert.equal(lock.chapters["sample-chapter"], canonical.chapter.id);
});
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `npm test`
Expected: build tests FAIL - `buildChapter` still reads `source.topics` (v2 sources have no topics, so canonical.qnas is empty / `chapter.key` errors are not thrown / lock shape mismatches).

- [ ] **Step 3: Rewrite `build.js`**

Replace the ledger and tree-walk portions of `ingestion/src/build.js` (imports, `MAX_IMAGE_BYTES`, `MAX_IMAGE_EDGE`, `WEBP_QUALITIES`, `processImage`, `sortKeys` are unchanged):

```js
// Speciality-level ledger (eng amendment 1): ONE ids.lock per speciality;
// chapter membership is placement only, so a question moved between chapters
// keeps its ULID. Default lock location: the chapter dir's PARENT (all of a
// speciality's chapter dirs share it); the generator passes the committed
// ledger path explicitly. After a cross-chapter move, republish BOTH affected
// chapters in one publish invocation (identity survives either order; the
// batch shrinks the transient-absence window - see publish.js).
export function defaultLockPath(chapterDir) {
  return path.join(path.dirname(path.resolve(chapterDir)), "ids.lock");
}

export async function buildChapter(
  chapterDir,
  outDir,
  lockPath = defaultLockPath(chapterDir),
) {
  const source = JSON.parse(
    await readFile(path.join(chapterDir, "chapter.json"), "utf8"),
  );
  let lock;
  try {
    lock = JSON.parse(await readFile(lockPath, "utf8"));
  } catch {
    lock = { chapters: {}, qnas: {}, images: {} };
  }
  lock.chapters ??= {};
  lock.qnas ??= {};
  lock.images ??= {};
  const mint = (map, key) => (map[key] ??= ulid());

  if (!source.chapter?.key)
    throw new Error(
      `chapter "${source.chapter?.title ?? "?"}": missing "key" (permanent identity handle, see AUTHORING.md)`,
    );
  const chapterId = mint(lock.chapters, source.chapter.key);

  const canonical = {
    schema_version: 2,
    speciality_slug: source.speciality_slug,
    chapter: {
      id: chapterId,
      title: source.chapter.title,
      slug: source.chapter.slug,
      sort_order: source.chapter.sort_order,
      exam_weight: source.chapter.exam_weight,
    },
    qnas: [],
    images: [],
  };

  for (const qna of source.qnas ?? []) {
    if (!qna.key)
      throw new Error(
        `qna "${(qna.question ?? "?").slice(0, 40)}": missing "key" (permanent identity handle, see AUTHORING.md)`,
      );
    const qnaId = mint(lock.qnas, qna.key);
    canonical.qnas.push({
      id: qnaId,
      chapter_id: chapterId,
      question: qna.question,
      years: qna.years ?? null,
      marks: qna.marks ?? null,
      earns_marks: qna.earns_marks ?? [],
      sections: qna.sections,
      sort_order: qna.sort_order,
    });
    for (const img of qna.images ?? []) {
      const imageId = mint(lock.images, `${qna.key}/${img.file}`);
      const processed = await processImage(
        path.join(chapterDir, "images", img.file),
      );
      await mkdir(path.join(outDir, "images"), { recursive: true });
      await writeFile(
        path.join(outDir, "images", `${imageId}.webp`),
        processed,
      );
      canonical.images.push({
        id: imageId,
        qna_id: qnaId,
        caption: img.caption,
        content_description: img.content_description,
        file: `images/${imageId}.webp`,
        byte_size: processed.length,
        sha256: createHash("sha256").update(processed).digest("hex"),
        sort_order: img.sort_order,
      });
    }
  }

  await writeLock(lockPath, lock);
  await mkdir(outDir, { recursive: true });
  await writeFile(
    path.join(outDir, "chapter.json"),
    JSON.stringify(canonical, null, 2) + "\n",
  );
  return canonical;
}
```

`writeLock` drops the single-chapter field and the topics map:

```js
async function writeLock(lockPath, lock) {
  const stable = {
    chapters: sortKeys(lock.chapters),
    qnas: sortKeys(lock.qnas),
    images: sortKeys(lock.images),
  };
  await writeFile(lockPath, JSON.stringify(stable, null, 2) + "\n");
}
```

CLI block gains the optional third arg:

```js
  const [chapterDir, outDir, lockPath] = process.argv.slice(2);
  if (!chapterDir || !outDir) {
    console.error("usage: node src/build.js <chapterDir> <outDir> [lockPath]");
    process.exit(2);
  }
  try {
    const canonical = await buildChapter(chapterDir, outDir, lockPath);
```

- [ ] **Step 4: Run to verify build tests pass**

Run: `npm test`
Expected: `build.test.js` ALL PASS (including the untouched image tests). `validate`, `fixture`, `publish` remain red - next tasks.

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/build.js ingestion/test/build.test.js
git commit -m "feat(ingestion): speciality-level ids.lock + canonical v2 - moves keep ULIDs, zero-churn re-runs"
```

---

### Task 3: `validate.js` v2 + regression suite (IRON RULE rewrite 1 of 4)

**Files:**

- Modify: `ingestion/src/validate.js`
- Test: `ingestion/test/validate.test.js`

**Interfaces:**

- Consumes: canonical v2 (Task 2).
- Produces: `validateCanonical(dir) -> string[]` - empty means valid v2. New rules: `schema_version === 2`; a `topics` key present is an ERROR; `qnas[]` non-empty; every `qna.chapter_id === chapter.id`. All v1 section/earns_marks/image checks preserved verbatim. `publish.js` (Task 4) and the generator (lane D) gate on this.

- [ ] **Step 1: Rewrite the validate tests (failing first)**

In `ingestion/test/validate.test.js`: replace the file's canonical-fixture helper with a v2 builder, delete every topics-specific test, keep/adapt the section, earns_marks, slug, ULID-shape, and image tests (they change only in that the fixture has no topics and qnas carry `chapter_id`). Add this helper and the four v2 regression tests:

```js
function makeCanonical(mutate = () => {}) {
  const canonical = {
    schema_version: 2,
    speciality_slug: "anaesthesiology",
    chapter: {
      id: "01ARZ3NDEKTSV4RRFFQ69G5FAV",
      title: "Sample Chapter",
      slug: "sample-chapter",
      sort_order: 1,
      exam_weight: 10,
    },
    qnas: [
      {
        id: "01ARZ3NDEKTSV4RRFFQ69G5FB1",
        chapter_id: "01ARZ3NDEKTSV4RRFFQ69G5FAV",
        question: "Question one?",
        years: "2022",
        marks: 10,
        earns_marks: [{ label: "Definition point", section_key: "definition" }],
        sections: [
          { key: "definition", heading: "Definition", body_md: "Body one." },
        ],
        sort_order: 1,
      },
    ],
    images: [],
  };
  mutate(canonical);
  return canonical;
}

async function writeCanonicalDir(canonical) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-val-"));
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  return dir;
}

test("a valid v2 canonical passes", async () => {
  const errors = await validateCanonical(
    await writeCanonicalDir(makeCanonical()),
  );
  assert.deepEqual(errors, []);
});

test("REGRESSION: schema_version 1 is rejected", async () => {
  const errors = await validateCanonical(
    await writeCanonicalDir(makeCanonical((c) => (c.schema_version = 1))),
  );
  assert.ok(errors.some((e) => /schema_version: expected 2/.test(e)));
});

test("REGRESSION: a canonical carrying topics[] is rejected", async () => {
  const errors = await validateCanonical(
    await writeCanonicalDir(makeCanonical((c) => (c.topics = []))),
  );
  assert.ok(errors.some((e) => /topics: removed in schema v2/.test(e)));
});

test("REGRESSION: qna.chapter_id must match chapter.id", async () => {
  const errors = await validateCanonical(
    await writeCanonicalDir(
      makeCanonical(
        (c) => (c.qnas[0].chapter_id = "01ARZ3NDEKTSV4RRFFQ69G5FZZ"),
      ),
    ),
  );
  assert.ok(
    errors.some((e) =>
      /qnas\[0\]\.chapter_id: does not match chapter\.id/.test(e),
    ),
  );
});

test("REGRESSION: empty qnas[] is rejected (empty chapters never publish)", async () => {
  const errors = await validateCanonical(
    await writeCanonicalDir(makeCanonical((c) => (c.qnas = []))),
  );
  assert.ok(errors.some((e) => /qnas: must be a non-empty array/.test(e)));
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `npm test`
Expected: FAIL - `validate.js` still expects `schema_version === 1` and a non-empty `topics` array, so the "valid v2 passes" test reports those two errors, and the topics-rejection test finds no matching error string.

- [ ] **Step 3: Rewrite `validate.js`**

In `ingestion/src/validate.js` (imports, `isInt`/`nonEmpty`/`checkId` helpers, slug/ULID regexes, and the ENTIRE images block stay verbatim):

- Version pin:

```js
if (canonical.schema_version !== 2) {
  errors.push(
    `schema_version: expected 2, got ${JSON.stringify(canonical.schema_version ?? null)}`,
  );
}
```

- Immediately after the chapter checks, REPLACE the whole topics block (v1 lines 59-82) and the qna `topic_id` check with:

```js
  if ("topics" in canonical) {
    errors.push(
      "topics: removed in schema v2 - qnas hang directly off the chapter (sql/0004)",
    );
  }

  const qnas = Array.isArray(canonical.qnas) ? canonical.qnas : [];
  if (qnas.length === 0) errors.push("qnas: must be a non-empty array");
  const qnaIds = new Set();
  qnas.forEach((q, i) => {
    checkId(`qnas[${i}]`, q.id);
    if (q.chapter_id !== ch.id)
      errors.push(`qnas[${i}].chapter_id: does not match chapter.id`);
```

(the rest of the per-qna body - question, years, marks, sort_order, sections, earns_marks - is unchanged from v1).

- [ ] **Step 4: Run to verify validate tests pass**

Run: `npm test`
Expected: `validate.test.js` ALL PASS. `fixture` and `publish` still red.

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/validate.js ingestion/test/validate.test.js
git commit -m "feat(ingestion): validate v2 - rejects v1, topics[], chapter_id mismatch, empty qnas"
```

---

### Task 4: `publish.js` v2 - chapter_id deletes + batch republish (IRON RULE rewrite 2 of 4)

**Files:**

- Modify: `ingestion/src/publish.js`
- Test: `ingestion/test/publish.test.js`

**Interfaces:**

- Consumes: `validateCanonical` v2 (Task 3), post-0004 schema via `testClient()` (Task 1).
- Produces: `publishChapter(client, canonicalDir)` upserting chapter/qnas/images (NO topics), orphan-deleting images then qnas by `chapter_id`, bumping `content_version`, one transaction per chapter. CLI accepts MULTIPLE canonical dirs: `LICENSE_SIGNED=true node src/publish.js <dirA> <dirB> ... --allow-publish` (the batch-republish rule for cross-chapter moves). `gateCheck` UNCHANGED.

- [ ] **Step 1: Write the failing regression tests**

In `ingestion/test/publish.test.js`: the three `gateCheck` tests and the `publish rejects an invalid canonical dir` test stay VERBATIM (do not touch them). The existing fixture-publishing integration tests will pass again once the fixture migrates (Task 5); if any of them asserts topic rows, update those assertions to qna/chapter grain in this step. Add a canonical-builder helper and the two new integration tests (both follow the file's existing `skipDb` pattern: `test("...", { skip: skipDb }, async () => ...)`):

```js
import { testClient, TEST_SPECIALITY_ID } from "./db.js";

function canonicalV2({ chapterKeyId, qnas }) {
  return {
    schema_version: 2,
    speciality_slug: "anaesthesiology",
    chapter: {
      id: chapterKeyId,
      title: `Chapter ${chapterKeyId.slice(-2)}`,
      slug: `chapter-${chapterKeyId.slice(-2).toLowerCase()}`,
      sort_order: 1,
      exam_weight: 1,
    },
    qnas: qnas.map((q, i) => ({
      id: q.id,
      chapter_id: chapterKeyId,
      question: q.question,
      years: null,
      marks: null,
      earns_marks: [],
      sections: [
        { key: "summary", heading: "Summary", body_md: "Owned sample text." },
      ],
      sort_order: i + 1,
    })),
    images: [],
  };
}

async function writeCanonical(canonical) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-pub-"));
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  return dir;
}

const CH_A = "01ARZ3NDEKTSV4RRFFQ69G5CHA";
const CH_B = "01ARZ3NDEKTSV4RRFFQ69G5CHB";
const Q_MOVED = "01ARZ3NDEKTSV4RRFFQ69G5QMV";
const Q_STAYS = "01ARZ3NDEKTSV4RRFFQ69G5QST";

test(
  "REGRESSION: authoritative republish deletes dropped qnas + their images by chapter_id",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const two = canonicalV2({
        chapterKeyId: CH_A,
        qnas: [
          { id: Q_STAYS, question: "stays" },
          { id: Q_MOVED, question: "dropped" },
        ],
      });
      await publishChapter(client, await writeCanonical(two));
      await client.query(
        `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
       VALUES ('01ARZ3NDEKTSV4RRFFQ69G5IMG', $1, 'c', 'd', decode('52494646','hex'), 4, 'x', 1)`,
        [Q_MOVED],
      );
      const one = canonicalV2({
        chapterKeyId: CH_A,
        qnas: [{ id: Q_STAYS, question: "stays" }],
      });
      await publishChapter(client, await writeCanonical(one));
      const qnas = await client.query(
        `SELECT id FROM qnas WHERE chapter_id = $1`,
        [CH_A],
      );
      assert.deepEqual(
        qnas.rows.map((r) => r.id),
        [Q_STAYS],
      );
      const images = await client.query(
        `SELECT id FROM images WHERE qna_id = $1`,
        [Q_MOVED],
      );
      assert.equal(
        images.rowCount,
        0,
        "orphaned image must be deleted with its qna",
      );
    } finally {
      await client.end();
    }
  },
);

test(
  "a cross-chapter move keeps the qna ULID in EITHER republish order (amendment 1)",
  { skip: skipDb },
  async () => {
    for (const order of ["source-first", "target-first"]) {
      const client = await testClient(); // fresh schema per order
      try {
        const aWith = canonicalV2({
          chapterKeyId: CH_A,
          qnas: [{ id: Q_MOVED, question: "moving" }],
        });
        const bEmptyPlaceholder = canonicalV2({
          chapterKeyId: CH_B,
          qnas: [{ id: Q_STAYS, question: "anchor" }],
        });
        await publishChapter(client, await writeCanonical(aWith));
        await publishChapter(client, await writeCanonical(bEmptyPlaceholder));

        // The move: q leaves A, joins B - same ULID. A' must still validate, so
        // it keeps a replacement qna (empty chapters never publish).
        const aAfter = canonicalV2({
          chapterKeyId: CH_A,
          qnas: [{ id: "01ARZ3NDEKTSV4RRFFQ69G5QNW", question: "replacement" }],
        });
        const bAfter = canonicalV2({
          chapterKeyId: CH_B,
          qnas: [
            { id: Q_STAYS, question: "anchor" },
            { id: Q_MOVED, question: "moving" },
          ],
        });
        const batch =
          order === "source-first" ? [aAfter, bAfter] : [bAfter, aAfter];
        for (const canonical of batch) {
          await publishChapter(client, await writeCanonical(canonical));
        }
        const moved = await client.query(
          `SELECT chapter_id FROM qnas WHERE id = $1`,
          [Q_MOVED],
        );
        assert.equal(moved.rowCount, 1, `qna row survives the move (${order})`);
        assert.equal(
          moved.rows[0].chapter_id,
          CH_B,
          `qna belongs to the target (${order})`,
        );
      } finally {
        await client.end();
      }
    }
  },
);
```

- [ ] **Step 2: Run to verify they fail**

Run: `DATABASE_URL=<disposable> npm test`
Expected: both new tests FAIL - `publishChapter` still validates v1 (rejects the v2 canonical) and its SQL still walks `topics`.

- [ ] **Step 3: Rewrite `publish.js`**

In `ingestion/src/publish.js`, `gateCheck` stays byte-identical. Inside `publishChapter`'s transaction: DELETE the whole `for (const t of canonical.topics)` loop; change the qna upsert; replace the three orphan-deletes with two:

```js
for (const q of canonical.qnas) {
  await client.query(
    `INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
         ON CONFLICT (id) DO UPDATE SET
           chapter_id = EXCLUDED.chapter_id, question = EXCLUDED.question, years = EXCLUDED.years,
           marks = EXCLUDED.marks, earns_marks = EXCLUDED.earns_marks, sections = EXCLUDED.sections,
           sort_order = EXCLUDED.sort_order`,
    [
      q.id,
      q.chapter_id,
      q.question,
      q.years,
      q.marks,
      JSON.stringify(q.earns_marks),
      JSON.stringify(q.sections),
      q.sort_order,
    ],
  );
}
```

(the images upsert loop is unchanged), then:

```js
// A republish is authoritative for its chapter: rows dropped from the
// canonical set are deleted (FK-safe order: images -> qnas). Under the
// speciality ledger a qna moved to ANOTHER chapter has already been
// upserted with its new chapter_id by the batch, so the source chapter's
// delete never touches it (its chapter_id no longer matches $1).
await client.query(
  `DELETE FROM images WHERE qna_id IN (
         SELECT id FROM qnas WHERE chapter_id = $1
       ) AND id <> ALL($2::text[])`,
  [ch.id, canonical.images.map((i) => i.id)],
);
await client.query(
  `DELETE FROM qnas WHERE chapter_id = $1 AND id <> ALL($2::text[])`,
  [ch.id, canonical.qnas.map((q) => q.id)],
);
```

The `content_version` bump and COMMIT/ROLLBACK stay as they are.

CLI block: publish EVERY non-flag arg, in order (batch-republish rule - a cross-chapter move ships both chapters in ONE invocation; each chapter stays its own transaction, so the worst case is a brief absence window between the two, documented in the design):

```js
const args = process.argv.slice(2);
const dirs = args.filter((a) => !a.startsWith("--"));
if (dirs.length === 0) {
  console.error(
    "usage: LICENSE_SIGNED=true node src/publish.js <canonicalDir> [more dirs...] --allow-publish",
  );
  process.exit(2);
}
const refusal = gateCheck(args, process.env);
if (refusal) {
  console.error(refusal);
  process.exit(1);
}
if (!process.env.DATABASE_URL) {
  console.error("DATABASE_URL not set");
  process.exit(2);
}
const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
try {
  for (const dir of dirs) {
    const { chapterId, contentVersion } = await publishChapter(client, dir);
    console.log(
      `published chapter ${chapterId} at content_version ${contentVersion}`,
    );
  }
} catch (err) {
  console.error(`ERROR ${err.message}`);
  process.exitCode = 1;
} finally {
  await client.end();
}
```

- [ ] **Step 4: Run to verify publish tests pass**

Run: `DATABASE_URL=<disposable> npm test`
Expected: gate tests (untouched) PASS; both new integration tests PASS. Only `fixture.test.js` (and any fixture-publishing test) remains red until Task 5.

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/publish.js ingestion/test/publish.test.js
git commit -m "feat(ingestion): publish v2 - chapter_id orphan deletes, multi-dir batch CLI, gate untouched"
```

---

### Task 5: fixture migration (zero ULID churn) + AUTHORING.md rewrite + holding area

**Files:**

- Modify: `ingestion/fixtures/sample-chapter/chapter.json` (v2 authoring shape, slug fix)
- Create: `ingestion/fixtures/ids.lock` (speciality-level, ULIDs carried over)
- Delete: `ingestion/fixtures/sample-chapter/ids.lock`
- Modify: `ingestion/fixtures/canonical/sample-chapter/chapter.json` (rebuilt by build.js)
- Modify: `ingestion/AUTHORING.md` (full rewrite)
- Modify: `ingestion/.gitignore` (holding area)
- Test: `ingestion/test/fixture.test.js`

**Interfaces:**

- Consumes: build/validate v2 (Tasks 2-3).
- Produces: the committed de-branded fixture in v2 shape that lane C's parse tests and lane D's dry run consume; `ingestion/holding/` as the gitignored Miller-text holding area (amendment 3); AUTHORING.md as the authoring contract for lane D's emitter.

- [ ] **Step 1: Migrate the authoring fixture**

Replace `ingestion/fixtures/sample-chapter/chapter.json` with the v2 shape. Rules applied: `speciality_slug` fixed to `anaesthesiology`; `chapter.key` added (`"regional-anaesthesia-sample"` - matches the old lock's chapter identity); the two topics' qnas flatten in old (topic order, qna order): `spinal-definition`, `spinal-technique`, `pdph` with `sort_order` 1..3; every `key`, `question`, `years`, `marks`, `earns_marks`, `sections`, `images` field carried over VERBATIM from the current file, with ONE addition - the `spinal-definition` indications body gains the phrase "topical anaesthesia" (T19's sweep false-positive fixture). The exact indications `body_md` becomes:

```
Indications include lower-abdominal and lower-limb procedures where an awake technique is preferred, in contrast to surface procedures managed under topical anaesthesia. Contraindications include patient refusal, local infection at the puncture site, and uncorrected coagulopathy. Sample text, not licensed content.
```

Resulting file skeleton (bodies abbreviated HERE ONLY for plan readability - the real file carries the full current text):

```json
{
  "speciality_slug": "anaesthesiology",
  "chapter": {
    "key": "regional-anaesthesia-sample",
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
  "qnas": [
    { "key": "spinal-definition", "sort_order": 1, ... },
    { "key": "spinal-technique", "sort_order": 2, ... },
    { "key": "pdph", "sort_order": 3, ... }
  ]
}
```

- [ ] **Step 2: Write the speciality ledger PRESERVING every ULID**

Create `ingestion/fixtures/ids.lock` with the existing minted ULIDs carried over from `ingestion/fixtures/sample-chapter/ids.lock` (chapter ULID keyed by the new `chapter.key`; topics ULIDs die with the layer, by design - nothing referenced them outside the topics table):

```json
{
  "chapters": {
    "regional-anaesthesia-sample": "01KWRJV8K4PVHZXZZZCQCRKVMP"
  },
  "qnas": {
    "pdph": "01KWRJV8KJACRNDSG9Y7XDBDTC",
    "spinal-definition": "01KWRJV8K50XTN4DYZWGH5JJ39",
    "spinal-technique": "01KWRJV8KJA7G3G8XRNHC9QZDT"
  },
  "images": {
    "spinal-definition/spinal-levels.png": "01KWRJV8K5BXBBTMS47GPZPV4Q"
  }
}
```

Then delete the old per-chapter lock:

```bash
git rm ingestion/fixtures/sample-chapter/ids.lock
```

- [ ] **Step 3: Rebuild the canonical fixture and verify identity survived**

Run (from `ingestion/`):

```bash
node src/build.js fixtures/sample-chapter fixtures/canonical/sample-chapter
node src/validate.js fixtures/canonical/sample-chapter
git diff --stat ingestion/fixtures/ids.lock
```

Expected: build prints the SAME chapter ULID `01KWRJV8K4PVHZXZZZCQCRKVMP...` (3 qnas, 1 image); validate prints `OK`; `ids.lock` shows NO diff (zero churn - the build reused every ULID). The canonical `chapter.json` diff shows `schema_version: 2`, no `topics`, `chapter_id` on qnas, same qna/image ids. The image file `fixtures/canonical/sample-chapter/images/01KWRJV8K5BXBBTMS47GPZPV4Q.webp` is byte-identical (same source, same pipeline).

- [ ] **Step 4: Update `fixture.test.js` and run the FULL suite**

`ingestion/test/fixture.test.js` (1.6K) validates the committed canonical fixture. Update its expectations: `schema_version` 2, qna count 3 (unchanged), no `topics` key, `speciality_slug === "anaesthesiology"`, and - if it publishes the fixture - it now publishes against the seeded anaesthesiology row from `testClient()`. Then:

Run: `DATABASE_URL=<disposable> npm test`
Expected: ALL ingestion tests PASS - the lane-red window closes here.

- [ ] **Step 5: Rewrite AUTHORING.md**

Replace `ingestion/AUTHORING.md` in full:

````markdown
# DiploMate Content Authoring Format (schema v2)

Read this before writing or editing any chapter. The pipeline is
build -> validate -> publish (see CLI usage below). Identity rules here are
load-bearing: recall history hangs off the ULIDs this pipeline mints.

Schema v2 (2026-07-06, sql/0004): the topics layer is REMOVED. Questions
hang directly off chapters; chapters mirror the source book's own chapter
list (Miller's Anesthesia for Anaesthesiology).

## Directory layout

A SPECIALITY is a directory of chapter directories sharing ONE ledger:

```
<speciality-dir>/
  ids.lock          machine-written ULID ledger for the WHOLE speciality;
                    created by the first build; COMMITTED; never hand-edited.
                    One ledger per speciality means a question moved between
                    chapters keeps its ULID (chapter membership is placement,
                    not identity).
  <chapter-dir>/
    chapter.json    the chapter: metadata + qnas + image references
    images/         source images (png/jpg/webp; any size - the build
                    resizes/converts)
```

`chapter.json`:

```json
{
  "speciality_slug": "anaesthesiology",
  "chapter": {
    "key": "regional-anaesthesia-sample",
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
  "qnas": [
    {
      "key": "spinal-definition",
      "question": "Define spinal anaesthesia. List its indications and contraindications.",
      "years": "2019, 2022",
      "marks": 10,
      "sort_order": 1,
      "earns_marks": [
        {
          "label": "Definition of subarachnoid block",
          "section_key": "definition"
        }
      ],
      "sections": [
        { "key": "definition", "heading": "Definition", "body_md": "..." },
        { "key": "summary", "heading": "Summary", "body_md": "..." }
      ],
      "images": [
        {
          "file": "spinal-levels.png",
          "caption": "Vertebral levels relevant to spinal anaesthesia (sample diagram)",
          "content_description": "Sample placeholder panel standing in for a labelled vertebral column diagram.",
          "sort_order": 1
        }
      ]
    }
  ]
}
```

## Field rules

- `speciality_slug` - must match a slug seeded by `sql/0002_seed_specialities.sql`
  (beta content: `anaesthesiology`). The publisher resolves it to the seeded
  speciality ULID; it never creates specialities.
- `key` (chapter and qnas) - PERMANENT identity handle, unique within the
  SPECIALITY, never renamed once published. `ids.lock` maps keys to minted
  ULIDs; SR state hangs off those ULIDs. Renaming a `key` mints a new
  identity and orphans recall history - do not do it. Generated content keys
  are minted by the generator's ledger (first 16 hex chars of sha256 of the
  normalized question text, reconciled provenance-first on re-runs); hand
  content uses stable slugs.
- `slug`, `title` - mutable path metadata. Rename freely; identity is the ULID.
- Slug format: lowercase `a-z0-9` groups separated by single hyphens
  (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- `sections` - non-empty array; `key` unique within the qna; recommended keys
  follow the D16 answer anatomy: `definition`, `indications`, `technique`,
  `complications`, `summary` (free-form allowed; the validator checks shape,
  not vocabulary). `body_md` is Markdown. Book-grounded answers carry
  verbatim quotes with inline citation lines
  ("- Miller's Anesthesia, Ch.44, p.1413").
- `earns_marks` - the "What earns marks" outline; every `section_key` must
  match a `sections[].key` in the same qna. May be `[]`.
- `years` - optional freeform PYQ string, e.g. `"2019, 2022"`. `marks` -
  optional integer.
- `chapter.exam_weight` - yield signal: the SUM of year-appearances of the
  questions assigned to the chapter (a question asked 6 times contributes 6).
- `images[].file` - path relative to `<chapter-dir>/images/`. The build
  converts to WebP, resizes to fit 1600x1600, and re-encodes down the quality
  ladder (80, 60, 40) until <= 204800 bytes; if still over, the build fails.
  `caption` and `content_description` are mandatory (TalkBack, D20).

## Licensing: de-brand rule + holding area (amended 2026-07-06)

Founder-signed amendment (office hours + eng review amendment 3, 2026-07-06):

- The REPO and every DATABASE stay absolutely publisher-text-free until the
  Miller/Elsevier license is signed: no verbatim book text, no scanned
  figures, anywhere git tracks or publish writes.
- HOLDING-AREA GENERATION of licensed-source artifacts is explicitly allowed
  pre-license: the generator writes chapter.json drafts containing Miller
  text ONLY under `ingestion/holding/` (gitignored) and mirrors them to the
  same Google Drive folder that holds the book PDF. The PDF itself is never
  committed.
- `ids.lock` and the generator's key ledger contain ZERO publisher text and
  ARE committed - identity must survive even if the holding area is lost.
- Publishing to any database is additionally gated:
  `node src/publish.js <dir> --allow-publish` with env `LICENSE_SIGNED=true`.
  This gate is never weakened; it is the legal enforcement point.

## CLI usage

```
node src/build.js <chapterDir> <outDir> [lockPath]
    authoring -> canonical (mints/reuses ULIDs via the speciality ids.lock;
    lockPath defaults to <chapterDir>/../ids.lock)
node src/validate.js <canonicalDir>
    CI gate; exit 0 = OK, exit 1 = ERROR lines on stderr
LICENSE_SIGNED=true node src/publish.js <canonicalDir> [more dirs...] --allow-publish
    DATABASE_URL env required. After a cross-chapter move, pass BOTH affected
    chapters in ONE invocation (batch-republish rule): identity survives
    either order, and the batch shrinks the transient-absence window.
```

## Canonical output (schema v2)

`<outDir>/chapter.json` + `<outDir>/images/<image-ulid>.webp` mirror the DB
row shape:

```json
{
  "schema_version": 2,
  "speciality_slug": "anaesthesiology",
  "chapter": {"id": "<ULID>", "title": "...", "slug": "...", "sort_order": 1, "exam_weight": 10},
  "qnas": [{"id": "<ULID>", "chapter_id": "<ULID>", "question": "...", "years": "2019, 2022", "marks": 10, "earns_marks": [...], "sections": [...], "sort_order": 1}],
  "images": [{"id": "<ULID>", "qna_id": "<ULID>", "caption": "...", "content_description": "...", "file": "images/<ULID>.webp", "byte_size": 12345, "sha256": "<hex>", "sort_order": 1}]
}
```
````

- [ ] **Step 6: Gitignore the holding area**

`ingestion/.gitignore` becomes:

```
node_modules/
holding/
```

Verify the ledger stays trackable: `git check-ignore ingestion/fixtures/ids.lock` prints nothing (not ignored), `git check-ignore ingestion/holding/x` (hypothetical) matches.

- [ ] **Step 7: Run the lane sweep + full suite one last time**

```bash
grep -rniE 'topic_id|topic_count|topicId|topics?\b' ingestion/src ingestion/test ingestion/fixtures ingestion/AUTHORING.md | grep -viE 'topical|topic_opened'
cd ingestion && DATABASE_URL=<disposable> npm test
```

Expected: sweep prints ZERO lines (the fixture's "topical anaesthesia" survives only because the filter exempts it - that is T19's proof); suite ALL PASS.

- [ ] **Step 8: Commit**

```bash
git add ingestion/fixtures ingestion/AUTHORING.md ingestion/.gitignore ingestion/test/fixture.test.js
git rm --cached ingestion/fixtures/sample-chapter/ids.lock 2>/dev/null || true
git commit -m "feat(ingestion): v2 fixture (zero ULID churn) + AUTHORING v2 - anaesthesiology slug, de-brand amendment, holding area"
```

---

## Self-review checklist (run before handing the lane off)

- `gateCheck` is byte-identical to main (`git diff main -- ingestion/src/publish.js` shows no hunk touching it) and its three tests pass verbatim.
- `ingestion/fixtures/ids.lock` carries the four pre-existing ULIDs unchanged; `git log --follow` on the deleted per-chapter lock explains where they went.
- Both move-order publishes leave the moved qna present with its original ULID.
- The sweep grep is clean with the "topical anaesthesia" phrase present in the fixture.
- `AUTHORING.md` contains no `anaesthesia`-bare slug and documents: speciality ledger, batch republish, holding area, exam_weight = year-appearances.
