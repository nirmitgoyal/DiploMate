# Content Pass Lane A: 0004 Migration + Metrics + Server Rewrites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the topics-removal schema migration (`sql/0004_drop_topics.sql`), rewrite the metrics pack at chapter grain with the `chapter_opened` event rename, and rewrite the two content routes (`manifest.js`, `chapters.js`) so qnas hang directly off chapters - with the empty-chapter filter, stable pagination, and the wire version-knob bump to 2.

**Architecture:** One new append-only migration does all schema work (add+backfill `qnas.chapter_id`, renumber `sort_order` per chapter, drop `topic_id`/`topics`, add the two missing indexes, widen the `app_events` CHECK to admit `chapter_opened`). Server routes then read `qnas.chapter_id` directly; the manifest gains a `WHERE EXISTS` empty-chapter filter; metrics SQL keys on `event_type IN ('chapter_opened','topic_opened')` and counts distinct chapters. This is eng-review task set T4/T5/T8/T11 + the server half of T6, plus the server/sql slices of the T10 test pack.

**Tech Stack:** Postgres 16 (raw SQL migrations), Node 22 + Express + `pg` (server), `node:test` + supertest (server tests), `node:test` + `pg` (tools/db contract tests).

**Source of truth:** design doc `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-claude-jolly-banach-f5aef8-design-20260706-134407.md` - its "ENG REVIEW AMENDMENTS (2026-07-06)" section SUPERSEDES the doc body wherever they conflict (event renamed `chapter_opened` NOW, ledger speciality-level, exam_weight = year-appearances, sweep identifier-level).

## Global Constraints

Every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, or doc; plain hyphens only (user convention).
- Migrations are APPEND-ONLY: all schema change goes in the new `sql/0004_drop_topics.sql`; `0001`/`0002`/`0003` are never edited.
- Publish stays blocked until `LICENSE_SIGNED=true`: nothing in this plan touches `ingestion/src/publish.js` `gateCheck` (it lives in lane B and is NOT weakened there either).
- The wire event name `chapter_opened` is emitted going forward; `topic_opened` stays legal in the CHECK for safety (amendment 4). Metrics key on `event_type IN ('chapter_opened','topic_opened')` - no UNION machinery.
- All generated/seeded content uses `speciality_slug` **`anaesthesiology`** (seeded id `01JZSP3C00DNB0000000000001`, `sql/0002_seed_specialities.sql:8`).
- Version knobs (amendment 10, cutover table): wire `SCHEMA_VERSION` 1 to 2 and `MIN_APP_VERSION` 1 to 2 land HERE (server half). Canonical `schema_version` 2 lands in lane B; drift bump lands in lane C. Note: main is already at drift `schemaVersion => 2` (plan 6 sync_attempts), so lane C's bump is 2 to 3 - the design doc's "drift 1 to 2" wording is stale.
- v2 wire contract (shared with lane C - copy exactly):
  - `GET /manifest` body: `{schema_version: 2, min_app_version: 2, specialities: [...]}`; with `?speciality=` also `chapters: [{id, title, slug, sort_order, exam_weight, content_version, qna_count}]` - NO `topic_count`, zero-qna chapters EXCLUDED.
  - `GET /chapters/:chapterId/qnas` body: `{chapter_id, content_version, schema_version: 2, page, pages, items: [{id, chapter_id, question, years, marks, earns_marks, sections, sort_order, images: [...]}]}` - NO `topics` key, items carry `chapter_id` not `topic_id`.
- Identifier-level sweep criterion (amendment 14): after this lane, `grep -rniE 'topic_id|topic_count|topicId|topics?\b' server/src server/test sql/metrics | grep -viE 'topical|topic_opened'` returns zero lines. `topic_opened` is exempt (CHECK back-compat + metrics IN-list + constants mirror); medical content strings ("topical anaesthesia") are exempt; append-only `sql/0001`/`sql/0003` are out of sweep scope.
- TDD per task: failing test first, run it (expect FAIL with the stated reason), minimal implementation, run again (expect PASS), commit. Conventional-commit messages.

**Deploy choreography (amendment 15, carried in the migration header):** run 0004 via `heroku pg:psql < sql/0004_drop_topics.sql` IMMEDIATELY BEFORE promoting the topics-less server deploy. The brief old-code window is acceptable at zero-user beta; never leave a migrated DB under old server code unattended.

**Working directory:** `node`/`npm` commands run from the directory named in each step (`tools/db/` or `server/`). Git commits run from the repo root. Server tests need `TEST_DATABASE_URL` pointing at a disposable Postgres with `tools/db/apply.sh` applied; tools/db tests need `DATABASE_URL` likewise.

**Suite-red window:** the moment 0004 is applied to the shared test database (end of Task 1), the untouched server tests (`content`, `manifest`, `metrics_pack`, `e2e_metrics_sanity`) go red because `seed_content.js` still inserts into `topics`. Tasks 2-5 restore them one file at a time; Task 6 proves the whole suite green. Do not merge this lane mid-way.

**Execution order across lanes:** this lane (A) runs in parallel with lanes B (ingestion) and C (app) in separate worktrees (superpowers:using-git-worktrees), EXCEPT lane B's publish integration tests need `sql/0004_drop_topics.sql` to exist - land Task 1 first (or share the file into B's worktree). Lane D (generator) runs only after B merges.

