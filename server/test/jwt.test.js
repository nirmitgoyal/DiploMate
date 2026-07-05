const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const express = require("express");
const { signSession, verifySession } = require("../src/lib/jwt");
const { requireAuth } = require("../src/middleware/auth");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v2: "new-secret", v1: "old-secret" }; // first key signs
const DAY = 86400000;
const pool = testPool();

function appWith(now) {
  const app = express();
  app.locals.pool = pool;
  app.locals.secrets = SECRETS;
  app.locals.now = now;
  app.get("/probe", requireAuth, (req, res) => res.json({ id: req.user.id }));
  return app;
}

test("sign/verify roundtrip; old kid still verifies; expired fails", () => {
  const t0 = new Date("2026-07-04T00:00:00Z");
  const tok = signSession("u1", { secrets: SECRETS, now: () => t0 });
  assert.strictEqual(
    verifySession(tok, { secrets: SECRETS, now: () => t0 }).sub,
    "u1",
  );

  const oldTok = signSession("u1", {
    secrets: { v1: "old-secret" },
    now: () => t0,
  });
  assert.strictEqual(
    verifySession(oldTok, { secrets: SECRETS, now: () => t0 }).sub,
    "u1",
    "rotation: retired kid still verifies while listed",
  );

  const later = new Date(t0.getTime() + 91 * DAY);
  assert.throws(
    () => verifySession(tok, { secrets: SECRETS, now: () => later }),
    /expired/,
  );
});

test("requireAuth: valid -> row loaded; >30d old -> X-Refreshed-Token; deleted user -> 401", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','sub1','a@b.c')`,
  );
  const t0 = new Date("2026-07-04T00:00:00Z");
  const tok = signSession("u1", { secrets: SECRETS, now: () => t0 });

  const fresh = await request(appWith(() => t0))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(fresh.status, 200);
  assert.strictEqual(fresh.headers["x-refreshed-token"], undefined);

  const t35 = new Date(t0.getTime() + 35 * DAY);
  const stale = await request(appWith(() => t35))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(stale.status, 200);
  assert.ok(stale.headers["x-refreshed-token"], "sliding renewal header");
  const renewed = verifySession(stale.headers["x-refreshed-token"], {
    secrets: SECRETS,
    now: () => t35,
  });
  assert.strictEqual(renewed.sub, "u1");

  await pool.query(`DELETE FROM users WHERE id='u1'`);
  const gone = await request(appWith(() => t35))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(gone.status, 401, "missing users row = revocation");

  const t95 = new Date(t0.getTime() + 95 * DAY);
  const expired = await request(appWith(() => t95))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(expired.status, 401);
  assert.strictEqual(expired.body.error, "session_expired");
});
