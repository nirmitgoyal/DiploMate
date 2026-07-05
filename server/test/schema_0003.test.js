const test = require("node:test");
const assert = require("node:assert");
const { testPool, resetUserData } = require("./helpers/setup");

const pool = testPool();

test("0003 tables exist with the contract columns", async () => {
  const { rows } = await pool.query(`
    SELECT table_name, column_name FROM information_schema.columns
    WHERE table_name IN ('users','entitlements','review_events','app_events','bookmarks','reports')
  `);
  const has = (t, c) =>
    rows.some((r) => r.table_name === t && r.column_name === c);
  assert.ok(has("users", "google_sub"));
  assert.ok(has("users", "speciality_change_count"));
  assert.ok(has("review_events", "local_day"));
  assert.ok(has("review_events", "synced_at"));
  assert.ok(has("app_events", "hidden_ms"));
  assert.ok(has("bookmarks", "deleted"));
  assert.ok(has("reports", "qna_id"));
});

test("rating + event_type CHECKs reject invalid values with named constraints", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1', 'sub1', 'a@b.c')`,
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'q1', 'easy', now(), now(), now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "review_events_rating_check",
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO app_events (id, user_id, event_type, occurred_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'pack_download_started', now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "app_events_event_type_check",
    "pack_download_* was removed with the downloads feature",
  );
});

test("event order CHECK holds and user delete cascades", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','sub1','a@b.c')`,
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'q1', 'good', now(), now() - interval '1 minute', now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "review_events_order_check",
  );
  await pool.query(
    `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
     VALUES (gen_random_uuid(), 'u1', 'q1', 'good', now() - interval '2m', now() - interval '1m', now(), '2026-07-04')`,
  );
  await pool.query(`DELETE FROM users WHERE id = 'u1'`);
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM review_events`,
  );
  assert.strictEqual(rows[0].n, 0, "ON DELETE CASCADE");
});