---

### Task 1: `sql/0004_drop_topics.sql` + migration correctness tests

**Files:**

- Create: `sql/0004_drop_topics.sql`
- Create: `tools/db/test/migration_0004.test.js`
- Modify: `tools/db/test/schema.test.js` (topics expectations out, chapter_id + indexes in)
- Modify: `tools/db/package.json` (serialize test files - they share one DATABASE_URL)

**Interfaces:**

- Produces: post-0004 schema consumed by every other task and lane - `qnas.chapter_id TEXT NOT NULL REFERENCES chapters(id)` (no `topic_id`, no `topics` table), `qnas.sort_order` renumbered 1..N per chapter, indexes `qnas_chapter_id_idx` + `images_qna_id_idx`, `app_events_event_type_check` admitting `chapter_opened` AND `topic_opened`.

- [ ] **Step 1: Serialize tools/db test files**

In `tools/db/package.json`, change the test script (two test files will now share one live database, and `migration_0004.test.js` rebuilds the schema from zero mid-run):

```json
  "scripts": {
    "test": "node --test --test-concurrency=1"
  }
```

- [ ] **Step 2: Write the failing migration-correctness test**

Create `tools/db/test/migration_0004.test.js`. It rebuilds the schema from zero itself (so it does not depend on apply.sh having run), seeds v1-shaped data WITH topics, applies 0004, and asserts backfill, renumbering, NOT NULL, index presence, and the widened CHECK:

```js
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
before(() => client.connect());
after(() => client.end());

async function apply(file) {
  const sql = await readFile(
    new URL(`../../../sql/${file}`, import.meta.url),
    "utf8",
  );
  await client.query(sql);
}

test("0004 backfills chapter_id, renumbers sort_order, drops topics, adds indexes, widens CHECK", async () => {
  await client.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public");
  await apply("0001_content_v0.sql");
  await apply("0002_seed_specialities.sql");
  await apply("0003_users_events.sql");

  // v1-shaped seed: two chapters, three topics, qnas with per-topic sort_order
  // duplicates (the C1 pagination hazard 0004 must renumber away).
  const spec = (
    await client.query(
      `SELECT id FROM specialities WHERE slug = 'anaesthesiology'`,
    )
  ).rows[0].id;
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight)
     VALUES ('CHA', $1, 'A', 'a', 1, 1), ('CHB', $1, 'B', 'b', 2, 1)`,
    [spec],
  );
  await client.query(`
    INSERT INTO topics (id, chapter_id, title, slug, sort_order) VALUES
      ('TA1', 'CHA', 'T1', 't1', 1), ('TA2', 'CHA', 'T2', 't2', 2),
      ('TB1', 'CHB', 'T3', 't3', 1)`);
  await client.query(`
    INSERT INTO qnas (id, topic_id, question, sections, sort_order) VALUES
      ('Q1', 'TA1', 'q1', '[]', 1), ('Q2', 'TA1', 'q2', '[]', 2),
      ('Q3', 'TA2', 'q3', '[]', 1), ('Q4', 'TA2', 'q4', '[]', 2),
      ('Q5', 'TB1', 'q5', '[]', 1)`);

  await apply("0004_drop_topics.sql");

  // Backfill: every qna owns its former topic's chapter.
  const rows = (
    await client.query(
      `SELECT id, chapter_id, sort_order FROM qnas ORDER BY chapter_id, sort_order`,
    )
  ).rows;
  assert.deepEqual(rows, [
    { id: "Q1", chapter_id: "CHA", sort_order: 1 },
    { id: "Q2", chapter_id: "CHA", sort_order: 2 },
    { id: "Q3", chapter_id: "CHA", sort_order: 3 },
    { id: "Q4", chapter_id: "CHA", sort_order: 4 },
    { id: "Q5", chapter_id: "CHB", sort_order: 1 },
  ]);

  // NOT NULL holds.
  const notnull = await client.query(`
    SELECT is_nullable FROM information_schema.columns
    WHERE table_name = 'qnas' AND column_name = 'chapter_id'`);
  assert.equal(notnull.rows[0].is_nullable, "NO");

  // topic_id and topics are gone.
  const cols = (
    await client.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name = 'qnas'`,
    )
  ).rows.map((r) => r.column_name);
  assert.ok(!cols.includes("topic_id"));
  const topics = await client.query(`SELECT to_regclass('public.topics') AS t`);
  assert.equal(topics.rows[0].t, null);

  // Indexes exist (Perf 1).
  const idx = (
    await client.query(
      `SELECT indexname FROM pg_indexes WHERE schemaname = 'public'`,
    )
  ).rows.map((r) => r.indexname);
  assert.ok(idx.includes("qnas_chapter_id_idx"));
  assert.ok(idx.includes("images_qna_id_idx"));

  // CHECK admits chapter_opened AND still admits topic_opened.
  await client.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u', 'u', 'x@y.z')`,
  );
  for (const type of ["chapter_opened", "topic_opened"]) {
    await client.query(
      `INSERT INTO app_events (id, user_id, event_type, occurred_at, local_day)
       VALUES (gen_random_uuid(), 'u', $1, now(), '2026-07-01')`,
      [type],
    );
  }
  await assert.rejects(
    client.query(
      `INSERT INTO app_events (id, user_id, event_type, occurred_at, local_day)
       VALUES (gen_random_uuid(), 'u', 'bogus', now(), '2026-07-01')`,
    ),
    /app_events_event_type_check/,
  );
});
```

- [ ] **Step 3: Run it to verify it fails**

Run (from `tools/db/`): `DATABASE_URL=<disposable> npm test`
Expected: FAIL - `ENOENT .../sql/0004_drop_topics.sql` (file does not exist yet). `schema.test.js` still passes at this point only if apply.sh ran before; ignore it until Step 6.

- [ ] **Step 4: Write the migration**

Create `sql/0004_drop_topics.sql`:

```sql
-- 0004_drop_topics.sql - content pass 2026-07-06: qnas hang directly off
-- chapters; the topics layer is removed (design doc jolly-banach-f5aef8,
-- eng-review amendments 4/9/15).
--
-- OPS (amendment 15): apply via `heroku pg:psql < sql/0004_drop_topics.sql`
-- IMMEDIATELY BEFORE promoting the topics-less server deploy. The brief
-- old-code-new-schema window is acceptable at zero-user beta; never leave a
-- migrated DB under old server code unattended. Local/CI: tools/db/apply.sh.
--
-- EVENT RENAME (amendment 4): the CHECK below admits 'chapter_opened' (the
-- event the app emits from now on) AND keeps 'topic_opened' for safety;
-- production app_events is empty pre-launch, so no historical rows exist
-- either way. Metrics key on event_type IN ('chapter_opened','topic_opened').
-- Dropping 'topic_opened' entirely is deferred post-beta.
--
-- SWEEP CRITERION (amendment 14, identifier-level): after the four rewrites,
--   grep -rniE 'topic_id|topic_count|topicId|topics?\b' \
--     app/lib app/test server/src server/test ingestion/src ingestion/test \
--     ingestion/fixtures ingestion/generator sql/metrics ingestion/AUTHORING.md \
--   | grep -viE 'topical|topic_opened'
-- must return zero lines. Exempt: medical content strings ("topical
-- anaesthesia"), the retained 'topic_opened' literal (this CHECK, metrics
-- IN-lists, constants mirrors), and append-only history (sql/0001, sql/0003,
-- this file).

