const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const express = require("express");
const { requireAuth } = require("../src/middleware/auth");
const { requireEntitlement } = require("../src/middleware/entitlement");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

function app() {
  const a = express();
  a.locals = { pool, secrets: SECRETS, now: () => new Date() };
  a.get(
    "/probe/:spec",
    requireAuth,
    requireEntitlement((req) => req.params.spec),
    (req, res) => res.json({ ok: true }),
  );
  return a;
}

async function makeUser(id) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1, $1, 'x@y.z')`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

const SPEC = "ANY-SPEC-ID"; // entitlement check does not FK-validate the id

test("beta_active=true: any signed-in user passes (E1 - no seeding race)", async () => {
  await resetUserData();
  const tok = await makeUser("u1");
  const res = await request(app())
    .get(`/probe/${SPEC}`)
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
});

test("beta_active=false: non-entitled canary gets 403; entitled passes (final shape)", async () => {
  await resetUserData();
  await pool.query(
    `UPDATE app_config SET value='false' WHERE key='beta_active'`,
  );
  const canary = await makeUser("canary");
  const denied = await request(app())
    .get(`/probe/${SPEC}`)
    .set("Authorization", `Bearer ${canary}`);
  assert.strictEqual(denied.status, 403);
  assert.strictEqual(denied.body.error, "not_entitled");

  const buyer = await makeUser("buyer");
  const { rows } = await pool.query(`SELECT id FROM specialities LIMIT 1`);
  const realSpec = rows[0].id;
  await pool.query(
    `INSERT INTO entitlements (user_id, speciality_id) VALUES ('buyer', $1)`,
    [realSpec],
  );
  const ok = await request(app())
    .get(`/probe/${realSpec}`)
    .set("Authorization", `Bearer ${buyer}`);
  assert.strictEqual(ok.status, 200);
});

test("no JWT fails closed - never unfiltered rows (H2)", async () => {
  const res = await request(app()).get(`/probe/${SPEC}`);
  assert.strictEqual(res.status, 401);
});
