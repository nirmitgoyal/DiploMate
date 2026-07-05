# Day-1 Content DDL Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Commit the day-1 v0 content schema (sql/0001_content_v0.sql), the 61-speciality seed (sql/0002_seed_specialities.sql), an apply script, and a contract test suite that pins tables, columns, and CHECK constraint names as the A/B/C lane contract (ENG-T20 + the DDL-ownership half of ENG-T16).

**Architecture:** Plain numbered SQL files in sql/ are the single schema truth, applied in filename order (heroku pg:psql in prod, tools/db/apply.sh locally/CI). A node:test + pg suite runs against a disposable Postgres and asserts the exact shape, including the ABSENCE of the removed downloads-era columns. No ORM, no migration framework.

**Tech Stack:** PostgreSQL 16, bash + psql, Node 22 LTS, node:test, pg (npm).

## Global Constraints

Copied from the shared interface contract (trimmed to what this plan touches):

- NEVER use em-dashes or en-dashes in any file, code, comment, UI copy, or doc; plain hyphens only (user convention).
- NO offline Downloads feature (founder, 2026-07-04 evening): chapters carries `content_version` (publisher-bumped, cache-invalidation key); there is NO `bundle_version`, NO `bundle_sha256`, NO `download_bytes` on chapters and NO `row_hash` on qnas. The contract tests assert these columns are absent.
- sql/ migrations are append-only numbered files (0001*..., 0002*...) applied in filename order via `heroku pg:psql < sql/NNNN_*.sql` in prod; CI applies the same files to a disposable Postgres from zero. The T2 ingestion spike AMENDS via new migrations, never redefines.
- Wire enums are owned by sql/ DDL as named CHECK constraints (D7 addendum, Issue 5A). The API maps a Postgres CHECK violation to HTTP 400 `{error: 'constraint_violation', constraint: '<name>'}` (never 500) and does NOT re-validate enum membership. Constraint NAMES are therefore wire contract: `specialities_exam_type_check`, `images_byte_size_check`.
- Content IDs are ULIDs (26-char Crockford base32 TEXT) - opaque identity; slugs/titles are mutable path metadata (A4).
- exam_type enum: `'DNB' | 'DrNB'`. 61 tracks total: 30 DNB broad + 31 DrNB super; beta data = Anaesthesia only (TD3). Anaesthesiology's seeded ULID is the beta content anchor.
- qnas.sections is JSONB `[{"key": "...", "heading": "...", "body_md": "..."}]` and earns_marks is JSONB `[{"label": "...", "section_key": "..."}]` (D16 schema coupling, encoded from the first spike).
- images.byte_size capped at 204800 (<=200KB per image); sha256 column is the HTTP ETag.
- Beta flag is the `app_config.beta_active` DB row (value `'true'`), deliberately NOT a config var.
- FREE BETA (PG3): entitlement schema + middleware ship in final shape, but they live in the server plan (sql/0003), not here.
- TDD: every task = failing test -> minimal code -> pass -> commit.

## File Structure

```
sql/
  0001_content_v0.sql        content schema + app_config + beta_active row
  0002_seed_specialities.sql 61 speciality rows, fixed ULIDs
  README.md                  append-only migration policy
tools/db/
  apply.sh                   applies sql/*.sql in filename order to $DATABASE_URL
  package.json               node:test harness deps (pg)
  test/schema.test.js        table/column/constraint contract tests
  test/seed.test.js          61-row seed tests
```

Authoritative speciality list: the speciality-onboarding spec (docs/superpowers/specs/2026-07-03-speciality-onboarding-design.md) says "Row inventory lives in SPEC_DNB / SPEC_DRNB in the source (61 total)"; those arrays are at prototype/index.html lines 544-545. This plan seeds those 61 names verbatim.