BEGIN;

ALTER TABLE qnas ADD COLUMN chapter_id TEXT REFERENCES chapters(id);

UPDATE qnas q SET chapter_id = t.chapter_id
FROM topics t WHERE q.topic_id = t.id;

ALTER TABLE qnas ALTER COLUMN chapter_id SET NOT NULL;

-- C1: per-topic sort_order values collide once topics collapse into one
-- chapter; renumber 1..N per chapter in (topic order, qna order, id) so
-- ORDER BY sort_order LIMIT/OFFSET pagination is stable. The rewritten page
-- query ALSO orders by (sort_order, id) as a permanent tiebreak.
WITH renumbered AS (
  SELECT q.id,
         ROW_NUMBER() OVER (
           PARTITION BY q.chapter_id
           ORDER BY t.sort_order, q.sort_order, q.id
         ) AS rn
  FROM qnas q JOIN topics t ON q.topic_id = t.id
)
UPDATE qnas q SET sort_order = r.rn FROM renumbered r WHERE q.id = r.id;

ALTER TABLE qnas DROP COLUMN topic_id;
DROP TABLE topics;

-- Perf 1: 0001 shipped zero secondary indexes; the manifest EXISTS filter,
-- qna_count subqueries, page queries, and publish orphan-deletes all filter
-- on these columns.
CREATE INDEX qnas_chapter_id_idx ON qnas (chapter_id);
CREATE INDEX images_qna_id_idx ON images (qna_id);

ALTER TABLE app_events DROP CONSTRAINT app_events_event_type_check;
ALTER TABLE app_events ADD CONSTRAINT app_events_event_type_check
  CHECK (event_type IN ('chapter_opened','topic_opened','recall_shown',
                        'recall_revealed','recall_rated','session_start'));

