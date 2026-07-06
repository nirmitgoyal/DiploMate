const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

const pool = testPool();
const packDir = path.join(__dirname, "..", "..", "sql", "metrics");

async function seedUserJourney(userId, { validRecall }) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1,$1,'x@y.z')
                    ON CONFLICT (google_sub) DO NOTHING`,
    [userId],
  );
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, occurred_at, local_day)
     VALUES ($1, $2, 'chapter_opened', 'CH1', '2026-07-01T10:00:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId],
  );
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, hidden_ms, occurred_at, local_day)
     VALUES ($1, $2, 'recall_revealed', 'QN1', $3, '2026-07-01T10:05:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId, validRecall ? 15000 : 3000],
  );
  await pool.query(
    `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
     VALUES ($1, $2, 'QN1', 'good', '2026-07-01T10:04:00Z', '2026-07-01T10:05:00Z', '2026-07-01T10:06:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId],
  );
}

test("metrics pack computes activation and validity from local_day windows", async () => {
  await resetUserData();
  await seedContent(pool);
  await seedUserJourney("honest", { validRecall: true });
  await seedUserJourney("skimmer", { validRecall: false }); // <10s reveal

  // Second valid recall for honest, same chapter (CH1), different QnA (QN2).
  // Proves D14 chapter-collapsing: 2 QnAs rated in 1 chapter -> chapters=1, qnas=2.
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, hidden_ms, occurred_at, local_day)
     VALUES ($1, 'honest', 'recall_revealed', 'QN2', 15000, '2026-07-01T10:15:00Z', '2026-07-01')`,
    [crypto.randomUUID()],
  );
  await pool.query(
    `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
     VALUES ($1, 'honest', 'QN2', 'good', '2026-07-01T10:14:00Z', '2026-07-01T10:15:00Z', '2026-07-01T10:16:00Z', '2026-07-01')`,
    [crypto.randomUUID()],
  );

  const activation = fs.readFileSync(
    path.join(packDir, "activation.sql"),
    "utf8",
  );
  const act = await pool.query(activation);
  assert.strictEqual(
    Number(act.rows[0].activated_users),
    2,
    "both opened a chapter",
  );

  const validRecall = fs.readFileSync(
    path.join(packDir, "valid_recall.sql"),
    "utf8",
  );
  const vr = await pool.query(validRecall);
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
});

test("pack files never window on synced_at (outside voice #12)", () => {
  for (const f of ["activation.sql", "valid_recall.sql", "d7_return.sql"]) {
    const sql = fs.readFileSync(path.join(packDir, f), "utf8");
    assert.ok(
      !/WHERE[^;]*synced_at/is.test(sql),
      `${f} must window on local_day, not synced_at`,
    );
  }
});

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
