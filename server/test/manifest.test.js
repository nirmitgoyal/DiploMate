const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

const SECRETS = { v1: "s1" };
const pool = testPool();

async function tokenFor(id) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1, $1, 'x@y.z')
     ON CONFLICT (google_sub) DO NOTHING`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

test("manifest lists 61 specialities with has_content; chapters only with ?speciality", async () => {
  await resetUserData();
  const { spec } = await seedContent(pool);
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");

  const res = await request(app)
    .get("/manifest")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.schema_version, 1);
  assert.strictEqual(res.body.min_app_version, 1);
  assert.strictEqual(res.body.specialities.length, 61);
  const anaes = res.body.specialities.find((s) => s.has_content);
  assert.strictEqual(anaes.id, spec);
  assert.strictEqual(typeof anaes.slug, "string");
  assert.strictEqual(typeof anaes.sort_order, "number");
  assert.strictEqual(
    res.body.chapters,
    undefined,
    "lazy: no chapters without param",
  );

  const withSpec = await request(app)
    .get(`/manifest?speciality=${spec}`)
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(withSpec.status, 200);
  const ch = withSpec.body.chapters.find((c) => c.id === "CH1");
  assert.strictEqual(ch.topic_count, 1);
  assert.strictEqual(ch.qna_count, 2);
  assert.strictEqual(ch.content_version, 1);
});

test("manifest requires auth", async () => {
  const app = createApp({ pool, secrets: SECRETS });
  const res = await request(app).get("/manifest");
  assert.strictEqual(res.status, 401);
});
