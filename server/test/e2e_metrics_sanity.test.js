const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

// E2E metrics sanity: unlike metrics_pack.test.js (which hand-INSERTs event
// rows), this seeds ONE honest user journey through the REAL sync endpoints
// via supertest, then runs the exact sql/metrics/*.sql files the dashboard
// runs. It is the deploy-smoke rehearsal: proof the pack computes correctly
// against API-shaped data (server-stamped user_id, per-row insert path), not
// just against rows a test crafted by hand.

const SECRETS = { v1: "s1" };
const pool = testPool();
const packDir = path.join(__dirname, "..", "..", "sql", "metrics");

async function tokenFor(id) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1,$1,'x@y.z')
                    ON CONFLICT (google_sub) DO NOTHING`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

function sql(file) {
  return fs.readFileSync(path.join(packDir, file), "utf8");
}

test("metrics pack runs on one journey pushed through the real sync API", async () => {
  await resetUserData();
  await seedContent(pool); // CH1 -> QN1 (chapter_opened target + rated QnA)
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const day = "2026-07-01";

  // app-events: opened the topic (activation), then revealed the answer with
  // the answer hidden >= 10s (valid recall per D9). Both land via POST, so the
  // server stamps user_id from the JWT - exactly the launch path.
  const ae = await request(app)
    .post("/sync/app-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      events: [
        {
          id: crypto.randomUUID(),
          event_type: "chapter_opened",
          content_id: "CH1",
          occurred_at: `${day}T10:00:00Z`,
          local_day: day,
        },
        {
          id: crypto.randomUUID(),
          event_type: "recall_revealed",
          content_id: "QN1",
          hidden_ms: 15000,
          occurred_at: `${day}T10:05:00Z`,
          local_day: day,
        },
      ],
    });
  assert.strictEqual(ae.status, 200);
  assert.strictEqual(ae.body.inserted, 2, "both app-events landed");

  // review-events: rated that QnA good, same local_day.
  const re = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      events: [
        {
          id: crypto.randomUUID(),
          content_id: "QN1",
          rating: "good",
          shown_at: `${day}T10:04:00Z`,
          revealed_at: `${day}T10:05:00Z`,
          rated_at: `${day}T10:06:00Z`,
          local_day: day,
        },
      ],
    });
  assert.strictEqual(re.status, 200);
  assert.strictEqual(re.body.inserted, 1, "the rating landed");

  // Now the actual dashboard SQL, unedited, over that API-written data.
  const act = await pool.query(sql("activation.sql"));
  assert.strictEqual(
    Number(act.rows[0].activated_users),
    1,
    "one user opened a topic -> activated",
  );

  const vr = await pool.query(sql("valid_recall.sql"));
  const u1 = vr.rows.find((r) => r.user_id === "u1");
  assert.ok(u1, "the journeying user appears in valid_recall");
  assert.strictEqual(
    Number(u1.valid_recall_chapters),
    1,
    ">=10s reveal + rating in week 1 -> 1 valid-recall chapter",
  );
  assert.strictEqual(Number(u1.valid_recall_qnas), 1, "exactly one QnA rated");

  const d7 = await pool.query(sql("d7_return.sql"));
  assert.strictEqual(
    Number(d7.rows[0].activated_users),
    1,
    "activation cohort = 1",
  );
  assert.strictEqual(
    Number(d7.rows[0].returned_d7),
    0,
    "single-day journey has no event on d0+7 -> no D7 return",
  );
});