COMMIT;
```

- [ ] **Step 5: Run the migration test to verify it passes**

Run (from `tools/db/`): `DATABASE_URL=<disposable> npm test`
Expected: `migration_0004.test.js` PASS. `schema.test.js` now FAILS (it still expects the `topics` table and `topic_id` on qnas) - fixed next step.

- [ ] **Step 6: Update the schema contract test**

In `tools/db/test/schema.test.js`:

- Delete the `topics columns exact` test entirely.
- Change the `qnas` expectation: replace `topic_id` with `chapter_id` in its expected column array (keep alphabetical order: `["chapter_id", "earns_marks", "id", "marks", "question", "sections", "sort_order", "years"]`).
- If the file asserts the `app_events` CHECK rejects/accepts specific event types, add `chapter_opened` to the accepted list (read the file; only touch topic/event assertions).
- Add one new test at the bottom:

```js
test("0004 indexes exist", async () => {
  const idx = (
    await client.query(
      `SELECT indexname FROM pg_indexes WHERE schemaname = 'public'`,
    )
  ).rows.map((r) => r.indexname);
  assert.ok(idx.includes("qnas_chapter_id_idx"));
  assert.ok(idx.includes("images_qna_id_idx"));
});
```

- [ ] **Step 7: Run the full tools/db suite**

Run (from `tools/db/`): `DATABASE_URL=<disposable> npm test`
Expected: ALL PASS (migration_0004 rebuilds and fully migrates the schema, then schema.test.js asserts the post-0004 shape; `--test-concurrency=1` guarantees the order hazard is gone).

- [ ] **Step 8: Apply 0004 to the server test database**

Run: `DATABASE_URL=$TEST_DATABASE_URL tools/db/apply.sh`
(apply.sh is idempotent only from zero; if it errors on already-applied files, apply just the new one: `psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/0004_drop_topics.sql`.)
Expected: applies cleanly. The server suite is now RED (seed_content still inserts topics) - this is the documented suite-red window; Tasks 2-5 fix it.

- [ ] **Step 9: Commit**

```bash
git add sql/0004_drop_topics.sql tools/db/test/migration_0004.test.js tools/db/test/schema.test.js tools/db/package.json
git commit -m "feat(sql): 0004 drops topics - chapter_id backfill, sort renumber, indexes, chapter_opened CHECK"
```

---

### Task 2: seed helper v2 + `chapters.js` rewrite

**Files:**

- Modify: `server/test/helpers/seed_content.js`
- Modify: `server/src/routes/chapters.js`
- Modify: `server/src/lib/constants.js`
- Test: `server/test/content.test.js`

**Interfaces:**

- Consumes: post-0004 schema (Task 1).
- Produces: `seedContent(pool)` seeding `CH1` with `QN1`/`QN2` (`chapter_id = 'CH1'`, sort_order 1/2) + `IM1`; wire constants `SCHEMA_VERSION = 2`, `MIN_APP_VERSION = 2`, `EVENT_TYPES` including `chapter_opened`; route body per the v2 wire contract in Global Constraints. Tasks 3-6 and lane C consume these.

- [ ] **Step 1: Rewrite the seed helper (test infrastructure first - it is what makes the failing tests runnable)**

Replace the topics/qnas inserts in `server/test/helpers/seed_content.js` (chapter and images inserts stay as they are):

```js
// Minimal content tree for endpoint tests - shaped exactly like the
// ingestion publisher's output (schema v2: qnas hang off chapters).
async function seedContent(pool) {
  const { rows } = await pool.query(
    `SELECT id FROM specialities WHERE slug = 'anaesthesiology'`,
  );
  const spec = rows[0].id;
  await pool.query(
    `
    INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
    VALUES ('CH1', $1, 'Airway Management', 'airway-management', 1, 100, 1)
    ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  await pool.query(`
    INSERT INTO qnas (id, chapter_id, question, years, marks, earns_marks, sections, sort_order)
    VALUES
      ('QN1', 'CH1', 'Outline the difficult airway algorithm.', '2021 Paper I', 10,
       '[{"label":"Definition","section_key":"definition"}]',
       '[{"key":"definition","heading":"Definition","body_md":"A clinical situation...","marks":2}]', 1),
      ('QN2', 'CH1', 'Describe rapid sequence induction.', '2019', 5,
       '[]', '[{"key":"summary","heading":"Summary","body_md":"Speed matters.","marks":null}]', 2)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`
    INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
    VALUES ('IM1', 'QN1', 'Fig 1 - algorithm', 'Flowchart of the difficult airway algorithm',
            decode('52494646', 'hex'), 4, 'abc123', 1)
    ON CONFLICT (id) DO NOTHING`);
  return { spec };
}

