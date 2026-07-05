# Ingestion Pipeline (Lane A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the lane-A content ingestion CLI (`ingestion/`): build an authoring chapter directory into canonical JSON with stable minted ULIDs, validate it with exact CI checks (schema, WebP, 200KB/image, resolution cap), and publish it to Postgres in one idempotent transaction that bumps `chapters.content_version` - plus the committed de-branded fixture chapter that lanes B and D test against.

**Architecture:** Three small ESM modules with no shared state: `src/build.js` (authoring dir -> canonical JSON; identity minted once into a committed `ids.lock`), `src/validate.js` (pure checker returning an error-message array; the CI gate), `src/publish.js` (PG1-gated CLI; validates, then upserts specialities-resolved chapter/topics/qnas/images and bumps `content_version` in one `pg` transaction). The fixture chapter is committed twice: authoring source and built canonical output, so downstream lanes consume stable ULIDs without running the pipeline.

**Tech Stack:** Node 22 LTS, ESM, `node:test` runner, `ulid`, `sharp` (WebP conversion + resizing), `pg` (raw SQL, no ORM), GitHub Actions with a Postgres 16 service container.

## Global Constraints

Copied from the shared interface contract (`plan-contract.md`); every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, UI copy, or doc; plain hyphens only (user convention).
- NO offline Downloads feature (founder, 2026-07-04 evening): no bundle install/checksum machinery, no client-install per-row hashes, no 20MB bundle budget, no `pack_download_*` events. Content is served on demand; `chapters.content_version` (publisher-bumped) is the cache-invalidation key. This plan builds NO bundle hashing of any kind.
- Content IDs are ULIDs (26-char Crockford base32 TEXT) minted by the ingestion pipeline - opaque identity; slugs/titles are mutable path metadata (A4). SR state (review_events.content_id = QnA ULID) must survive every rebuild and republish, so minted IDs are locked in a committed `ids.lock`.
- Image laws (D8 as amended + D20): WebP only, `byte_size <= 204800` (matches DB CHECK `images_byte_size_check`), resolution cap 1600px on either edge (pipeline-chosen exact value; the contract caps resolution without a number), `caption` and `content_description` (TalkBack) mandatory, `sha256` of the WebP bytes stored as the HTTP ETag value.
- D16 schema coupling: answer section structure is encoded from the first ingested chapter. `qnas.sections` JSONB = `[{"key": "definition", "heading": "Definition", "body_md": "..."}]`; `qnas.earns_marks` JSONB = `[{"label": "...", "section_key": "definition"}]`, every `section_key` must reference an existing `sections[].key`.
- `sql/` DDL is the single schema truth. This plan consumes `sql/0001_content_v0.sql` (tables `app_config`, `specialities`, `chapters`, `topics`, `qnas`, `images`) and the Anaesthesia speciality seeded by `sql/0002_seed_specialities.sql` - both owned by plan `2026-07-04-day1-content-ddl.md`. Ingestion NEVER creates or updates speciality rows (their fixed ULIDs are seed-owned); the publisher resolves `speciality_id` by slug and refuses unknown slugs.
- PUBLISHING is PG1-gated (outside voice #2): `src/publish.js` refuses unless BOTH `--allow-publish` is passed AND env `LICENSE_SIGNED=true`. The pipeline itself (build/validate/tests/fixture) runs on de-branded owned sample content so lane A never blocks on the term sheet.
- Server/tooling stack lock: Node 22 LTS (`"engines": {"node": "22.x"}`), raw `pg` (no ORM). pg Pool max = 5 server-side; this CLI uses a single `pg.Client`.
- FREE BETA (PG3): nothing in this plan renders UI; no paywall or entitlement logic belongs in ingestion.
- `prototype/index.html` is a copy/structure reference only - NEVER modify it; its download lozenges are display-only legacy with no build obligation.
- TDD: every task = failing test -> run it (expect FAIL with reason) -> minimal implementation -> run (expect PASS) -> commit. Conventional-commit messages.

**Prerequisite:** Plan 1 (`2026-07-04-day1-content-ddl.md`) must be landed first - the publish integration tests apply `sql/0001_content_v0.sql` to a disposable Postgres. Build order per the locked plan verdict: day-1 v0 DDL (T20) precedes lane A.

**Working directory:** All `npm` / `node` commands below run from `/Users/nirmit/Codebases/DiploMate/ingestion/` unless a step says otherwise. Git commits run from the repo root.

---

## Authoring Format Spec (reference)

This is the exact JSON a content author writes. Task 1 commits it verbatim as `ingestion/AUTHORING.md`; it is reproduced here so every task can reference it without leaving the plan.

An authoring chapter is a directory:

```
<chapter-dir>/
  chapter.json      the whole chapter: metadata, topics, qnas, image references
  images/           source images (png, jpg, or webp; any size - the build resizes/converts)
  ids.lock          machine-written ULID ledger; created by the first build; COMMITTED; never hand-edited
```

`chapter.json`:

```json
{
  "speciality_slug": "anaesthesia",
  "chapter": {
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
  "topics": [
    {
      "key": "spinal-anaesthesia",
      "title": "Spinal Anaesthesia",
      "slug": "spinal-anaesthesia",
      "exam_theme": "Regional techniques",
      "sort_order": 1,
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
            },
            {
              "label": "Absolute contraindications",
              "section_key": "indications"
            }
          ],
          "sections": [
            { "key": "definition", "heading": "Definition", "body_md": "..." },
            {
              "key": "indications",
              "heading": "Indications and contraindications",
              "body_md": "..."
            },
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
  ]
}
```

Field rules:

- `speciality_slug` - must match a slug seeded by `sql/0002_seed_specialities.sql` (beta content: `anaesthesia`). The publisher resolves it to the seeded speciality ULID; it never creates specialities.
- `key` (topics and qnas) - PERMANENT identity handle, unique within the chapter, never renamed once published. `ids.lock` maps keys to minted ULIDs; SR state hangs off those ULIDs. Renaming a `key` mints a new identity and orphans recall history - do not do it.
- `slug`, `title` - mutable path metadata (A4). Rename freely; identity is the ULID.
- Slug format: lowercase `a-z0-9` groups separated by single hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- `sections` - non-empty array; `key` unique within the qna; recommended keys follow the D16 answer anatomy: `definition`, `indications`, `technique`, `complications`, `summary` (free-form allowed; the validator checks shape, not vocabulary). `body_md` is Markdown.
- `earns_marks` - the "What earns marks" outline; every `section_key` must match a `sections[].key` in the same qna. May be `[]`.
- `years` - optional freeform PYQ string, e.g. `"2019, 2022"`. `marks` - optional integer. `exam_theme` - optional string.
- `images[].file` - path relative to `<chapter-dir>/images/`. The build converts to WebP, resizes to fit 1600x1600, and re-encodes down the quality ladder (80, 60, 40) until <= 204800 bytes; if still over, the build fails. `caption` and `content_description` are mandatory (TalkBack, D20).
- De-brand rule (outside voice #2): until the content term sheet is signed (PG1), author ONLY de-branded owned sample content - no publisher text, no scanned figures. Publishing to any database is additionally gated: `node src/publish.js <dir> --allow-publish` with env `LICENSE_SIGNED=true`.

CLI usage:

```
node src/build.js <chapterDir> <outDir>        # authoring -> canonical (mints/reuses ULIDs via ids.lock)
node src/validate.js <canonicalDir>            # CI gate; exit 0 = OK, exit 1 = ERROR lines on stderr
LICENSE_SIGNED=true node src/publish.js <canonicalDir> --allow-publish   # DATABASE_URL env required
```

Canonical output (`<outDir>/chapter.json` + `<outDir>/images/<image-ulid>.webp`) mirrors the DB row shape:

```json
{
  "schema_version": 1,
  "speciality_slug": "anaesthesia",
  "chapter": {"id": "<ULID>", "title": "...", "slug": "...", "sort_order": 1, "exam_weight": 10},
  "topics": [{"id": "<ULID>", "chapter_id": "<ULID>", "title": "...", "slug": "...", "exam_theme": "...", "sort_order": 1}],
  "qnas": [{"id": "<ULID>", "topic_id": "<ULID>", "question": "...", "years": "2019, 2022", "marks": 10, "earns_marks": [...], "sections": [...], "sort_order": 1}],
  "images": [{"id": "<ULID>", "qna_id": "<ULID>", "caption": "...", "content_description": "...", "file": "images/<ULID>.webp", "byte_size": 12345, "sha256": "<hex>", "sort_order": 1}]
}
```

---

### Task 1: Package scaffold + committed authoring spec

**Files:**

- Create: `ingestion/package.json`
- Create: `ingestion/.gitignore`
- Create: `ingestion/AUTHORING.md`
- Create: `ingestion/package-lock.json` (generated by `npm install`, committed)

**Interfaces:**

- Consumes: nothing (first lane-A commit).
- Produces: the `ingestion/` npm package every later task installs into; `npm test` = `node --test` (discovers `ingestion/test/*.test.js`); dependencies `ulid`, `sharp`, `pg` available to `src/*.js`.

- [ ] **Step 1: Write `ingestion/package.json`**

```json
{
  "name": "diplomate-ingestion",
  "private": true,
  "type": "module",
  "engines": {
    "node": "22.x"
  },
  "scripts": {
    "test": "node --test"
  },
  "dependencies": {
    "pg": "^8.12.0",
    "sharp": "^0.33.4",
    "ulid": "^2.3.0"
  }
}
```

- [ ] **Step 2: Write `ingestion/.gitignore`**

```
node_modules/
```

- [ ] **Step 3: Write `ingestion/AUTHORING.md`**

Copy the entire "Authoring Format Spec (reference)" section above (from "An authoring chapter is a directory:" through the canonical output JSON block) verbatim into `ingestion/AUTHORING.md`, preceded by this heading:

```markdown
# DiploMate Content Authoring Format

Read this before writing or editing any chapter. The pipeline is
build -> validate -> publish (see CLI usage below). Identity rules here are
load-bearing: recall history hangs off the ULIDs this pipeline mints.
```

- [ ] **Step 4: Install dependencies and verify they load**

Run: `npm install` (in `ingestion/`)
Expected: exit 0, `added N packages` (sharp downloads a prebuilt binary; needs network).

Run: `node -e "require('ulid'); require('sharp'); require('pg'); console.log('deps ok')"`
Expected: `deps ok`

- [ ] **Step 5: Commit**

```bash
git add ingestion/package.json ingestion/package-lock.json ingestion/.gitignore ingestion/AUTHORING.md
git commit -m "feat(ingestion): scaffold lane-A package + authoring format spec"
```

---

### Task 2: build.js - ULID minting, ids.lock stability, canonical text rows

**Files:**

- Create: `ingestion/src/build.js`
- Test: `ingestion/test/build.test.js`

**Interfaces:**

- Consumes: `ulid` package (`ulid(): string`, 26-char Crockford base32 uppercase).
- Produces: `export async function buildChapter(chapterDir, outDir)` -> resolves to the canonical object (shape in the Authoring Format Spec) and writes `<outDir>/chapter.json` plus `<chapterDir>/ids.lock`. `ids.lock` shape: `{"chapter": "<ULID>", "topics": {"<topic-key>": "<ULID>"}, "qnas": {"<qna-key>": "<ULID>"}, "images": {"<qna-key>/<source-file>": "<ULID>"}}`. Task 3 extends this same file with image processing; Task 5 builds the committed fixture with it.

- [ ] **Step 1: Write the failing tests**

`ingestion/test/build.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { buildChapter } from "../src/build.js";

const ULID_RE = /^[0-9A-HJKMNP-TV-Z]{26}$/;

function sourceChapter() {
  return {
    speciality_slug: "anaesthesia",
    chapter: {
      title: "Sample Chapter",
      slug: "sample-chapter",
      sort_order: 1,
      exam_weight: 10,
    },
    topics: [
      {
        key: "topic-one",
        title: "Topic One",
        slug: "topic-one",
        exam_theme: "Theme one",
        sort_order: 1,
        qnas: [
          {
            key: "q-one",
            question: "Question one?",
            years: "2022",
            marks: 10,
            sort_order: 1,
            earns_marks: [
              { label: "Definition point", section_key: "definition" },
            ],
            sections: [
              {
                key: "definition",
                heading: "Definition",
                body_md: "Body one.",
              },
            ],
            images: [],
          },
        ],
      },
    ],
  };
}

async function makeChapterDir(source) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-src-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(source, null, 2),
  );
  return dir;
}

async function makeOutDir() {
  return mkdtemp(path.join(tmpdir(), "ingest-out-"));
}

test("build mints ULIDs and writes ids.lock", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const canonical = await buildChapter(dir, await makeOutDir());
  assert.match(canonical.chapter.id, ULID_RE);
  assert.match(canonical.topics[0].id, ULID_RE);
  assert.match(canonical.qnas[0].id, ULID_RE);
  assert.equal(canonical.topics[0].chapter_id, canonical.chapter.id);
  assert.equal(canonical.qnas[0].topic_id, canonical.topics[0].id);
  const lock = JSON.parse(await readFile(path.join(dir, "ids.lock"), "utf8"));
  assert.equal(lock.chapter, canonical.chapter.id);
  assert.equal(lock.topics["topic-one"], canonical.topics[0].id);
  assert.equal(lock.qnas["q-one"], canonical.qnas[0].id);
});

test("rebuild reuses locked ids (stable across rebuilds)", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const first = await buildChapter(dir, await makeOutDir());
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.chapter.id, first.chapter.id);
  assert.deepEqual(
    second.topics.map((t) => t.id),
    first.topics.map((t) => t.id),
  );
  assert.deepEqual(
    second.qnas.map((q) => q.id),
    first.qnas.map((q) => q.id),
  );
});

test("adding a qna preserves existing ids and mints only the new one", async () => {
  const source = sourceChapter();
  const dir = await makeChapterDir(source);
  const first = await buildChapter(dir, await makeOutDir());
  source.topics[0].qnas.push({
    key: "q-two",
    question: "Question two?",
    years: null,
    marks: 5,
    sort_order: 2,
    earns_marks: [],
    sections: [{ key: "summary", heading: "Summary", body_md: "Body two." }],
    images: [],
  });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(source, null, 2),
  );
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.qnas[0].id, first.qnas[0].id);
  assert.match(second.qnas[1].id, ULID_RE);
  assert.notEqual(second.qnas[1].id, second.qnas[0].id);
});

test("canonical text row shape matches the DB columns", async () => {
  const dir = await makeChapterDir(sourceChapter());
  const canonical = await buildChapter(dir, await makeOutDir());
  assert.equal(canonical.schema_version, 1);
  assert.equal(canonical.speciality_slug, "anaesthesia");
  assert.deepEqual(Object.keys(canonical.chapter).sort(), [
    "exam_weight",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
  assert.deepEqual(Object.keys(canonical.topics[0]).sort(), [
    "chapter_id",
    "exam_theme",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
  assert.deepEqual(Object.keys(canonical.qnas[0]).sort(), [
    "earns_marks",
    "id",
    "marks",
    "question",
    "sections",
    "sort_order",
    "topic_id",
    "years",
  ]);
  const out = JSON.parse(
    await readFile(path.join(await (async () => dir)(), "ids.lock"), "utf8"),
  );
  assert.ok(out.images);
});

test("a qna without a key fails the build", async () => {
  const source = sourceChapter();
  delete source.topics[0].qnas[0].key;
  const dir = await makeChapterDir(source);
  await assert.rejects(() => buildChapter(dir, ""), /missing "key"/);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test`
Expected: FAIL - `Cannot find module '../src/build.js'` (all 5 tests error), summary contains `# fail` / `# cancelled` counts greater than 0.

- [ ] **Step 3: Write `ingestion/src/build.js`**

```js
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ulid } from "ulid";

export async function buildChapter(chapterDir, outDir) {
  const source = JSON.parse(
    await readFile(path.join(chapterDir, "chapter.json"), "utf8"),
  );
  const lockPath = path.join(chapterDir, "ids.lock");
  let lock;
  try {
    lock = JSON.parse(await readFile(lockPath, "utf8"));
  } catch {
    lock = { chapter: null, topics: {}, qnas: {}, images: {} };
  }
  lock.topics ??= {};
  lock.qnas ??= {};
  lock.images ??= {};
  lock.chapter ??= ulid();
  const mint = (map, key) => (map[key] ??= ulid());

  const canonical = {
    schema_version: 1,
    speciality_slug: source.speciality_slug,
    chapter: {
      id: lock.chapter,
      title: source.chapter.title,
      slug: source.chapter.slug,
      sort_order: source.chapter.sort_order,
      exam_weight: source.chapter.exam_weight,
    },
    topics: [],
    qnas: [],
    images: [],
  };

  for (const topic of source.topics ?? []) {
    if (!topic.key)
      throw new Error(
        `topic "${topic.title ?? "?"}": missing "key" (permanent identity handle, see AUTHORING.md)`,
      );
    const topicId = mint(lock.topics, topic.key);
    canonical.topics.push({
      id: topicId,
      chapter_id: lock.chapter,
      title: topic.title,
      slug: topic.slug,
      exam_theme: topic.exam_theme ?? null,
      sort_order: topic.sort_order,
    });
    for (const qna of topic.qnas ?? []) {
      if (!qna.key)
        throw new Error(
          `qna "${(qna.question ?? "?").slice(0, 40)}": missing "key" (permanent identity handle, see AUTHORING.md)`,
        );
      const qnaId = mint(lock.qnas, qna.key);
      canonical.qnas.push({
        id: qnaId,
        topic_id: topicId,
        question: qna.question,
        years: qna.years ?? null,
        marks: qna.marks ?? null,
        earns_marks: qna.earns_marks ?? [],
        sections: qna.sections,
        sort_order: qna.sort_order,
      });
      // Task 3 wires image processing into this loop.
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

const sortKeys = (obj) =>
  Object.fromEntries(Object.entries(obj).sort(([a], [b]) => (a < b ? -1 : 1)));

async function writeLock(lockPath, lock) {
  const stable = {
    chapter: lock.chapter,
    topics: sortKeys(lock.topics),
    qnas: sortKeys(lock.qnas),
    images: sortKeys(lock.images),
  };
  await writeFile(lockPath, JSON.stringify(stable, null, 2) + "\n");
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const [chapterDir, outDir] = process.argv.slice(2);
  if (!chapterDir || !outDir) {
    console.error("usage: node src/build.js <chapterDir> <outDir>");
    process.exit(2);
  }
  try {
    const canonical = await buildChapter(chapterDir, outDir);
    console.log(
      `built chapter ${canonical.chapter.id} (${canonical.qnas.length} qnas, ${canonical.images.length} images)`,
    );
  } catch (err) {
    console.error(`ERROR ${err.message}`);
    process.exit(1);
  }
}
```

Note the `buildChapter(dir, '')` call in the missing-key test: the key check throws before any output is written, so the empty outDir is never used.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test`
Expected: PASS - summary contains `# pass 5` and `# fail 0`.

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/build.js ingestion/test/build.test.js
git commit -m "feat(ingestion): build.js mints stable ULIDs via committed ids.lock"
```

---

### Task 3: build.js - image processing (WebP, resize, size ladder, sha256)

**Files:**

- Modify: `ingestion/src/build.js`
- Test: `ingestion/test/build.test.js` (append)

**Interfaces:**

- Consumes: `buildChapter` from Task 2; `sharp` package.
- Produces: `export async function processImage(sourcePath)` -> `Promise<Buffer>` (WebP, both edges <= 1600px, length <= 204800, throws `image <sourcePath> exceeds 204800 bytes at lowest quality` otherwise); `buildChapter` now emits `canonical.images` rows `{id, qna_id, caption, content_description, file: "images/<ULID>.webp", byte_size, sha256, sort_order}` and writes `<outDir>/images/<ULID>.webp`. Exported constants `MAX_IMAGE_BYTES = 204800`, `MAX_IMAGE_EDGE = 1600` (Task 4's validator imports nothing from here - it declares its own copies so the validator stays a standalone CI gate; the values must match).

- [ ] **Step 1: Append the failing tests**

Append to `ingestion/test/build.test.js`:

```js
import sharp from 'sharp';
import {randomBytes, createHash} from 'node:crypto';

function sourceChapterWithImage(fileName) {
  const source = sourceChapter();
  source.topics[0].qnas[0].images = [
    {
      file: fileName,
      caption: 'Sample diagram',
      content_description: 'A plain sample panel used as a placeholder diagram.',
      sort_order: 1
    }
  ];
  return source;
}

test('images are converted to capped WebP with sha256 and byte_size', async () => {
  const dir = await makeChapterDir(sourceChapterWithImage('big.png'));
  const png = await sharp({create: {width: 2400, height: 1800, channels: 3, background: {r: 200, g: 220, b: 230}}})
    .png().toBuffer();
  await writeFile(path.join(dir, 'images', 'big.png'), png);
  const outDir = await makeOutDir();
  const canonical = await buildChapter(dir, outDir);

  assert.equal(canonical.images.length, 1);
  const img = canonical.images[0];
  assert.match(img.id, ULID_RE);
  assert.equal(img.qna_id, canonical.qnas[0].id);
  assert.equal(img.file, `images/${img.id}.webp`);
  const bytes = await readFile(path.join(outDir, img.file));
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP');
  assert.equal(img.byte_size, bytes.length);
  assert.ok(bytes.length <= 204800, `image is ${bytes.length} bytes`);
  assert.equal(img.sha256, createHash('sha256').update(bytes).digest('hex'));
  const meta = await sharp(bytes).metadata();
  assert.ok(meta.width <= 1600 && meta.height <= 1600, `resized to ${meta.width}x${meta.height}`);
});

test('image ULID is stable across rebuilds', async () => {
  const dir = await makeChapterDir(sourceChapterWithImage('big.png'));
  const png = await sharp({create: {width: 800, height: 600, channels: 3, background: {r: 210, g: 210, b: 210}}})
    .png().toBuffer();
  await writeFile(path.join(dir, 'images', 'big.png'), png);
  const first = await buildChapter(dir, await makeOutDir());
  const second = await buildChapter(dir, await makeOutDir());
  assert.equal(second.images[0].id, first.images[0].id);
});

test('an incompressible image over the cap fails the build', async () => {
  const dir = await makeChapterDir(sourceChapterWithImage('noise.png'));
  // Random noise is incompressible; at 1600x1600 even quality 40 WebP stays over 200KB.
  const noise = await sharp(randomBytes(1600 * 1600 * 3), {raw: {width: 1600, height: 1600, channels: 3}})
    .png().toBuffer();
  await writeFile(path.join(dir, 'images', 'noise.png'), noise);
  await assert.rejects(
    () => buildChapter(dir, await makeOutDir()),
    /exceeds 204800 bytes at lowest quality/
  );
});
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `npm test`
Expected: FAIL - the three new tests fail; first with `canonical.images.length` = 0 (assert.equal 0 !== 1), the stability test with `Cannot read properties of undefined` or empty images, the noise test with `Missing expected rejection`. The 5 Task 2 tests still pass.

- [ ] **Step 3: Extend `ingestion/src/build.js`**

Add imports and constants at the top of the file:

```js
import { createHash } from "node:crypto";
import sharp from "sharp";

export const MAX_IMAGE_BYTES = 204800;
export const MAX_IMAGE_EDGE = 1600;
const WEBP_QUALITIES = [80, 60, 40];
```

Add the exported function (below `buildChapter`):

```js
export async function processImage(sourcePath) {
  for (const quality of WEBP_QUALITIES) {
    const buf = await sharp(sourcePath)
      .rotate()
      .resize({
        width: MAX_IMAGE_EDGE,
        height: MAX_IMAGE_EDGE,
        fit: "inside",
        withoutEnlargement: true,
      })
      .webp({ quality })
      .toBuffer();
    if (buf.length <= MAX_IMAGE_BYTES) return buf;
  }
  throw new Error(
    `image ${sourcePath} exceeds ${MAX_IMAGE_BYTES} bytes at lowest quality`,
  );
}
```

Replace the `// Task 3 wires image processing into this loop.` comment inside the qna loop with:

```js
for (const img of qna.images ?? []) {
  const imageId = mint(lock.images, `${qna.key}/${img.file}`);
  const processed = await processImage(
    path.join(chapterDir, "images", img.file),
  );
  await mkdir(path.join(outDir, "images"), { recursive: true });
  await writeFile(path.join(outDir, "images", `${imageId}.webp`), processed);
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test`
Expected: PASS - summary contains `# pass 8` and `# fail 0`.

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/build.js ingestion/test/build.test.js
git commit -m "feat(ingestion): WebP conversion with 1600px and 200KB caps via sharp"
```

---

### Task 4: validate.js - the CI gate with exact error messages

**Files:**

- Create: `ingestion/src/validate.js`
- Test: `ingestion/test/validate.test.js`

**Interfaces:**

- Consumes: canonical output shape produced by Task 3's `buildChapter` (but validates any directory - it is the trust boundary for CI, so it re-checks everything from bytes up).
- Produces: `export async function validateCanonical(dir)` -> `Promise<string[]>` (empty array = valid; each string is one exact error message below). CLI: `node src/validate.js <canonicalDir>` prints `ERROR <message>` per error to stderr and exits 1, or prints `OK <dir>: <n> qnas, <m> images validated` and exits 0. Task 6's publisher and Task 7's CI both call this. Exported constants `MAX_IMAGE_BYTES = 204800`, `MAX_IMAGE_EDGE = 1600`.

Error message catalog (exact formats; `JSON.stringify` renders the offending value):

```
chapter.json: unreadable or not valid JSON (<detail>)
schema_version: expected 1, got <value>
speciality_slug: <value> is not a valid slug
chapter.id: <value> is not a ULID
<label>.id: duplicate id <value>
chapter.title: missing or empty
chapter.slug: <value> is not a valid slug
chapter.sort_order: not an integer
chapter.exam_weight: not an integer
topics: must be a non-empty array
topics[i].id: <value> is not a ULID
topics[i].chapter_id: does not match chapter.id
topics[i].title: missing or empty
topics[i].slug: <value> is not a valid slug
topics: duplicate slug <value>
topics[i].exam_theme: must be a non-empty string or null
topics[i].sort_order: not an integer
qnas: must be a non-empty array
qnas[i].id: <value> is not a ULID
qnas[i].topic_id: <value> does not match any topics[].id
qnas[i].question: missing or empty
qnas[i].years: must be a non-empty string or null
qnas[i].marks: must be an integer or null
qnas[i].sort_order: not an integer
qnas[i].sections: must be a non-empty array
qnas[i].sections[j].key: missing or empty
qnas[i].sections: duplicate key <value>
qnas[i].sections[j].heading: missing or empty
qnas[i].sections[j].body_md: missing or empty
qnas[i].earns_marks: must be an array
qnas[i].earns_marks[j].label: missing or empty
qnas[i].earns_marks[j].section_key: <value> does not match any sections[].key
images: must be an array
images[i].id: <value> is not a ULID
images[i].qna_id: <value> does not match any qnas[].id
images[i].caption: missing or empty
images[i].content_description: missing or empty
images[i].sort_order: not an integer
images[i].file: missing or empty
images[i].file: <path> not found
images[i]: not a WebP file
images[i].byte_size: <n> does not match file size <m>
images[i]: byte_size <n> exceeds 204800
images[i].sha256: does not match file contents
images[i]: width <w> exceeds 1600
images[i]: height <h> exceeds 1600
images[i]: unreadable image data
```

- [ ] **Step 1: Write the failing tests**

`ingestion/test/validate.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { ulid } from "ulid";
import sharp from "sharp";
import { validateCanonical } from "../src/validate.js";

async function smallWebp(width = 400, height = 300) {
  return sharp({
    create: {
      width,
      height,
      channels: 3,
      background: { r: 214, g: 234, b: 236 },
    },
  })
    .webp({ quality: 80 })
    .toBuffer();
}

async function validCanonical() {
  const chapterId = ulid();
  const topicId = ulid();
  const qnaId = ulid();
  const imageId = ulid();
  const webp = await smallWebp();
  return {
    canonical: {
      schema_version: 1,
      speciality_slug: "anaesthesia",
      chapter: {
        id: chapterId,
        title: "Chapter",
        slug: "chapter",
        sort_order: 1,
        exam_weight: 10,
      },
      topics: [
        {
          id: topicId,
          chapter_id: chapterId,
          title: "Topic",
          slug: "topic",
          exam_theme: null,
          sort_order: 1,
        },
      ],
      qnas: [
        {
          id: qnaId,
          topic_id: topicId,
          question: "Q?",
          years: "2022",
          marks: 10,
          earns_marks: [{ label: "Point", section_key: "definition" }],
          sections: [
            { key: "definition", heading: "Definition", body_md: "Body." },
          ],
          sort_order: 1,
        },
      ],
      images: [
        {
          id: imageId,
          qna_id: qnaId,
          caption: "Caption",
          content_description: "Description for TalkBack.",
          file: `images/${imageId}.webp`,
          byte_size: webp.length,
          sha256: createHash("sha256").update(webp).digest("hex"),
          sort_order: 1,
        },
      ],
    },
    files: { [`images/${imageId}.webp`]: webp },
  };
}

async function writeCanonicalDir({ canonical, files }) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-canon-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  for (const [rel, bytes] of Object.entries(files)) {
    await writeFile(path.join(dir, rel), bytes);
  }
  return dir;
}

test("a valid canonical dir returns zero errors", async () => {
  const dir = await writeCanonicalDir(await validCanonical());
  assert.deepEqual(await validateCanonical(dir), []);
});

test("earns_marks pointing at a missing section key is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.qnas[0].earns_marks[0].section_key = "technique";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    'qnas[0].earns_marks[0].section_key: "technique" does not match any sections[].key',
  ]);
});

