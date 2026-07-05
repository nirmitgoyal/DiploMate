const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const crypto = require("node:crypto");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

async function tokenFor(id) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1,$1,'x@y.z')
                    ON CONFLICT (google_sub) DO NOTHING`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

function reviewEvent(overrides = {}) {
  const t = new Date("2026-07-04T10:00:00Z");
  return {
    id: crypto.randomUUID(),
    content_id: "QN1",
    rating: "good",
    shown_at: new Date(t.getTime() - 120000).toISOString(),
    revealed_at: new Date(t.getTime() - 60000).toISOString(),
    rated_at: t.toISOString(),
    local_day: "2026-07-04",
    ...overrides,
  };
}

test("idempotent insert: duplicate sync retries cannot double-count (critical gap 3)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const e = reviewEvent();

  const first = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [e] });
  assert.strictEqual(first.status, 200);
  assert.strictEqual(first.body.inserted, 1);

  const retry = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [e] });
  assert.strictEqual(retry.body.inserted, 0);
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM review_events`,
  );
  assert.strictEqual(rows[0].n, 1);
});

test("poison row falls back per-row; rest of batch lands (T4)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const good = reviewEvent();
  const poison = reviewEvent({ rating: "easy" }); // invalid wire value

  const res = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [good, poison] });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.inserted, 1);
  assert.strictEqual(res.body.rejected.length, 1);
  assert.strictEqual(res.body.rejected[0].id, poison.id);
  assert.match(res.body.rejected[0].error, /review_events_rating_check/);
});

test("null/malformed array element is isolated per-row, not batch-fatal (T4)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const good = reviewEvent();
  const res = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [good, null] });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.inserted, 1);
  assert.strictEqual(res.body.rejected.length, 1);
});

test("server stamps user_id from the JWT - body cannot write cross-user", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tokA = await tokenFor("userA");
  await tokenFor("userB");
  await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tokA}`)
    .send({ events: [{ ...reviewEvent(), user_id: "userB" }] });
  const { rows } = await pool.query(`SELECT user_id FROM review_events`);
  assert.strictEqual(rows[0].user_id, "userA");
});

test("timestamp skew: rated_at >48h ahead is rejected per-row", async () => {
  await resetUserData();
  const app = createApp({
    pool,
    secrets: SECRETS,
    now: () => new Date("2026-07-04T10:00:00Z"),
  });
  const tok = await tokenFor("u1");
  const skewed = reviewEvent({
    shown_at: "2026-07-10T10:00:00Z",
    revealed_at: "2026-07-10T10:01:00Z",
    rated_at: "2026-07-10T10:02:00Z",
  });
  const res = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [skewed] });
  assert.strictEqual(res.body.inserted, 0);
  assert.strictEqual(res.body.rejected[0].error, "timestamp_skew");
});

test("app-events: same pattern incl. hidden_ms; event enum owned by DDL", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const res = await request(app)
    .post("/sync/app-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      events: [
        {
          id: crypto.randomUUID(),
          event_type: "recall_revealed",
          content_id: "QN1",
          hidden_ms: 12000,
          occurred_at: "2026-07-04T10:00:00Z",
          local_day: "2026-07-04",
        },
      ],
    });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.inserted, 1);
});

test("no UPDATE/DELETE surface exists for event tables (append-only)", async () => {
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  for (const method of ["put", "patch", "delete"]) {
    for (const path of ["/sync/review-events", "/sync/app-events"]) {
      const res = await request(app)
        [method](path)
        .set("Authorization", `Bearer ${tok}`);
      assert.strictEqual(res.status, 404, `${method.toUpperCase()} ${path}`);
    }
  }
});