ULID choice (stated per scope): the seed ULIDs are fixed, hand-minted, valid 26-char Crockford base32 strings with a constant time prefix `01JZSP3C00` and a readable suffix (`DNB...NNN` / `DRNB...NNN`). They are opaque TEXT identity (A4); nothing may parse them. sort_order is global 1..61 (DNB alphabetical 1-30, then DrNB alphabetical 31-61) matching the prototype's alphabetical group order.

---

### Task 1: sql/0001_content_v0.sql + apply script + shape contract tests

**Files:**

- Create: `sql/0001_content_v0.sql`
- Create: `sql/README.md`
- Create: `tools/db/apply.sh`
- Create: `tools/db/package.json`
- Test: `tools/db/test/schema.test.js`

**Interfaces:**

- Consumes: nothing (first task in the repo's SQL lane). Requires a disposable Postgres reachable via `$DATABASE_URL` and `psql` on PATH.
- Produces:
  - Tables `app_config(key TEXT PK, value TEXT NOT NULL)`, `specialities(id, name, exam_type, slug, sort_order)`, `chapters(id, speciality_id, title, slug, sort_order, exam_weight, content_version)`, `topics(id, chapter_id, title, slug, exam_theme, sort_order)`, `qnas(id, topic_id, question, years, marks, earns_marks, sections, sort_order)`, `images(id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)`. The server plan (2026-07-04-server-api.md) reads these for `/manifest`, `/chapters/:chapterId/qnas`, `/images/:id`; the ingestion plan (2026-07-04-ingestion-pipeline.md) INSERTs into them via new numbered migrations.
  - Named CHECK constraints `specialities_exam_type_check` and `images_byte_size_check` - the server's errors middleware maps violations of these names to HTTP 400 `{error: 'constraint_violation', constraint: '<name>'}`.
  - Row `app_config('beta_active', 'true')` - read by the server entitlement middleware clause `(SELECT value FROM app_config WHERE key='beta_active') = 'true'`.
  - `tools/db/apply.sh` - CI and the integration plan invoke it to build a schema from zero.

- [ ] **Step 1: Start a disposable Postgres and export DATABASE_URL**

```bash
docker run --rm -d --name diplomate-ddl-pg -e POSTGRES_PASSWORD=postgres -p 5433:5432 postgres:16
export DATABASE_URL=postgres://postgres:postgres@localhost:5433/postgres
```

Expected: container id printed. (If a local Postgres already runs, any empty database URL works instead; every apply below starts from a schema reset.)

- [ ] **Step 2: Create the test harness package**

Create `tools/db/package.json`:

```json
{
  "name": "diplomate-db-tools",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test test/"
  },
  "dependencies": {
    "pg": "^8.12.0"
  }
}
```

Run: `cd /Users/nirmit/Codebases/DiploMate/tools/db && npm install`
Expected: `added 1 package` (plus deps), no errors.

- [ ] **Step 3: Write the failing shape contract test**

Create `tools/db/test/schema.test.js`:

```js
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
before(() => client.connect());
after(() => client.end());

async function columns(table) {
  const r = await client.query(
    `SELECT column_name FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1
     ORDER BY column_name`,
    [table],
  );
  return r.rows.map((x) => x.column_name);
}

// Exact column sets: deepEqual pins presence AND absence in one assertion.
// chapters must NOT have bundle_version/bundle_sha256/download_bytes;
// qnas must NOT have row_hash (NO OFFLINE DOWNLOADS revision, 2026-07-04).

test("app_config columns exact", async () => {
  assert.deepEqual(await columns("app_config"), ["key", "value"]);
});

test("specialities columns exact", async () => {
  assert.deepEqual(await columns("specialities"), [
    "exam_type",
    "id",
    "name",
    "slug",
    "sort_order",
  ]);
});

test("chapters columns exact (content_version in, bundle columns out)", async () => {
  assert.deepEqual(await columns("chapters"), [
    "content_version",
    "exam_weight",
    "id",
    "slug",
    "sort_order",
    "speciality_id",
    "title",
  ]);
});

test("topics columns exact", async () => {
  assert.deepEqual(await columns("topics"), [
    "chapter_id",
    "exam_theme",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
});

test("qnas columns exact (no row_hash)", async () => {
  assert.deepEqual(await columns("qnas"), [
    "earns_marks",
    "id",
    "marks",
    "question",
    "sections",
    "sort_order",
    "topic_id",
    "years",
  ]);
});

test("images columns exact", async () => {
  assert.deepEqual(await columns("images"), [
    "byte_size",
    "caption",
    "content_description",
    "id",
    "qna_id",
    "sha256",
    "sort_order",
    "webp",
  ]);
});

test("beta_active row is true", async () => {
  const r = await client.query(
    `SELECT value FROM app_config WHERE key = 'beta_active'`,
  );
  assert.equal(r.rows.length, 1);
  assert.equal(r.rows[0].value, "true");
});
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd /Users/nirmit/Codebases/DiploMate/tools/db && npm test`
Expected: FAIL - all 7 tests fail (`deepEqual` mismatch against `[]` for the 6 column tests because the tables do not exist yet; the beta_active test errors with `relation "app_config" does not exist`).

- [ ] **Step 5: Write the DDL, verbatim from the shared contract**

Create `sql/0001_content_v0.sql`:

```sql
-- 0001_content_v0.sql - day-1 v0 content DDL, the A/B/C lane contract (T20).
-- Append-only: never edit this file after it ships; amend via a NEW numbered
-- migration. Wire enums live here as named CHECK constraints (D7/5A); the API
-- maps violations to HTTP 400 with the constraint name.
-- IDs are ULIDs (26-char Crockford base32 TEXT) minted by the ingestion
-- pipeline - opaque identity; slugs/titles are mutable path metadata (A4).

CREATE TABLE app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT INTO app_config (key, value) VALUES ('beta_active', 'true');

CREATE TABLE specialities (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  exam_type  TEXT NOT NULL CONSTRAINT specialities_exam_type_check
             CHECK (exam_type IN ('DNB','DrNB')),
  slug       TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE chapters (
  id              TEXT PRIMARY KEY,
  speciality_id   TEXT NOT NULL REFERENCES specialities(id),
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  exam_weight     INTEGER NOT NULL DEFAULT 0,
  content_version INTEGER NOT NULL DEFAULT 0,   -- bumped by publisher; cache invalidation
  UNIQUE (speciality_id, slug)
);

CREATE TABLE topics (
  id         TEXT PRIMARY KEY,
  chapter_id TEXT NOT NULL REFERENCES chapters(id),
  title      TEXT NOT NULL,
  slug       TEXT NOT NULL,
  exam_theme TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (chapter_id, slug)
);

CREATE TABLE qnas (
  id          TEXT PRIMARY KEY,
  topic_id    TEXT NOT NULL REFERENCES topics(id),
  question    TEXT NOT NULL,
  years       TEXT,                -- e.g. '2019, 2022' (PYQ appearances)
  marks       INTEGER,
  earns_marks JSONB NOT NULL DEFAULT '[]',
    -- [{"label": "...", "section_key": "definition"}] - anchor links to sections
  sections    JSONB NOT NULL,
    -- [{"key": "definition", "heading": "Definition", "body_md": "..."}]
    -- D16 schema coupling: section structure encoded from the first spike
  sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE images (
  id                  TEXT PRIMARY KEY,
  qna_id              TEXT NOT NULL REFERENCES qnas(id),
  caption             TEXT NOT NULL,
  content_description TEXT NOT NULL,   -- TalkBack description (D20)
  webp                BYTEA NOT NULL,
  byte_size           INTEGER NOT NULL CONSTRAINT images_byte_size_check
                      CHECK (byte_size <= 204800),
  sha256              TEXT NOT NULL,   -- ETag for HTTP caching
  sort_order          INTEGER NOT NULL DEFAULT 0
);
```

- [ ] **Step 6: Write the apply script**

Create `tools/db/apply.sh`:

```bash
#!/usr/bin/env bash
# Applies sql/*.sql to $DATABASE_URL in filename order.
# Migrations are append-only; prod uses `heroku pg:psql < sql/NNNN_*.sql`.
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must be set}"
SQL_DIR="$(cd "$(dirname "$0")/../../sql" && pwd)"
for f in "$SQL_DIR"/[0-9]*.sql; do
  echo "applying $(basename "$f")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

Run: `chmod +x /Users/nirmit/Codebases/DiploMate/tools/db/apply.sh`
Expected: no output.

- [ ] **Step 7: Apply from zero**

```bash
psql "$DATABASE_URL" -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
/Users/nirmit/Codebases/DiploMate/tools/db/apply.sh
```

Expected output includes `applying 0001_content_v0.sql`, then `CREATE TABLE` lines and `INSERT 0 1`, exit code 0.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd /Users/nirmit/Codebases/DiploMate/tools/db && npm test`
Expected: PASS - `tests 7`, `pass 7`, `fail 0`.

- [ ] **Step 9: Write sql/README.md**

Create `sql/README.md`:

```markdown
# sql/ - schema migrations

- Numbered files (0001*..., 0002*...) are the single schema truth.
- Append-only: NEVER edit a shipped migration; amend with a NEW numbered
  file. The T2 ingestion spike AMENDS via new migrations, never redefines.
- Prod apply: `heroku pg:psql < sql/NNNN_name.sql`, in filename order.
- Local/CI apply from zero: `tools/db/apply.sh` (reads `$DATABASE_URL`).
- Wire enums are owned here as named CHECK constraints (D7/5A). The API maps
  a CHECK violation to HTTP 400 `{error: 'constraint_violation',
constraint: '<name>'}` and never re-validates enum membership. Renaming a
  constraint is a wire-contract change.
- Contract tests: `cd tools/db && npm test` (needs a disposable Postgres in
  `$DATABASE_URL` with the migrations applied).
```

- [ ] **Step 10: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add sql/0001_content_v0.sql sql/README.md tools/db/apply.sh tools/db/package.json tools/db/package-lock.json tools/db/test/schema.test.js
git commit -m "feat(sql): day-1 v0 content DDL, apply script, shape contract tests (ENG-T20)"
```

---

### Task 2: CHECK constraint name contract tests (ENG-T16 DDL-ownership half)

**Files:**

- Modify: `tools/db/test/schema.test.js` (append tests at end of file)

**Interfaces:**

- Consumes: Task 1's applied schema (constraints `specialities_exam_type_check`, `images_byte_size_check`) and its pg `client` already defined at the top of `schema.test.js`.
- Produces: pinned constraint names as executable contract. The server plan's errors middleware (2026-07-04-server-api.md) relies on the pg error's `.constraint` property carrying exactly these names to build 400 `{error: 'constraint_violation', constraint: '<name>'}`. The server and Dart constants files each carry a comment pointing at `sql/0001_content_v0.sql` as the enum owner; those files belong to the server and Flutter plans.

Note on TDD: these tests pass immediately because the contract requires the constraints to ship inside 0001 verbatim (Task 1). They are not driving new code; they pin the constraint NAMES as wire contract so a future rename fails CI. This is the one deliberate exception to fail-first in this plan.

- [ ] **Step 1: Append the constraint tests**

Append to `tools/db/test/schema.test.js` (after the `beta_active` test):

```js
test("invalid exam_type is rejected by specialities_exam_type_check", async () => {
  await client.query("BEGIN");
  const err = await client
    .query(
      `INSERT INTO specialities (id, name, exam_type, slug)
       VALUES ('0000000000000000000000TEST', 'Test', 'MD', 'test-exam-type')`,
    )
    .then(
      () => null,
      (e) => e,
    );
  await client.query("ROLLBACK");
  assert.ok(err, "insert with exam_type MD must fail");
  assert.equal(err.constraint, "specialities_exam_type_check");
});

test("images byte_size over 204800 is rejected by images_byte_size_check", async () => {
  await client.query("BEGIN");
  await client.query(
    `INSERT INTO specialities (id, name, exam_type, slug)
     VALUES ('0000000000000000000000TSPC', 'Tmp', 'DNB', 'tmp-spec')`,
  );
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug)
     VALUES ('0000000000000000000000TCHP', '0000000000000000000000TSPC', 'Tmp', 'tmp-ch')`,
  );
  await client.query(
    `INSERT INTO topics (id, chapter_id, title, slug)
     VALUES ('0000000000000000000000TTPC', '0000000000000000000000TCHP', 'Tmp', 'tmp-tp')`,
  );
  await client.query(
    `INSERT INTO qnas (id, topic_id, question, sections)
     VALUES ('0000000000000000000000TQNA', '0000000000000000000000TTPC', 'Q?', '[]')`,
  );
  const err = await client
    .query(
      `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256)
       VALUES ('0000000000000000000000TIMG', '0000000000000000000000TQNA', 'c', 'd', '\\x00', 204801, 'deadbeef')`,
    )
    .then(
      () => null,
      (e) => e,
    );
  await client.query("ROLLBACK");
  assert.ok(err, "insert with byte_size 204801 must fail");
  assert.equal(err.constraint, "images_byte_size_check");
});
```

- [ ] **Step 2: Run the tests**

Run: `cd /Users/nirmit/Codebases/DiploMate/tools/db && npm test`
Expected: PASS - `tests 9`, `pass 9`, `fail 0`. Both new tests roll back their rows, so the database is unchanged afterwards.

- [ ] **Step 3: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add tools/db/test/schema.test.js
git commit -m "test(sql): pin CHECK constraint names as wire contract (ENG-T16 DDL half)"
```

---

### Task 3: sql/0002_seed_specialities.sql - all 61 tracks with fixed ULIDs

**Files:**

- Create: `sql/0002_seed_specialities.sql`
- Test: `tools/db/test/seed.test.js`

**Interfaces:**

- Consumes: Task 1's `specialities` table and `tools/db/apply.sh`.
- Produces: 61 speciality rows (30 `exam_type='DNB'` + 31 `exam_type='DrNB'`), sort_order global 1..61. Fixed ULIDs with prefix `01JZSP3C00`. The beta content anchor consumed by the ingestion plan (2026-07-04-ingestion-pipeline.md) is Anaesthesiology's id `01JZSP3C00DNB0000000000001`. The server plan's `/manifest` reads these rows for its `specialities` array; the Flutter plan's speciality picker renders the same 61 names (its `SPEC_DNB`/`SPEC_DRNB` copy must match this seed).

Names are verbatim from `SPEC_DNB`/`SPEC_DRNB` in prototype/index.html (lines 544-545), the row inventory the onboarding spec designates as the source. Slugs are lowercase, non-alphanumerics collapsed to single hyphens, `&` spelled `and`.

- [ ] **Step 1: Write the failing seed test**

Create `tools/db/test/seed.test.js`:

```js
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
before(() => client.connect());
after(() => client.end());

test("61 specialities seeded: 30 DNB + 31 DrNB", async () => {
  const r = await client.query(
    `SELECT exam_type, count(*)::int AS n FROM specialities
     GROUP BY exam_type ORDER BY exam_type`,
  );
  assert.deepEqual(r.rows, [
    { exam_type: "DNB", n: 30 },
    { exam_type: "DrNB", n: 31 },
  ]);
});

test("every id is a 26-char Crockford base32 ULID and slugs are unique", async () => {
  const r = await client.query(`SELECT id, slug FROM specialities`);
  const ulid = /^[0-9A-HJKMNP-TV-Z]{26}$/;
  for (const row of r.rows) {
    assert.match(row.id, ulid, `bad ULID: ${row.id}`);
  }
  const slugs = r.rows.map((x) => x.slug);
  assert.equal(new Set(slugs).size, 61);
});

test("Anaesthesiology anchor ULID is fixed (beta content anchor)", async () => {
  const r = await client.query(
    `SELECT name, exam_type, slug, sort_order FROM specialities
     WHERE id = '01JZSP3C00DNB0000000000001'`,
  );
  assert.equal(r.rows.length, 1);
  assert.deepEqual(r.rows[0], {
    name: "Anaesthesiology",
    exam_type: "DNB",
    slug: "anaesthesiology",
    sort_order: 1,
  });
});

test("sort_order is global 1..61 with no gaps", async () => {
  const r = await client.query(
    `SELECT sort_order FROM specialities ORDER BY sort_order`,
  );
  assert.deepEqual(
    r.rows.map((x) => x.sort_order),
    Array.from({ length: 61 }, (_, i) => i + 1),
  );
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/nirmit/Codebases/DiploMate/tools/db && npm test`
Expected: FAIL - the 4 seed tests fail (counts are 0 rows, anchor row missing); the 9 schema tests still pass.

- [ ] **Step 3: Write the seed migration**

Create `sql/0002_seed_specialities.sql`:

```sql
-- 0002_seed_specialities.sql - all 61 DNB/DrNB exam tracks.
-- Names verbatim from SPEC_DNB/SPEC_DRNB (speciality-onboarding spec row
-- inventory). Fixed hand-minted ULIDs (prefix 01JZSP3C00) - opaque identity,
-- never parsed. Anaesthesiology (01JZSP3C00DNB0000000000001) is the beta
-- content anchor. sort_order is global: DNB 1-30, DrNB 31-61.

INSERT INTO specialities (id, name, exam_type, slug, sort_order) VALUES
  ('01JZSP3C00DNB0000000000001', 'Anaesthesiology', 'DNB', 'anaesthesiology', 1),
  ('01JZSP3C00DNB0000000000002', 'Anatomy', 'DNB', 'anatomy', 2),
  ('01JZSP3C00DNB0000000000003', 'Biochemistry', 'DNB', 'biochemistry', 3),
  ('01JZSP3C00DNB0000000000004', 'Community Medicine', 'DNB', 'community-medicine', 4),
  ('01JZSP3C00DNB0000000000005', 'Dermatology, Venereology and Leprosy', 'DNB', 'dermatology-venereology-and-leprosy', 5),
  ('01JZSP3C00DNB0000000000006', 'Emergency Medicine', 'DNB', 'emergency-medicine', 6),
  ('01JZSP3C00DNB0000000000007', 'Family Medicine', 'DNB', 'family-medicine', 7),
  ('01JZSP3C00DNB0000000000008', 'Forensic Medicine', 'DNB', 'forensic-medicine', 8),
  ('01JZSP3C00DNB0000000000009', 'General Medicine', 'DNB', 'general-medicine', 9),
  ('01JZSP3C00DNB0000000000010', 'General Surgery', 'DNB', 'general-surgery', 10),
  ('01JZSP3C00DNB0000000000011', 'Hospital Administration', 'DNB', 'hospital-administration', 11),
  ('01JZSP3C00DNB0000000000012', 'Immunohematology and Blood Transfusion', 'DNB', 'immunohematology-and-blood-transfusion', 12),
  ('01JZSP3C00DNB0000000000013', 'Maternal and Child Health', 'DNB', 'maternal-and-child-health', 13),
  ('01JZSP3C00DNB0000000000014', 'Microbiology', 'DNB', 'microbiology', 14),
  ('01JZSP3C00DNB0000000000015', 'Nuclear Medicine', 'DNB', 'nuclear-medicine', 15),
  ('01JZSP3C00DNB0000000000016', 'Obstetrics and Gynaecology', 'DNB', 'obstetrics-and-gynaecology', 16),
  ('01JZSP3C00DNB0000000000017', 'Ophthalmology', 'DNB', 'ophthalmology', 17),
  ('01JZSP3C00DNB0000000000018', 'Orthopaedics', 'DNB', 'orthopaedics', 18),
  ('01JZSP3C00DNB0000000000019', 'Otorhinolaryngology (ENT)', 'DNB', 'otorhinolaryngology-ent', 19),
  ('01JZSP3C00DNB0000000000020', 'Paediatrics', 'DNB', 'paediatrics', 20),
  ('01JZSP3C00DNB0000000000021', 'Palliative Medicine', 'DNB', 'palliative-medicine', 21),
  ('01JZSP3C00DNB0000000000022', 'Pathology', 'DNB', 'pathology', 22),
  ('01JZSP3C00DNB0000000000023', 'Pharmacology', 'DNB', 'pharmacology', 23),
  ('01JZSP3C00DNB0000000000024', 'Physical Medicine and Rehabilitation', 'DNB', 'physical-medicine-and-rehabilitation', 24),
  ('01JZSP3C00DNB0000000000025', 'Physiology', 'DNB', 'physiology', 25),
  ('01JZSP3C00DNB0000000000026', 'Psychiatry', 'DNB', 'psychiatry', 26),
  ('01JZSP3C00DNB0000000000027', 'Radiation Oncology', 'DNB', 'radiation-oncology', 27),
  ('01JZSP3C00DNB0000000000028', 'Radio Diagnosis', 'DNB', 'radio-diagnosis', 28),
  ('01JZSP3C00DNB0000000000029', 'Respiratory Medicine', 'DNB', 'respiratory-medicine', 29),
  ('01JZSP3C00DNB0000000000030', 'Trauma and Acute Care Surgery', 'DNB', 'trauma-and-acute-care-surgery', 30),
  ('01JZSP3C00DRNB000000000001', 'Cardiac Anaesthesia', 'DrNB', 'cardiac-anaesthesia', 31),
  ('01JZSP3C00DRNB000000000002', 'Cardiology', 'DrNB', 'cardiology', 32),
  ('01JZSP3C00DRNB000000000003', 'Cardiovascular & Thoracic Surgery', 'DrNB', 'cardiovascular-and-thoracic-surgery', 33),
  ('01JZSP3C00DRNB000000000004', 'Clinical Haematology', 'DrNB', 'clinical-haematology', 34),
  ('01JZSP3C00DRNB000000000005', 'Clinical Immunology & Rheumatology', 'DrNB', 'clinical-immunology-and-rheumatology', 35),
  ('01JZSP3C00DRNB000000000006', 'Critical Care Medicine', 'DrNB', 'critical-care-medicine', 36),
  ('01JZSP3C00DRNB000000000007', 'Endocrinology', 'DrNB', 'endocrinology', 37),
  ('01JZSP3C00DRNB000000000008', 'Gynaecological Oncology', 'DrNB', 'gynaecological-oncology', 38),
  ('01JZSP3C00DRNB000000000009', 'Head and Neck Oncology', 'DrNB', 'head-and-neck-oncology', 39),
  ('01JZSP3C00DRNB000000000010', 'Infectious Disease', 'DrNB', 'infectious-disease', 40),
  ('01JZSP3C00DRNB000000000011', 'Interventional Radiology', 'DrNB', 'interventional-radiology', 41),
  ('01JZSP3C00DRNB000000000012', 'Medical Gastroenterology', 'DrNB', 'medical-gastroenterology', 42),
  ('01JZSP3C00DRNB000000000013', 'Medical Genetics', 'DrNB', 'medical-genetics', 43),
  ('01JZSP3C00DRNB000000000014', 'Medical Oncology', 'DrNB', 'medical-oncology', 44),
  ('01JZSP3C00DRNB000000000015', 'Neonatology', 'DrNB', 'neonatology', 45),
  ('01JZSP3C00DRNB000000000016', 'Nephrology', 'DrNB', 'nephrology', 46),
  ('01JZSP3C00DRNB000000000017', 'Neuro Anaesthesia', 'DrNB', 'neuro-anaesthesia', 47),
  ('01JZSP3C00DRNB000000000018', 'Neurology', 'DrNB', 'neurology', 48),
  ('01JZSP3C00DRNB000000000019', 'Neurosurgery', 'DrNB', 'neurosurgery', 49),
  ('01JZSP3C00DRNB000000000020', 'Paediatric Cardiology', 'DrNB', 'paediatric-cardiology', 50),
  ('01JZSP3C00DRNB000000000021', 'Paediatric Critical Care', 'DrNB', 'paediatric-critical-care', 51),
  ('01JZSP3C00DRNB000000000022', 'Paediatric Haemato-Oncology', 'DrNB', 'paediatric-haemato-oncology', 52),
  ('01JZSP3C00DRNB000000000023', 'Paediatric Neurology', 'DrNB', 'paediatric-neurology', 53),
  ('01JZSP3C00DRNB000000000024', 'Paediatric Surgery', 'DrNB', 'paediatric-surgery', 54),
  ('01JZSP3C00DRNB000000000025', 'Plastic & Reconstructive Surgery', 'DrNB', 'plastic-and-reconstructive-surgery', 55),
  ('01JZSP3C00DRNB000000000026', 'Pulmonary Medicine', 'DrNB', 'pulmonary-medicine', 56),
  ('01JZSP3C00DRNB000000000027', 'Surgical Gastroenterology', 'DrNB', 'surgical-gastroenterology', 57),
  ('01JZSP3C00DRNB000000000028', 'Surgical Oncology', 'DrNB', 'surgical-oncology', 58),
  ('01JZSP3C00DRNB000000000029', 'Thoracic Surgery', 'DrNB', 'thoracic-surgery', 59),
  ('01JZSP3C00DRNB000000000030', 'Urology', 'DrNB', 'urology', 60),
  ('01JZSP3C00DRNB000000000031', 'Vascular Surgery', 'DrNB', 'vascular-surgery', 61);
```

- [ ] **Step 4: Apply from zero and run the tests**

```bash
psql "$DATABASE_URL" -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
/Users/nirmit/Codebases/DiploMate/tools/db/apply.sh
cd /Users/nirmit/Codebases/DiploMate/tools/db && npm test
```

Expected: apply output shows `applying 0001_content_v0.sql` then `applying 0002_seed_specialities.sql` (filename order) ending with `INSERT 0 61`; then PASS - `tests 13`, `pass 13`, `fail 0`.

- [ ] **Step 5: Commit and stop the disposable Postgres**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add sql/0002_seed_specialities.sql tools/db/test/seed.test.js
git commit -m "feat(sql): seed 61 DNB/DrNB specialities with fixed ULIDs"
docker stop diplomate-ddl-pg
```

---

## Coverage

| Source task                                                                                                                                       | Plan task(s)  |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| ENG-T20 (day-1 v0 content DDL as the A/B/C lane contract: 3+1 tables, D16 section array, A4 opaque IDs, wire enums, spike amends never redefines) | Tasks 1, 2, 3 |
| ENG-T16, DDL-ownership half (sql/ owns wire enums + CHECK constraints; constraint names are wire contract)                                        | Tasks 1, 2    |
| Seed of the 61 specialities (contract 0002, Anaesthesia anchor ULID)                                                                              | Task 3        |

Out of scope (owned by neighboring plans):

- `sql/0003_users_events.sql` (users, entitlements, review_events, app_events, bookmarks, reports), the API mapping of CHECK violations to 400, the server constants file commenting the DDL owner, entitlement middleware reading `beta_active`: 2026-07-04-server-api.md
- Content INSERT migrations (Anaesthesia chapters/topics/qnas/images), ULID minting tooling, `content_version` bumps by the publisher: 2026-07-04-ingestion-pipeline.md
- Dart constants file with the DDL-owner comment, speciality picker UI over the same 61 names: 2026-07-04-flutter-shell-screens.md
- drift mirror tables of this content shape: 2026-07-04-study-loop-srs.md
- Heroku Postgres provisioning and the prod `heroku pg:psql` apply run, deploy smoke: 2026-07-04-integration-release.md