test("empty sections array is rejected (D16 coupling)", async () => {
  const c = await validCanonical();
  c.canonical.qnas[0].sections = [];
  c.canonical.qnas[0].earns_marks = [];
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "qnas[0].sections: must be a non-empty array",
  ]);
});

test("bad slug is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.chapter.slug = "Bad Slug";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    'chapter.slug: "Bad Slug" is not a valid slug',
  ]);
});

test("non-ULID id is exact-messaged", async () => {
  const c = await validCanonical();
  c.canonical.topics[0].id = "not-a-ulid";
  const dir = await writeCanonicalDir(c);
  const errors = await validateCanonical(dir);
  assert.ok(
    errors.includes('topics[0].id: "not-a-ulid" is not a ULID'),
    errors.join("\n"),
  );
});

test("missing content_description is rejected (D20)", async () => {
  const c = await validCanonical();
  c.canonical.images[0].content_description = "";
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0].content_description: missing or empty",
  ]);
});

test("a non-WebP image file is rejected", async () => {
  const c = await validCanonical();
  const png = await sharp({
    create: {
      width: 40,
      height: 30,
      channels: 3,
      background: { r: 0, g: 0, b: 0 },
    },
  })
    .png()
    .toBuffer();
  const rel = c.canonical.images[0].file;
  c.files[rel] = png;
  c.canonical.images[0].byte_size = png.length;
  c.canonical.images[0].sha256 = createHash("sha256").update(png).digest("hex");
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0]: not a WebP file",
  ]);
});