module.exports = { seedContent };
```

- [ ] **Step 2: Update `content.test.js` to the v2 wire contract (the failing regression test)**

In the first test (`chapter qnas are paginated JSON...`), replace the v1 assertions:

- after the `content_version` assertion add: `assert.strictEqual(res.body.schema_version, 2);`
- replace `assert.strictEqual(q1.topic_id, "TP1");` with `assert.strictEqual(q1.chapter_id, "CH1");`
- delete the whole `res.body.topics` assertion block (from `assert.strictEqual(res.body.topics.length, 1);` through the `exam_theme` assertion) and replace with:

```js
assert.strictEqual(res.body.topics, undefined, "v2: no topics key on the wire");
```

Leave the images and 404/401 tests untouched.

- [ ] **Step 3: Run it to verify it fails for the right reason**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test -- --test-name-pattern "chapter qnas"`
(If the runner version ignores the pattern flag, run the whole suite and read only this file's results.)
Expected: FAIL - the route still queries `JOIN topics`, which no longer exists (Postgres error `relation "topics" does not exist`), proving the seed helper and schema moved and the route has not.

- [ ] **Step 4: Add wire version constants**

In `server/src/lib/constants.js`, extend `EVENT_TYPES` and add the two wire knobs (single definition; both routes import them):

```js
// Wire enums are OWNED by sql/0003 + sql/0004 CHECK constraints - these
// mirrors exist for readability only; never validate against them.
// topic_opened stays in the CHECK for back-compat; the app emits
// chapter_opened from schema v2 on (0004, amendment 4).
const RATINGS = ["again", "hard", "good"];
const EVENT_TYPES = [
  "chapter_opened",
  "topic_opened",
  "recall_shown",
  "recall_revealed",
  "recall_rated",
  "session_start",
];
const PAGE_SIZE = 50;
// Version-knob cutover (amendment 10): wire schema v2 = topics-less shape;
// min_app_version 2 sends stale clients to the upgrade gate, never a parse error.
const SCHEMA_VERSION = 2;
const MIN_APP_VERSION = 2;

module.exports = {
  RATINGS,
  EVENT_TYPES,
  PAGE_SIZE,
  SCHEMA_VERSION,
  MIN_APP_VERSION,
};
```

- [ ] **Step 5: Rewrite the qnas route**

Replace the query section of `server/src/routes/chapters.js` (imports gain `SCHEMA_VERSION`; `chapterSpeciality` and middleware stack are unchanged):

```js
const { PAGE_SIZE, SCHEMA_VERSION } = require("../lib/constants");
```

and inside the handler:

```js
const meta = await pool.query(
  `SELECT content_version FROM chapters WHERE id = $1`,
  [chapterId],
);
const total = await pool.query(
  `SELECT count(*)::int AS n FROM qnas WHERE chapter_id = $1`,
  [chapterId],
);
const pages = Math.max(1, Math.ceil(total.rows[0].n / PAGE_SIZE));

// ORDER BY (sort_order, id): 0004 renumbers sort_order per chapter, and
// the id tiebreak keeps LIMIT/OFFSET pages stable forever after (C1).
const { rows: items } = await pool.query(
  `SELECT q.id, q.chapter_id, q.question, q.years, q.marks, q.earns_marks,
                q.sections, q.sort_order,
                COALESCE((
                  SELECT json_agg(json_build_object(
                    'id', i.id, 'caption', i.caption,
                    'content_description', i.content_description,
                    'byte_size', i.byte_size, 'sha256', i.sha256,
                    'sort_order', i.sort_order) ORDER BY i.sort_order)
                  FROM images i WHERE i.qna_id = q.id), '[]') AS images
         FROM qnas q
         WHERE q.chapter_id = $1
         ORDER BY q.sort_order, q.id
         LIMIT $2 OFFSET $3`,
  [chapterId, PAGE_SIZE, (page - 1) * PAGE_SIZE],
);

res.json({
  chapter_id: chapterId,
  content_version: meta.rows[0].content_version,
  schema_version: SCHEMA_VERSION,
  page,
  pages,
  items,
});
```

(The `topics` query and the `topics` response key are deleted entirely.)

- [ ] **Step 6: Run the content tests to verify they pass**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: `content.test.js` PASS. `manifest.test.js`, `metrics_pack.test.js`, `e2e_metrics_sanity.test.js` still FAIL (Tasks 3-5).

- [ ] **Step 7: Commit**

```bash
git add server/test/helpers/seed_content.js server/src/routes/chapters.js server/src/lib/constants.js server/test/content.test.js
git commit -m "feat(server): qnas served by chapter_id - v2 wire shape, stable (sort_order, id) pagination"
```

---

### Task 3: `manifest.js` rewrite - qna_count, empty-chapter filter, version knobs

**Files:**

- Modify: `server/src/routes/manifest.js`
- Test: `server/test/manifest.test.js`

**Interfaces:**

- Consumes: `SCHEMA_VERSION`/`MIN_APP_VERSION` from `server/src/lib/constants.js` (Task 2).
- Produces: manifest v2 body per Global Constraints; the empty-chapter filter invariant (`WHERE EXISTS`) lane C's nav relies on.

- [ ] **Step 1: Update `manifest.test.js` to the v2 contract (failing first)**

In the first test:

- `assert.strictEqual(res.body.schema_version, 1);` becomes `assert.strictEqual(res.body.schema_version, 2);`
- `assert.strictEqual(res.body.min_app_version, 1);` becomes `assert.strictEqual(res.body.min_app_version, 2);`
- `assert.strictEqual(ch.topic_count, 1);` is deleted and replaced with `assert.strictEqual(ch.topic_count, undefined, "v2: no topic_count");`
- `assert.strictEqual(ch.qna_count, 2);` stays.

Then add a new test at the bottom of the file (empty-chapter filter - a NEW deliverable, does not exist today):

```js
test("manifest excludes chapters with zero qnas (empty-chapter filter)", async () => {
  await resetUserData();
  const { spec } = await seedContent(pool);
  // An empty chapter that somehow got published must never reach nav.
  await pool.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ('CHEMPTY', $1, 'Ghost', 'ghost', 99, 0, 1) ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const res = await request(app)
    .get(`/manifest?speciality=${spec}`)
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
  const ids = res.body.chapters.map((c) => c.id);
  assert.ok(ids.includes("CH1"));
  assert.ok(
    !ids.includes("CHEMPTY"),
    "zero-qna chapter leaked into the manifest",
  );
  await pool.query(`DELETE FROM chapters WHERE id = 'CHEMPTY'`);
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: `manifest.test.js` FAILS - first test errors with `relation "topics" does not exist` (the route still subselects `FROM topics`), and the new filter test would also fail.

- [ ] **Step 3: Rewrite the manifest route**

In `server/src/routes/manifest.js`, delete the local `const SCHEMA_VERSION = 1; const MIN_APP_VERSION = 1;` lines and import the shared knobs; rewrite the chapters query:

```js
const { SCHEMA_VERSION, MIN_APP_VERSION } = require("../lib/constants");
```

and replace the chapters query with:

```js
// Empty-chapter filter (design deliverable): Stage 0 publishes only
// populated chapters; this WHERE EXISTS is the belt-and-braces server
// invariant that keeps nav clean even if an empty chapter ever lands.
const { rows: chapters } = await pool.query(
  `
        SELECT c.id, c.title, c.slug, c.sort_order, c.exam_weight, c.content_version,
               (SELECT count(*)::int FROM qnas q WHERE q.chapter_id = c.id) AS qna_count
        FROM chapters c
        WHERE c.speciality_id = $1
          AND EXISTS (SELECT 1 FROM qnas q WHERE q.chapter_id = c.id)
        ORDER BY c.sort_order`,
  [spec],
);
```

(`has_content` in the specialities query is untouched - a published chapter always has qnas, so `content_version > 0` remains a truthful signal.)

- [ ] **Step 4: Run to verify it passes**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: `manifest.test.js` ALL PASS (both tests). `metrics_pack` and `e2e_metrics_sanity` still red.

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/manifest.js server/test/manifest.test.js
git commit -m "feat(server): manifest v2 - qna_count, empty-chapter filter, schema/min_app_version 2"
```

---

### Task 4: metrics pack at chapter grain + TD4 re-derivation

**Files:**

- Modify: `sql/metrics/activation.sql`
- Modify: `sql/metrics/d7_return.sql`
- Modify: `sql/metrics/valid_recall.sql`
- Modify: `sql/metrics/README.md`
- Test: `server/test/metrics_pack.test.js`

**Interfaces:**

- Consumes: post-0004 schema; `chapter_opened` CHECK membership (Task 1).
- Produces: `valid_recall.sql` output columns `user_id, valid_recall_chapters, valid_recall_qnas` (RENAMED from `valid_recall_topics` - lane consumers: this file's tests, Task 5's E2E, the founder dashboard runbook). Activation/d7 unchanged output shape.

- [ ] **Step 1: Update `metrics_pack.test.js` (failing first) - this is the metrics REGRESSION suite (IRON RULE)**

In `seedUserJourney`, the activation event becomes the renamed event carrying the CHAPTER id:

```js
await pool.query(
  `INSERT INTO app_events (id, user_id, event_type, content_id, occurred_at, local_day)
     VALUES ($1, $2, 'chapter_opened', 'CH1', '2026-07-01T10:00:00Z', '2026-07-01')`,
  [crypto.randomUUID(), userId],
);
```

In the main test, the "second valid recall" comment and assertions move to chapter grain (QN1 and QN2 are both in CH1, so 2 qnas still collapse to 1 chapter - D14's collapsing proof survives the grain change):

```js
const honest = vr.rows.find((r) => r.user_id === "honest");
const skimmer = vr.rows.find((r) => r.user_id === "skimmer");
assert.strictEqual(Number(honest.valid_recall_chapters), 1);
assert.strictEqual(
  Number(honest.valid_recall_qnas),
  2,
  "two QnAs in one chapter: 2 qnas but 1 chapter (D14 at chapter grain)",
);
assert.ok(
  !skimmer || Number(skimmer.valid_recall_chapters) === 0,
  "<10s reveal never counts (D9)",
);
```

Add one continuity test at the bottom (the IN-list keeps legacy rows countable):

```js
test("a legacy topic_opened row still activates (IN-list continuity)", async () => {
  await resetUserData();
  await seedContent(pool);
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('legacy','legacy','x@y.z')
     ON CONFLICT (google_sub) DO NOTHING`,
  );
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, occurred_at, local_day)
     VALUES ($1, 'legacy', 'topic_opened', 'CH1', '2026-07-01T10:00:00Z', '2026-07-01')`,
    [crypto.randomUUID()],
  );
  const act = await pool.query(
    fs.readFileSync(path.join(packDir, "activation.sql"), "utf8"),
  );
  assert.strictEqual(Number(act.rows[0].activated_users), 1);
});
```

