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