test("byte_size mismatch and stale sha256 are both reported", async () => {
  const c = await validCanonical();
  c.canonical.images[0].byte_size = c.canonical.images[0].byte_size + 1;
  c.canonical.images[0].sha256 = "deadbeef";
  const trueSize = c.files[c.canonical.images[0].file].length;
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    `images[0].byte_size: ${trueSize + 1} does not match file size ${trueSize}`,
    "images[0].sha256: does not match file contents",
  ]);
});

test("missing image file is exact-messaged", async () => {
  const c = await validCanonical();
  const rel = c.canonical.images[0].file;
  delete c.files[rel];
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    `images[0].file: ${rel} not found`,
  ]);
});

test("oversize image is rejected with the 204800 cap named", async () => {
  const c = await validCanonical();
  // 1500x1500 photographic-noise WebP at quality 95 lands well over 200KB while staying under the edge cap.
  const { randomBytes } = await import("node:crypto");
  const big = await sharp(randomBytes(1500 * 1500 * 3), {
    raw: { width: 1500, height: 1500, channels: 3 },
  })
    .webp({ quality: 95 })
    .toBuffer();
  const rel = c.canonical.images[0].file;
  c.files[rel] = big;
  c.canonical.images[0].byte_size = big.length;
  c.canonical.images[0].sha256 = createHash("sha256").update(big).digest("hex");
  const dir = await writeCanonicalDir(c);
  const errors = await validateCanonical(dir);
  assert.deepEqual(errors, [
    `images[0]: byte_size ${big.length} exceeds 204800`,
  ]);
});