The existing `pack files never window on synced_at` test stays untouched.

- [ ] **Step 2: Run to verify it fails**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: `metrics_pack.test.js` FAILS - `valid_recall.sql` still selects `q.topic_id`, which no longer exists (`column q.topic_id does not exist`).

- [ ] **Step 3: Rewrite the three metrics files**

`sql/metrics/activation.sql`:

```sql
-- Activated user = opened >= 1 chapter (D9 at chapter grain, 2026-07-06).
-- The app emits chapter_opened from schema v2 on; topic_opened stays in the
-- IN-list for back-compat (0004 keeps it legal; prod had zero rows at rename).
-- Cohort floor: quantitative reads need >= 30 activated users (D11); below
-- that treat as qualitative. Empty-track picks are excluded by definition
-- (no chapter to open, PG2/TD3).
SELECT count(DISTINCT user_id) AS activated_users
FROM app_events
WHERE event_type IN ('chapter_opened', 'topic_opened');
```

`sql/metrics/d7_return.sql` (only the `first_day` CTE's WHERE changes; header comment updated):

```sql
-- D7 return: any event on or after first_day + 7 (local_day windows).
-- TD4 gates: green >= 40% recall AND D7 >= 30% on >= 30 activated;
-- yellow recall 20-40% or D7 15-30%; red below. Chapter grain since
-- 2026-07-06 (see README).
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type IN ('chapter_opened', 'topic_opened')
  GROUP BY user_id
),
returned AS (
  SELECT DISTINCT e.user_id
  FROM app_events e JOIN first_day f ON f.user_id = e.user_id
  WHERE e.local_day >= f.d0 + 7
)
SELECT (SELECT count(*) FROM first_day) AS activated_users,
       (SELECT count(*) FROM returned) AS returned_d7,
       round(100.0 * (SELECT count(*) FROM returned)
             / GREATEST((SELECT count(*) FROM first_day), 1), 1) AS d7_pct;
```

`sql/metrics/valid_recall.sql`:

```sql
-- Valid recall (D9): rating whose reveal kept the answer hidden >= 10s.
-- Unit = QnA (D14); the leading metric counts DISTINCT PARENT CHAPTERS of
-- validly-rated QnAs in the user's FIRST WEEK (first 7 local_days from
-- first chapter_opened). Chapter grain since 2026-07-06 (0004 removed the
-- topics layer; see README for the TD4 re-derivation). Windows ride
-- event-carried local_day - never synced_at.
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type IN ('chapter_opened', 'topic_opened')
  GROUP BY user_id
),
valid_reveals AS (
  SELECT user_id, content_id, local_day
  FROM app_events
  WHERE event_type = 'recall_revealed' AND hidden_ms >= 10000
)
SELECT f.user_id,
       count(DISTINCT q.chapter_id) AS valid_recall_chapters,
       count(DISTINCT re.content_id) AS valid_recall_qnas
FROM first_day f
JOIN review_events re
  ON re.user_id = f.user_id
 AND re.local_day BETWEEN f.d0 AND f.d0 + 6
JOIN valid_reveals vr
  ON vr.user_id = re.user_id AND vr.content_id = re.content_id
JOIN qnas q ON q.id = re.content_id
GROUP BY f.user_id
ORDER BY valid_recall_chapters DESC;
```

- [ ] **Step 4: Re-derive TD4 in the README (recalibrated, not silently redefined)**

Replace `sql/metrics/README.md` with:

```markdown
# Metrics pack

Run each file against prod with `heroku pg:psql < sql/metrics/activation.sql`
(swap in `valid_recall.sql` or `d7_return.sql` as needed) to compute the ONE
beta experiment from the event log.

## Grain change, 2026-07-06 (content pass, eng amendment 4)

The topics layer was removed (sql/0004); questions hang directly off Miller
chapters. The activation event is `chapter_opened`, emitted when a chapter is
opened - the chapter list is the nav level that replaced topics, so "opened

> = 1 content unit" keeps its meaning. `topic_opened` remains legal in the
> CHECK and in every query's IN-list for back-compat; production app_events was
> EMPTY at the rename (pre-launch), so no historical rows straddle the grain.

`valid_recall.sql` now counts DISTINCT CHAPTERS (`valid_recall_chapters`,
formerly `valid_recall_topics`). A Miller chapter aggregates what were
several topics, so per-user unit counts read LOWER at chapter grain than the
old topic grain would have; this is a denominator change to the experiment's
unit, re-derived here deliberately rather than silently.

## TD4 gates (re-stated at chapter grain)

TD4 reads the two leading numbers together, per activated user cohort:

- GREEN: >= 40% of activated users record >= 1 valid-recall CHAPTER in their
  first week AND D7 return >= 30%.
- YELLOW: recall share 20-40% or D7 15-30%.
- RED: below both.

All three colors only mean something at >= 30 activated users (opened >= 1
chapter); below that floor, treat output as qualitative. Because activation
is well under 100% of installs, TODOS item 4 recruits 45-50 installs to
reliably clear the 30-activated floor and start TD4's four-week decision
clock. Every window rides the event-carried `local_day` column (first 7
local_days from a user's first `chapter_opened` for the recall window,
`local_day >= first_day + 7` for D7) - `synced_at` is never used for
windowing and is reserved for a separate skew sanity check on how late
offline-first clients sync.
```

- [ ] **Step 5: Run to verify it passes**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: `metrics_pack.test.js` ALL PASS. Only `e2e_metrics_sanity.test.js` remains red.

- [ ] **Step 6: Commit**

```bash
git add sql/metrics/ server/test/metrics_pack.test.js
git commit -m "feat(metrics): chapter grain - chapter_opened IN-list, valid_recall_chapters, TD4 re-derived"
```

---

### Task 5: E2E metrics sanity on the renamed event (study-loop E2E, server half)

**Files:**

- Test: `server/test/e2e_metrics_sanity.test.js`

**Interfaces:**

- Consumes: Tasks 1-4 (schema, seed v2, metrics v2). The sync routes themselves need NO change - the event-type CHECK is DB-owned and 0004 already widened it; this task PROVES that through the real API.

- [ ] **Step 1: Update the E2E journey to the renamed event and chapter grain**

In `server/test/e2e_metrics_sanity.test.js`:

- the seed comment becomes `// CH1 -> QN1 (chapter_opened target + rated QnA)`
- the first app-event posted becomes:

```js
        {
          id: crypto.randomUUID(),
          event_type: "chapter_opened",
          content_id: "CH1",
          occurred_at: `${day}T10:00:00Z`,
          local_day: day,
        },
```

- the valid_recall assertions move to chapter grain:

```js
assert.strictEqual(
  Number(u1.valid_recall_chapters),
  1,
  ">=10s reveal + rating in week 1 -> 1 valid-recall chapter",
);
```

(the `valid_recall_qnas` and activation/d7 assertions keep their existing values - one user, one chapter, one qna).

- [ ] **Step 2: Run to verify it fails first, then passes**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test` BEFORE applying the edit if you want to see the red (it fails on `topic_opened` semantics only via the old seed - it is already red from Task 2's seed change). After the edit:
Expected: ALL server tests PASS. This is the E2E proof that a `chapter_opened` posted through the REAL `/sync/app-events` endpoint lands (CHECK admits it) and the dashboard SQL counts the user as activated with 1 valid-recall chapter - the "full study loop" E2E's server half (lane C's widget test covers the app half; the generated-content variant rides lane D's dry run).

- [ ] **Step 3: Commit**

```bash
git add server/test/e2e_metrics_sanity.test.js
git commit -m "test(server): e2e metrics sanity rides chapter_opened at chapter grain"
```

---

### Task 6: pagination stability test (>50 qnas) + lane sweep

**Files:**

- Create: `server/test/pagination.test.js`

**Interfaces:**

- Consumes: chapters route (Task 2). Proves the T5 renumber + id tiebreak: page 2 shows no repeated and no skipped questions on a >PAGE_SIZE chapter.

- [ ] **Step 1: Write the failing-or-green pagination test**

Create `server/test/pagination.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

const SECRETS = { v1: "s1" };
const pool = testPool();

test("page 2 of a 60-qna chapter has no repeats and no skips (sort_order + id tiebreak)", async () => {
  await resetUserData();
  const { spec } = await seedContent(pool);
  await pool.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ('CHBIG', $1, 'Big', 'big', 50, 1, 1) ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  // Deliberately IDENTICAL sort_order on every row: the id tiebreak alone
  // must keep pages disjoint and exhaustive (the C1 failure mode).
  for (let i = 0; i < 60; i++) {
    await pool.query(
      `INSERT INTO qnas (id, chapter_id, question, sections, sort_order)
       VALUES ($1, 'CHBIG', $2, '[]', 1) ON CONFLICT (id) DO NOTHING`,
      [`BIGQ${String(i).padStart(2, "0")}`, `q${i}`],
    );
  }
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','u1','x@y.z')
     ON CONFLICT (google_sub) DO NOTHING`,
  );
  const tok = signSession("u1", { secrets: SECRETS });
  const app = createApp({ pool, secrets: SECRETS });

  const p1 = await request(app)
    .get("/chapters/CHBIG/qnas?page=1")
    .set("Authorization", `Bearer ${tok}`);
  const p2 = await request(app)
    .get("/chapters/CHBIG/qnas?page=2")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(p1.status, 200);
  assert.strictEqual(p2.status, 200);
  assert.strictEqual(p1.body.pages, 2);
  const ids = [...p1.body.items, ...p2.body.items].map((q) => q.id);
  assert.strictEqual(ids.length, 60, "no skips");
  assert.strictEqual(new Set(ids).size, 60, "no repeats across pages");

  await pool.query(`DELETE FROM qnas WHERE chapter_id = 'CHBIG'`);
  await pool.query(`DELETE FROM chapters WHERE id = 'CHBIG'`);
});
```

Note: `u1` may already exist from other files; the ON CONFLICT insert makes this order-independent. `--test-concurrency=1` (already the server script) keeps the shared-DB writes serial.

- [ ] **Step 2: Run the FULL server suite**

Run (from `server/`): `TEST_DATABASE_URL=<disposable> npm test`
Expected: ALL PASS - the suite-red window is closed. If `sync.test.js`, `route_inventory.test.js`, or `schema_0003.test.js` show failures, read them: only event-type or content-shape assertions may need the `chapter_opened`/`chapter_id` equivalents (surgical edits, same pattern as Tasks 2-5); anything else is a real regression - stop and fix the route, not the test.

- [ ] **Step 3: Run the lane sweep**

Run (from repo root):

```bash
grep -rniE 'topic_id|topic_count|topicId|topics?\b' server/src server/test sql/metrics | grep -viE 'topical|topic_opened'
```

Expected: zero lines. (Allowed leftovers by design: `topic_opened` literals in `constants.js`, metrics IN-lists, and this criterion text in `sql/0004_drop_topics.sql` - the first two are filtered by the grep, the migration file is out of sweep scope.)

- [ ] **Step 4: Commit**

```bash
git add server/test/pagination.test.js
git commit -m "test(server): pagination stability across pages under duplicate sort_order"
```

---

## Self-review checklist (run before handing the lane off)

- 0004 applies cleanly from zero (`tools/db/apply.sh` on a fresh DB) AND on a v1-seeded DB (migration_0004 test proves the second).
- `chapter_opened` posted through the real sync API lands and activates (Task 5).
- `valid_recall_chapters` is the column name every consumer uses (metrics_pack, e2e, README).
- No topics identifier survives the sweep in `server/` or `sql/metrics/`.
- `manifest.js` and `chapters.js` both read `SCHEMA_VERSION` from `lib/constants.js` - one knob, bumped once.
