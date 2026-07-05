const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");
const { _resetQuota } = require("../src/middleware/quota");

const SECRETS = { v1: "s1" };
const pool = testPool();

test("past N/day -> 429 + Retry-After; under quota a heavy day passes (3A, #9)", async () => {
  await resetUserData();
  await seedContent(pool);
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','u1','x@y.z')`,
  );
  _resetQuota({ limit: 3 }); // shrink N for the test; prod default 2000
  const app = createApp({ pool, secrets: SECRETS });
  const tok = signSession("u1", { secrets: SECRETS });

  for (let i = 0; i < 3; i++) {
    const ok = await request(app)
      .get("/chapters/CH1/qnas")
      .set("Authorization", `Bearer ${tok}`);
    assert.strictEqual(ok.status, 200, `request ${i + 1} under quota`);
  }
  const blocked = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(blocked.status, 429);
  assert.ok(
    Number(blocked.headers["retry-after"]) > 0,
    "Retry-After seconds present",
  );
  _resetQuota({ limit: 2000 });
});

test("quota keys on user, not IP (CGNAT-safe): second user unaffected", async () => {
  await resetUserData();
  await seedContent(pool);
  await pool.query(`INSERT INTO users (id, google_sub, email) VALUES
                    ('u1','u1','x@y.z'), ('u2','u2','q@y.z')`);
  _resetQuota({ limit: 1 });
  const app = createApp({ pool, secrets: SECRETS });
  const tok1 = signSession("u1", { secrets: SECRETS });
  const tok2 = signSession("u2", { secrets: SECRETS });

  await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok1}`);
  const blocked = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok1}`);
  assert.strictEqual(blocked.status, 429);
  const other = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok2}`);
  assert.strictEqual(other.status, 200, "same IP, different user: passes");
  _resetQuota({ limit: 2000 });
});
