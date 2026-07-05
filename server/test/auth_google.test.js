const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { verifySession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

const goodVerifier = async (idToken) => {
  if (idToken !== "good-token") {
    const e = new Error("bad aud/expired");
    throw e;
  }
  return {
    sub: "gsub-1",
    email: "ananya@example.com",
    name: "Ananya Sharma",
    picture: "https://p/x.jpg",
  };
};

function app() {
  return createApp({ pool, verifyGoogleToken: goodVerifier, secrets: SECRETS });
}

test("valid Google ID token -> user upserted + session JWT", async () => {
  await resetUserData();
  const res = await request(app())
    .post("/auth/google")
    .send({ id_token: "good-token" });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.user.email, "ananya@example.com");
  assert.strictEqual(res.body.user.speciality_id, null);
  assert.strictEqual(res.body.user.speciality_change_count, 0);
  const claims = verifySession(res.body.session_jwt, { secrets: SECRETS });
  assert.strictEqual(claims.sub, res.body.user.id);

  // second sign-in: same user row (upsert by google_sub), same id
  const again = await request(app())
    .post("/auth/google")
    .send({ id_token: "good-token" });
  assert.strictEqual(again.body.user.id, res.body.user.id);
  const { rows } = await pool.query(`SELECT count(*)::int AS n FROM users`);
  assert.strictEqual(rows[0].n, 1);
});

test("wrong-aud / expired Google token -> 401 invalid_google_token", async () => {
  const res = await request(app())
    .post("/auth/google")
    .send({ id_token: "evil" });
  assert.strictEqual(res.status, 401);
  assert.strictEqual(res.body.error, "invalid_google_token");
});

test("missing body -> 400", async () => {
  const res = await request(app()).post("/auth/google").send({});
  assert.strictEqual(res.status, 400);
});