test("image wider than 1600px is rejected", async () => {
  const c = await validCanonical();
  const wide = await smallWebp(1800, 400);
  const rel = c.canonical.images[0].file;
  c.files[rel] = wide;
  c.canonical.images[0].byte_size = wide.length;
  c.canonical.images[0].sha256 = createHash("sha256")
    .update(wide)
    .digest("hex");
  const dir = await writeCanonicalDir(c);
  assert.deepEqual(await validateCanonical(dir), [
    "images[0]: width 1800 exceeds 1600",
  ]);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test`
Expected: FAIL - `Cannot find module '../src/validate.js'`; the 8 build tests still pass.

- [ ] **Step 3: Write `ingestion/src/validate.js`**

```js
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

export const MAX_IMAGE_BYTES = 204800;
export const MAX_IMAGE_EDGE = 1600;
const ULID_RE = /^[0-9A-HJKMNP-TV-Z]{26}$/;
const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export async function validateCanonical(dir) {
  const errors = [];
  let canonical;
  try {
    canonical = JSON.parse(
      await readFile(path.join(dir, "chapter.json"), "utf8"),
    );
  } catch (err) {
    return [`chapter.json: unreadable or not valid JSON (${err.message})`];
  }

  const isInt = (v) => Number.isInteger(v);
  const nonEmpty = (v) => typeof v === "string" && v.trim().length > 0;
  const seenIds = new Set();
  const checkId = (label, id) => {
    if (!ULID_RE.test(id ?? ""))
      errors.push(`${label}.id: ${JSON.stringify(id ?? null)} is not a ULID`);
    else if (seenIds.has(id))
      errors.push(`${label}.id: duplicate id ${JSON.stringify(id)}`);
    seenIds.add(id);
  };

  if (canonical.schema_version !== 1) {
    errors.push(
      `schema_version: expected 1, got ${JSON.stringify(canonical.schema_version ?? null)}`,
    );
  }
  if (
    !nonEmpty(canonical.speciality_slug) ||
    !SLUG_RE.test(canonical.speciality_slug)
  ) {
    errors.push(
      `speciality_slug: ${JSON.stringify(canonical.speciality_slug ?? null)} is not a valid slug`,
    );
  }

  const ch = canonical.chapter ?? {};
  checkId("chapter", ch.id);
  if (!nonEmpty(ch.title)) errors.push("chapter.title: missing or empty");
  if (!SLUG_RE.test(ch.slug ?? ""))
    errors.push(
      `chapter.slug: ${JSON.stringify(ch.slug ?? null)} is not a valid slug`,
    );
  if (!isInt(ch.sort_order)) errors.push("chapter.sort_order: not an integer");
  if (!isInt(ch.exam_weight))
    errors.push("chapter.exam_weight: not an integer");

  const topics = Array.isArray(canonical.topics) ? canonical.topics : [];
  if (topics.length === 0) errors.push("topics: must be a non-empty array");
  const topicIds = new Set();
  const topicSlugs = new Set();
  topics.forEach((t, i) => {
    checkId(`topics[${i}]`, t.id);
    if (t.chapter_id !== ch.id)
      errors.push(`topics[${i}].chapter_id: does not match chapter.id`);
    if (!nonEmpty(t.title)) errors.push(`topics[${i}].title: missing or empty`);
    if (!SLUG_RE.test(t.slug ?? ""))
      errors.push(
        `topics[${i}].slug: ${JSON.stringify(t.slug ?? null)} is not a valid slug`,
      );
    else if (topicSlugs.has(t.slug))
      errors.push(`topics: duplicate slug ${JSON.stringify(t.slug)}`);
    topicSlugs.add(t.slug);
    if (t.exam_theme != null && !nonEmpty(t.exam_theme))
      errors.push(
        `topics[${i}].exam_theme: must be a non-empty string or null`,
      );
    if (!isInt(t.sort_order))
      errors.push(`topics[${i}].sort_order: not an integer`);
    topicIds.add(t.id);
  });

  const qnas = Array.isArray(canonical.qnas) ? canonical.qnas : [];
  if (qnas.length === 0) errors.push("qnas: must be a non-empty array");
  const qnaIds = new Set();
  qnas.forEach((q, i) => {
    checkId(`qnas[${i}]`, q.id);
    if (!topicIds.has(q.topic_id))
      errors.push(
        `qnas[${i}].topic_id: ${JSON.stringify(q.topic_id ?? null)} does not match any topics[].id`,
      );
    if (!nonEmpty(q.question))
      errors.push(`qnas[${i}].question: missing or empty`);
    if (q.years != null && !nonEmpty(q.years))
      errors.push(`qnas[${i}].years: must be a non-empty string or null`);
    if (q.marks != null && !isInt(q.marks))
      errors.push(`qnas[${i}].marks: must be an integer or null`);
    if (!isInt(q.sort_order))
      errors.push(`qnas[${i}].sort_order: not an integer`);

    const sections = Array.isArray(q.sections) ? q.sections : [];
    if (sections.length === 0)
      errors.push(`qnas[${i}].sections: must be a non-empty array`);
    const sectionKeys = new Set();
    sections.forEach((s, j) => {
      if (!nonEmpty(s.key))
        errors.push(`qnas[${i}].sections[${j}].key: missing or empty`);
      else if (sectionKeys.has(s.key))
        errors.push(
          `qnas[${i}].sections: duplicate key ${JSON.stringify(s.key)}`,
        );
      sectionKeys.add(s.key);
      if (!nonEmpty(s.heading))
        errors.push(`qnas[${i}].sections[${j}].heading: missing or empty`);
      if (!nonEmpty(s.body_md))
        errors.push(`qnas[${i}].sections[${j}].body_md: missing or empty`);
    });

    if (!Array.isArray(q.earns_marks))
      errors.push(`qnas[${i}].earns_marks: must be an array`);
    (Array.isArray(q.earns_marks) ? q.earns_marks : []).forEach((e, j) => {
      if (!nonEmpty(e.label))
        errors.push(`qnas[${i}].earns_marks[${j}].label: missing or empty`);
      if (!sectionKeys.has(e.section_key))
        errors.push(
          `qnas[${i}].earns_marks[${j}].section_key: ${JSON.stringify(e.section_key ?? null)} does not match any sections[].key`,
        );
    });
    qnaIds.add(q.id);
  });

  if (!Array.isArray(canonical.images)) errors.push("images: must be an array");
  const images = Array.isArray(canonical.images) ? canonical.images : [];
  for (const [i, img] of images.entries()) {
    checkId(`images[${i}]`, img.id);
    if (!qnaIds.has(img.qna_id))
      errors.push(
        `images[${i}].qna_id: ${JSON.stringify(img.qna_id ?? null)} does not match any qnas[].id`,
      );
    if (!nonEmpty(img.caption))
      errors.push(`images[${i}].caption: missing or empty`);
    if (!nonEmpty(img.content_description))
      errors.push(`images[${i}].content_description: missing or empty`);
    if (!isInt(img.sort_order))
      errors.push(`images[${i}].sort_order: not an integer`);
    if (!nonEmpty(img.file)) {
      errors.push(`images[${i}].file: missing or empty`);
      continue;
    }
    let bytes;
    try {
      bytes = await readFile(path.join(dir, img.file));
    } catch {
      errors.push(`images[${i}].file: ${img.file} not found`);
      continue;
    }
    const isWebp =
      bytes.length >= 12 &&
      bytes.toString("ascii", 0, 4) === "RIFF" &&
      bytes.toString("ascii", 8, 12) === "WEBP";
    if (!isWebp) {
      errors.push(`images[${i}]: not a WebP file`);
      continue;
    }
    if (img.byte_size !== bytes.length)
      errors.push(
        `images[${i}].byte_size: ${img.byte_size} does not match file size ${bytes.length}`,
      );
    if (bytes.length > MAX_IMAGE_BYTES)
      errors.push(
        `images[${i}]: byte_size ${bytes.length} exceeds ${MAX_IMAGE_BYTES}`,
      );
    const sha = createHash("sha256").update(bytes).digest("hex");
    if (img.sha256 !== sha)
      errors.push(`images[${i}].sha256: does not match file contents`);
    try {
      const meta = await sharp(bytes).metadata();
      if ((meta.width ?? 0) > MAX_IMAGE_EDGE)
        errors.push(
          `images[${i}]: width ${meta.width} exceeds ${MAX_IMAGE_EDGE}`,
        );
      if ((meta.height ?? 0) > MAX_IMAGE_EDGE)
        errors.push(
          `images[${i}]: height ${meta.height} exceeds ${MAX_IMAGE_EDGE}`,
        );
    } catch {
      errors.push(`images[${i}]: unreadable image data`);
    }
  }

  return errors;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const dir = process.argv[2];
  if (!dir) {
    console.error("usage: node src/validate.js <canonicalDir>");
    process.exit(2);
  }
  const errors = await validateCanonical(dir);
  if (errors.length > 0) {
    for (const e of errors) console.error(`ERROR ${e}`);
    process.exit(1);
  }
  const canonical = JSON.parse(
    await readFile(path.join(dir, "chapter.json"), "utf8"),
  );
  console.log(
    `OK ${dir}: ${canonical.qnas.length} qnas, ${canonical.images.length} images validated`,
  );
}
```

Note the two `continue`s in the image loop: a missing or non-WebP file short-circuits the byte checks so one root cause does not fan out into four noisy errors (this is why the non-WebP test expects exactly one message).

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test`
Expected: PASS - summary contains `# pass 19` and `# fail 0` (8 build + 11 validate).

- [ ] **Step 5: Commit**

```bash
git add ingestion/src/validate.js ingestion/test/validate.test.js
git commit -m "feat(ingestion): validate.js CI gate with exact error messages"
```

---

### Task 5: The committed fixture chapter (de-branded owned sample)

**Files:**

- Create: `ingestion/fixtures/sample-chapter/chapter.json` (authoring source)
- Create: `ingestion/fixtures/sample-chapter/images/spinal-levels.png` (generated placeholder)
- Create: `ingestion/fixtures/sample-chapter/ids.lock` (written by the build; committed)
- Create: `ingestion/fixtures/canonical/sample-chapter/chapter.json` + `ingestion/fixtures/canonical/sample-chapter/images/<ULID>.webp` (built output; committed)
- Test: `ingestion/test/fixture.test.js`

**Interfaces:**

- Consumes: `buildChapter` (Task 3), `validateCanonical` (Task 4).
- Produces: THE cross-lane fixture. Lanes B and D load `ingestion/fixtures/canonical/sample-chapter/chapter.json` (2 topics, 3 qnas, 1 WebP image; ULIDs stable because `ids.lock` is committed). Task 6's publish tests publish this directory. Content is de-branded owned sample text (outside voice #2) - safe pre-term-sheet.

- [ ] **Step 1: Write the authoring source**

`ingestion/fixtures/sample-chapter/chapter.json`:

```json
{
  "speciality_slug": "anaesthesia",
  "chapter": {
    "title": "Regional Anaesthesia (Sample)",
    "slug": "regional-anaesthesia-sample",
    "sort_order": 1,
    "exam_weight": 10
  },
  "topics": [
    {
      "key": "spinal-anaesthesia",
      "title": "Spinal Anaesthesia",
      "slug": "spinal-anaesthesia",
      "exam_theme": "Regional techniques",
      "sort_order": 1,
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
            },
            {
              "label": "Indications by surgical site",
              "section_key": "indications"
            },
            {
              "label": "Absolute contraindications",
              "section_key": "indications"
            }
          ],
          "sections": [
            {
              "key": "definition",
              "heading": "Definition",
              "body_md": "Spinal anaesthesia is a regional technique in which a local anaesthetic is deposited in the subarachnoid space, producing a reversible block of the spinal nerve roots. This is owned sample text written for the DiploMate pipeline fixture."
            },
            {
              "key": "indications",
              "heading": "Indications and contraindications",
              "body_md": "Indications include lower-abdominal and lower-limb procedures where an awake technique is preferred. Contraindications include patient refusal, local infection at the puncture site, and uncorrected coagulopathy. Sample text, not licensed content."
            },
            {
              "key": "summary",
              "heading": "Summary",
              "body_md": "A single deposit of local anaesthetic in the subarachnoid space provides dense, reliable blockade for surgery below the umbilicus."
            }
          ],
          "images": [
            {
              "file": "spinal-levels.png",
              "caption": "Vertebral levels relevant to spinal anaesthesia (sample diagram)",
              "content_description": "Sample placeholder panel standing in for a labelled vertebral column diagram.",
              "sort_order": 1
            }
          ]
        },
        {
          "key": "spinal-technique",
          "question": "Describe the steps of performing a subarachnoid block.",
          "years": "2021",
          "marks": 5,
          "sort_order": 2,
          "earns_marks": [
            {
              "label": "Positioning and landmarks",
              "section_key": "technique"
            },
            {
              "label": "Confirmation of correct placement",
              "section_key": "technique"
            }
          ],
          "sections": [
            {
              "key": "technique",
              "heading": "Technique",
              "body_md": "With the patient sitting or in lateral position, the interspace is identified, the skin is prepared, and the needle is advanced in the midline until free flow of cerebrospinal fluid confirms placement. Owned sample text for fixture use."
            },
            {
              "key": "summary",
              "heading": "Summary",
              "body_md": "Positioning, landmark identification, sterile technique, and confirmation by cerebrospinal fluid flow are the marks-earning steps."
            }
          ],
          "images": []
        }
      ]
    },
    {
      "key": "spinal-complications",
      "title": "Complications of Spinal Anaesthesia",
      "slug": "complications-of-spinal-anaesthesia",
      "exam_theme": "Complications and safety",
      "sort_order": 2,
      "qnas": [
        {
          "key": "pdph",
          "question": "What is post dural puncture headache? Outline its management.",
          "years": "2018, 2023",
          "marks": 10,
          "sort_order": 1,
          "earns_marks": [
            {
              "label": "Postural character of the headache",
              "section_key": "definition"
            },
            {
              "label": "Conservative and definitive management",
              "section_key": "management"
            }
          ],
          "sections": [
            {
              "key": "definition",
              "heading": "Definition",
              "body_md": "Post dural puncture headache is a positional headache that follows breach of the dura, worsening on sitting or standing and easing when supine. Owned sample text for fixture use."
            },
            {
              "key": "management",
              "heading": "Management",
              "body_md": "Initial management is conservative with fluids and simple analgesia; persistent cases are treated definitively. Sample text, not licensed content."
            },
            {
              "key": "summary",
              "heading": "Summary",
              "body_md": "Recognise the postural pattern, start conservative measures, and escalate when the headache persists."
            }
          ],
          "images": []
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Generate the placeholder source image**

Run (in `ingestion/`):

```bash
node -e "require('sharp')({create:{width:800,height:600,channels:3,background:{r:214,g:234,b:236}}}).png().toFile('fixtures/sample-chapter/images/spinal-levels.png').then(()=>console.log('png ok'))"
```

Expected: `png ok`

- [ ] **Step 3: Build the canonical fixture**

Run: `node src/build.js fixtures/sample-chapter fixtures/canonical/sample-chapter`
Expected: `built chapter <26-char ULID> (3 qnas, 1 images)`; `fixtures/sample-chapter/ids.lock` now exists with 1 chapter + 2 topics + 3 qnas + 1 image entry; `fixtures/canonical/sample-chapter/` contains `chapter.json` and `images/<ULID>.webp`.

- [ ] **Step 4: Validate the canonical fixture**

Run: `node src/validate.js fixtures/canonical/sample-chapter`
Expected: `OK fixtures/canonical/sample-chapter: 3 qnas, 1 images validated`, exit 0.

- [ ] **Step 5: Write the fixture tests**

`ingestion/test/fixture.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildChapter } from "../src/build.js";
import { validateCanonical } from "../src/validate.js";

const SOURCE_DIR = fileURLToPath(
  new URL("../fixtures/sample-chapter", import.meta.url),
);
const CANONICAL_DIR = fileURLToPath(
  new URL("../fixtures/canonical/sample-chapter", import.meta.url),
);

test("committed canonical fixture passes validation", async () => {
  assert.deepEqual(await validateCanonical(CANONICAL_DIR), []);
});

test("committed canonical fixture has the shape lanes B/D rely on", async () => {
  const canonical = JSON.parse(
    await readFile(path.join(CANONICAL_DIR, "chapter.json"), "utf8"),
  );
  assert.equal(canonical.topics.length, 2);
  assert.equal(canonical.qnas.length, 3);
  assert.equal(canonical.images.length, 1);
});

test("rebuilding the fixture reuses the committed ULIDs", async () => {
  const outDir = await mkdtemp(path.join(tmpdir(), "ingest-refixture-"));
  const rebuilt = await buildChapter(SOURCE_DIR, outDir);
  const committed = JSON.parse(
    await readFile(path.join(CANONICAL_DIR, "chapter.json"), "utf8"),
  );
  assert.equal(rebuilt.chapter.id, committed.chapter.id);
  assert.deepEqual(
    rebuilt.topics.map((t) => t.id),
    committed.topics.map((t) => t.id),
  );
  assert.deepEqual(
    rebuilt.qnas.map((q) => q.id),
    committed.qnas.map((q) => q.id),
  );
  assert.deepEqual(
    rebuilt.images.map((i) => i.id),
    committed.images.map((i) => i.id),
  );
});
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm test`
Expected: PASS - summary contains `# pass 22` and `# fail 0`.

(If the fixture tests fail here, steps 1-4 were done out of order - the canonical dir must be built and committed exactly once from the committed source.)

- [ ] **Step 7: Commit (source, lock, canonical output, binaries included)**

```bash
git add ingestion/fixtures ingestion/test/fixture.test.js
git commit -m "feat(ingestion): committed de-branded fixture chapter (2 topics, 3 qnas, 1 webp)"
```

---

### Task 6: publish.js - PG1 gate + idempotent upsert + content_version bump

**Files:**

- Create: `ingestion/src/publish.js`
- Create: `ingestion/test/db.js` (test helper)
- Test: `ingestion/test/publish.test.js`

**Interfaces:**

- Consumes: `sql/0001_content_v0.sql` (plan `2026-07-04-day1-content-ddl.md`; tables `specialities(id,name,exam_type,slug,sort_order)`, `chapters(id,speciality_id,title,slug,sort_order,exam_weight,content_version)`, `topics(id,chapter_id,title,slug,exam_theme,sort_order)`, `qnas(id,topic_id,question,years,marks,earns_marks,sections,sort_order)`, `images(id,qna_id,caption,content_description,webp,byte_size,sha256,sort_order)`); `validateCanonical` (Task 4); the canonical fixture (Task 5); `pg` package.
- Produces: `export function gateCheck(args, env)` -> `string | null` (refusal message or null = allowed); `export async function publishChapter(client, canonicalDir)` -> `Promise<{chapterId: string, contentVersion: number}>` (one transaction; validates first; idempotent upsert; authoritative per chapter - rows dropped from canonical are deleted; bumps `chapters.content_version` by 1 every publish). CLI: `LICENSE_SIGNED=true node src/publish.js <canonicalDir> --allow-publish` with `DATABASE_URL` env; prints `published chapter <id> at content_version <n>`. Lane D's deploy smoke and lane C's manifest/chapters routes read what this writes.

Exact refusal messages (outside voice #2 - the PG1 gate):

```
publish refused: pass --allow-publish (publishing is PG1-gated)
publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)
```

- [ ] **Step 1: Write the test DB helper**

`ingestion/test/db.js`:

```js
import { readFile } from "node:fs/promises";
import pg from "pg";

// Applies the repo's real DDL to the disposable test database and seeds one
// speciality row (speciality ULIDs are owned by sql/0002 in prod; tests pin
// their own so this suite depends only on 0001).
export const TEST_SPECIALITY_ID = "01ARZ3NDEKTSV4RRFFQ69G5FAV";

export async function testClient() {
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  await client.query(
    "DROP TABLE IF EXISTS images, qnas, topics, chapters, specialities, app_config CASCADE",
  );
  const ddl = await readFile(
    new URL("../../sql/0001_content_v0.sql", import.meta.url),
    "utf8",
  );
  await client.query(ddl);
  await client.query(
    `INSERT INTO specialities (id, name, exam_type, slug, sort_order)
     VALUES ($1, 'Anaesthesia', 'DNB', 'anaesthesia', 1)`,
    [TEST_SPECIALITY_ID],
  );
  return client;
}
```

- [ ] **Step 2: Write the failing tests**

`ingestion/test/publish.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  readFile,
  writeFile,
  copyFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { gateCheck, publishChapter } from "../src/publish.js";
import { testClient, TEST_SPECIALITY_ID } from "./db.js";

const FIXTURE = fileURLToPath(
  new URL("../fixtures/canonical/sample-chapter", import.meta.url),
);
const DB = process.env.DATABASE_URL;
const skipDb = !DB && "set DATABASE_URL to run publish integration tests";

test("gate refuses without --allow-publish", () => {
  assert.equal(
    gateCheck([], { LICENSE_SIGNED: "true" }),
    "publish refused: pass --allow-publish (publishing is PG1-gated)",
  );
});

test("gate refuses without LICENSE_SIGNED=true even with the flag", () => {
  assert.equal(
    gateCheck(["--allow-publish"], {}),
    "publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)",
  );
});

test("gate passes with flag and env together", () => {
  assert.equal(
    gateCheck(["--allow-publish"], { LICENSE_SIGNED: "true" }),
    null,
  );
});

test("publish rejects an invalid canonical dir before touching the database", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-bad-"));
  await writeFile(path.join(dir, "chapter.json"), "{not json");
  // client = null proves validation runs before any query is issued.
  await assert.rejects(() => publishChapter(null, dir), /validation failed/);
});

async function copyCanonical(mutate) {
  const dir = await mkdtemp(path.join(tmpdir(), "ingest-pub-"));
  await mkdir(path.join(dir, "images"), { recursive: true });
  const canonical = JSON.parse(
    await readFile(path.join(FIXTURE, "chapter.json"), "utf8"),
  );
  const result = mutate ? mutate(canonical) : undefined;
  await writeFile(
    path.join(dir, "chapter.json"),
    JSON.stringify(canonical, null, 2),
  );
  for (const img of canonical.images) {
    await copyFile(path.join(FIXTURE, img.file), path.join(dir, img.file));
  }
  return { dir, canonical, result };
}

test(
  "publish inserts the fixture and bumps content_version; republish is idempotent",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const first = await publishChapter(client, FIXTURE);
      assert.equal(first.contentVersion, 1);

      const counts = async () =>
        (
          await client.query(
            `SELECT (SELECT count(*) FROM chapters)::int AS chapters,
              (SELECT count(*) FROM topics)::int AS topics,
              (SELECT count(*) FROM qnas)::int AS qnas,
              (SELECT count(*) FROM images)::int AS images`,
          )
        ).rows[0];
      assert.deepEqual(await counts(), {
        chapters: 1,
        topics: 2,
        qnas: 3,
        images: 1,
      });

      const spec = await client.query("SELECT speciality_id FROM chapters");
      assert.equal(spec.rows[0].speciality_id, TEST_SPECIALITY_ID);

      const second = await publishChapter(client, FIXTURE);
      assert.equal(second.contentVersion, 2);
      assert.deepEqual(await counts(), {
        chapters: 1,
        topics: 2,
        qnas: 3,
        images: 1,
      });

      const img = await client.query(
        "SELECT octet_length(webp) AS len, byte_size, sha256 FROM images",
      );
      assert.equal(img.rows[0].len, img.rows[0].byte_size);
      assert.match(img.rows[0].sha256, /^[0-9a-f]{64}$/);
    } finally {
      await client.end();
    }
  },
);

test(
  "republish removes rows dropped from the canonical set",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      await publishChapter(client, FIXTURE);
      const { dir, result: droppedId } = await copyCanonical((canonical) => {
        const dropped = canonical.qnas.pop(); // pdph qna - has no images
        return dropped.id;
      });
      await publishChapter(client, dir);
      const n = await client.query("SELECT count(*)::int AS n FROM qnas");
      assert.equal(n.rows[0].n, 2);
      const gone = await client.query(
        "SELECT count(*)::int AS n FROM qnas WHERE id = $1",
        [droppedId],
      );
      assert.equal(gone.rows[0].n, 0);
    } finally {
      await client.end();
    }
  },
);

test(
  "publish refuses an unknown speciality slug (specialities are seed-owned)",
  { skip: skipDb },
  async () => {
    const client = await testClient();
    try {
      const { dir } = await copyCanonical((canonical) => {
        canonical.speciality_slug = "cardiology";
      });
      await assert.rejects(
        () => publishChapter(client, dir),
        /unknown speciality slug "cardiology" - specialities are seeded by sql\/0002, never created by publish/,
      );
      const n = await client.query("SELECT count(*)::int AS n FROM chapters");
      assert.equal(n.rows[0].n, 0);
    } finally {
      await client.end();
    }
  },
);
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `npm test`
Expected: FAIL - `Cannot find module '../src/publish.js'`. Earlier 22 tests still pass.

- [ ] **Step 4: Create the local test database (one-time, local dev only)**

```bash
createdb diplomate_ingestion_test 2>/dev/null || true
export DATABASE_URL=postgres://localhost:5432/diplomate_ingestion_test
```

(CI provides `DATABASE_URL` via a service container in Task 7. Without `DATABASE_URL` the three integration tests self-skip with `set DATABASE_URL to run publish integration tests` - the gate and validation tests always run.)

- [ ] **Step 5: Write `ingestion/src/publish.js`**

```js
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { validateCanonical } from "./validate.js";

export function gateCheck(args, env) {
  if (!args.includes("--allow-publish")) {
    return "publish refused: pass --allow-publish (publishing is PG1-gated)";
  }
  if (env.LICENSE_SIGNED !== "true") {
    return "publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)";
  }
  return null;
}

export async function publishChapter(client, canonicalDir) {
  const errors = await validateCanonical(canonicalDir);
  if (errors.length > 0) {
    throw new Error(
      `validation failed: ${errors[0]} (${errors.length} error(s) - run node src/validate.js ${canonicalDir})`,
    );
  }
  const canonical = JSON.parse(
    await readFile(path.join(canonicalDir, "chapter.json"), "utf8"),
  );
  const ch = canonical.chapter;

  await client.query("BEGIN");
  try {
    const spec = await client.query(
      "SELECT id FROM specialities WHERE slug = $1",
      [canonical.speciality_slug],
    );
    if (spec.rowCount === 0) {
      throw new Error(
        `unknown speciality slug "${canonical.speciality_slug}" - specialities are seeded by sql/0002, never created by publish`,
      );
    }
    const specialityId = spec.rows[0].id;

    await client.query(
      `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (id) DO UPDATE SET
         speciality_id = EXCLUDED.speciality_id, title = EXCLUDED.title, slug = EXCLUDED.slug,
         sort_order = EXCLUDED.sort_order, exam_weight = EXCLUDED.exam_weight`,
      [ch.id, specialityId, ch.title, ch.slug, ch.sort_order, ch.exam_weight],
    );

    for (const t of canonical.topics) {
      await client.query(
        `INSERT INTO topics (id, chapter_id, title, slug, exam_theme, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO UPDATE SET
           chapter_id = EXCLUDED.chapter_id, title = EXCLUDED.title, slug = EXCLUDED.slug,
           exam_theme = EXCLUDED.exam_theme, sort_order = EXCLUDED.sort_order`,
        [t.id, t.chapter_id, t.title, t.slug, t.exam_theme, t.sort_order],
      );
    }

    for (const q of canonical.qnas) {
      await client.query(
        `INSERT INTO qnas (id, topic_id, question, years, marks, earns_marks, sections, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
         ON CONFLICT (id) DO UPDATE SET
           topic_id = EXCLUDED.topic_id, question = EXCLUDED.question, years = EXCLUDED.years,
           marks = EXCLUDED.marks, earns_marks = EXCLUDED.earns_marks, sections = EXCLUDED.sections,
           sort_order = EXCLUDED.sort_order`,
        [
          q.id,
          q.topic_id,
          q.question,
          q.years,
          q.marks,
          JSON.stringify(q.earns_marks),
          JSON.stringify(q.sections),
          q.sort_order,
        ],
      );
    }

    for (const img of canonical.images) {
      const bytes = await readFile(path.join(canonicalDir, img.file));
      await client.query(
        `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO UPDATE SET
           qna_id = EXCLUDED.qna_id, caption = EXCLUDED.caption,
           content_description = EXCLUDED.content_description, webp = EXCLUDED.webp,
           byte_size = EXCLUDED.byte_size, sha256 = EXCLUDED.sha256, sort_order = EXCLUDED.sort_order`,
        [
          img.id,
          img.qna_id,
          img.caption,
          img.content_description,
          bytes,
          img.byte_size,
          img.sha256,
          img.sort_order,
        ],
      );
    }

    // A republish is authoritative for its chapter: rows dropped from the
    // canonical set are deleted (FK-safe order: images -> qnas -> topics).
    await client.query(
      `DELETE FROM images WHERE qna_id IN (
         SELECT q.id FROM qnas q JOIN topics t ON q.topic_id = t.id WHERE t.chapter_id = $1
       ) AND id <> ALL($2::text[])`,
      [ch.id, canonical.images.map((i) => i.id)],
    );
    await client.query(
      `DELETE FROM qnas WHERE topic_id IN (SELECT id FROM topics WHERE chapter_id = $1)
       AND id <> ALL($2::text[])`,
      [ch.id, canonical.qnas.map((q) => q.id)],
    );
    await client.query(
      `DELETE FROM topics WHERE chapter_id = $1 AND id <> ALL($2::text[])`,
      [ch.id, canonical.topics.map((t) => t.id)],
    );

    // ponytail: content_version bumps on EVERY publish, including a no-change
    // republish - clients just refetch one chapter; diffing rows to skip the
    // bump is complexity the beta does not need.
    const bumped = await client.query(
      "UPDATE chapters SET content_version = content_version + 1 WHERE id = $1 RETURNING content_version",
      [ch.id],
    );
    await client.query("COMMIT");
    return { chapterId: ch.id, contentVersion: bumped.rows[0].content_version };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const args = process.argv.slice(2);
  const dir = args.find((a) => !a.startsWith("--"));
  if (!dir) {
    console.error(
      "usage: LICENSE_SIGNED=true node src/publish.js <canonicalDir> --allow-publish",
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
    const { chapterId, contentVersion } = await publishChapter(client, dir);
    console.log(
      `published chapter ${chapterId} at content_version ${contentVersion}`,
    );
  } catch (err) {
    console.error(`ERROR ${err.message}`);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm test` (with `DATABASE_URL` exported from Step 4)
Expected: PASS - summary contains `# pass 29` and `# fail 0`.

Also run without the env to prove the skip path: `env -u DATABASE_URL npm test`
Expected: PASS - `# pass 26`, `# skipped 3`.

- [ ] **Step 7: Prove the gate at the CLI (no database touched)**

Run: `node src/publish.js fixtures/canonical/sample-chapter`
Expected: stderr `publish refused: pass --allow-publish (publishing is PG1-gated)`, exit 1.

Run: `node src/publish.js fixtures/canonical/sample-chapter --allow-publish`
Expected: stderr `publish refused: set LICENSE_SIGNED=true (content term sheet unsigned - publishing stays PG1-gated)`, exit 1.

- [ ] **Step 8: Commit**

```bash
git add ingestion/src/publish.js ingestion/test/db.js ingestion/test/publish.test.js
git commit -m "feat(ingestion): PG1-gated idempotent publish with content_version bump"
```

---

### Task 7: CI wiring - validate the fixture and run the suite on every push

**Files:**

- Create: `.github/workflows/ingestion.yml`

**Interfaces:**

- Consumes: `npm test` (Tasks 2-6), `node src/validate.js` (Task 4), the committed canonical fixture (Task 5), `sql/0001_content_v0.sql` (plan 1).
- Produces: the CI gate ENG-T6 requires - every push touching `ingestion/` or `sql/` re-validates the committed canonical fixture (schema + image caps) and runs the full unit + Postgres-integration suite. A separate workflow file so it never collides with plan 1's or plan 2's CI files.

- [ ] **Step 1: Write `.github/workflows/ingestion.yml`**

```yaml
name: ingestion
on:
  push:
    paths:
      - "ingestion/**"
      - "sql/**"
      - ".github/workflows/ingestion.yml"
  pull_request:
    paths:
      - "ingestion/**"
      - "sql/**"
      - ".github/workflows/ingestion.yml"
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: diplomate_ingestion_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/diplomate_ingestion_test
    defaults:
      run:
        working-directory: ingestion
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm test
      - run: node src/validate.js fixtures/canonical/sample-chapter
```

- [ ] **Step 2: Verify the workflow steps locally (same commands CI runs)**

Run (in `ingestion/`): `npm ci && npm test && node src/validate.js fixtures/canonical/sample-chapter`
Expected: `npm ci` exits 0; `npm test` summary `# pass 29` / `# fail 0` (with local `DATABASE_URL` set; `# skipped 3` without it); validator prints `OK fixtures/canonical/sample-chapter: 3 qnas, 1 images validated`.

- [ ] **Step 3: Commit and confirm the workflow runs green on push**

```bash
git add .github/workflows/ingestion.yml
git commit -m "ci(ingestion): validate fixture + run suite on a disposable Postgres"
git push
```

Then: `gh run watch` (or `gh run list --workflow=ingestion --limit 1`)
Expected: the `ingestion` workflow concludes `success`.

---

## Coverage

| Source task / lock                                                                                                                                                                                                                                                                                                                             | Plan tasks                                                                                                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ENG-T6 (`tasks-eng-review-20260704-093233.jsonl`, AS AMENDED by the NO OFFLINE DOWNLOADS revision): pipeline not spike; opaque stable ULIDs + mutable path metadata; CI validation (schema, image caps 200KB + WebP + resolution cap); publisher bumps `chapters.content_version`; NO client-install checksum machinery, NO 20MB bundle budget | Tasks 1-7 (ULID identity + ids.lock: 2, 3, 5; CI validation: 4, 7; content_version bump: 6; checksum/bundle machinery: deliberately absent per Global Constraints - only per-image sha256 as HTTP ETag survives)        |
| D16 schema coupling (design lock, anchored by ENG-T20's v0 DDL): `sections` + `earns_marks` anchor structure encoded from the first ingested chapter                                                                                                                                                                                           | Tasks 2 and 4 (canonical shape + validator enforce `[{key,heading,body_md}]` and `section_key` referencing), Task 5 (the first ingested chapter carries definition/indications/technique/complications/summary anatomy) |
| Outside voice #2 (de-brand fallback; PUBLISHING stays PG1-gated)                                                                                                                                                                                                                                                                               | Task 5 (fixture is de-branded owned sample content - lane A runs term-sheet-free), Task 6 (`gateCheck`: `--allow-publish` + `LICENSE_SIGNED=true` refusals with exact copy)                                             |
| Test-plan critical path "Content update: ingestion pipeline publishes v2 (CI-validated: schema, image caps) -> app detects on manifest poll" (checksum/20MB clauses superseded by no-downloads)                                                                                                                                                | Tasks 4, 6, 7 (validation gate + versioned republish + CI); manifest-poll client half is out of scope below                                                                                                             |
| Test-plan rows superseded by no-downloads (download states, airplane-mode drilling, atomic install, storage full, corrupt pack, per-row hash verification)                                                                                                                                                                                     | NOT implemented anywhere, by directive                                                                                                                                                                                  |

**Out of scope (owning plan file):**

- `sql/0001_content_v0.sql` + `sql/0002_seed_specialities.sql`, schema contract tests, CI-from-zero migration apply (ENG-T20): `2026-07-04-day1-content-ddl.md` - this plan consumes both.
- `/manifest` (incl. `schema_version`, `min_app_version`, `content_version` exposure), `/chapters/:chapterId/qnas`, `/images/:id` ETag serving, entitlement middleware, quota: `2026-07-04-server-api.md`.
- Flutter screens consuming the fixture as UI test data: `2026-07-04-flutter-shell-screens.md`.
- Leitner/SRS and event persistence: `2026-07-04-study-loop-srs.md`.
- On-demand content fetch + transparent drift cache keyed on `content_version`, deploy smoke that runs this publisher against the Heroku database: `2026-07-04-integration-release.md`.
- Signing the content term sheet itself (CEO-T1, PG1): founder-only, no plan task; this plan only enforces the gate.
