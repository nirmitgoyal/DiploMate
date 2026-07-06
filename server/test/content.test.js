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
    `INSERT INTO users (id, google_sub, email) VALUES ($1,$1,'x@y.z')
                    ON CONFLICT (google_sub) DO NOTHING`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

test("chapter qnas are paginated JSON with image metadata, no bytes", async () => {
  await resetUserData();
  await seedContent(pool);
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");

  const res = await request(app)
    .get("/chapters/CH1/qnas?page=1")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.chapter_id, "CH1");
  assert.strictEqual(res.body.content_version, 1);
  assert.strictEqual(res.body.page, 1);
  assert.strictEqual(res.body.pages, 1);
  assert.strictEqual(res.body.items.length, 2);
  const q1 = res.body.items.find((q) => q.id === "QN1");
  assert.strictEqual(q1.topic_id, "TP1");
  assert.strictEqual(q1.images[0].sha256, "abc123");
  assert.strictEqual(
    q1.images[0].webp,
    undefined,
    "no bytes in JSON (no base64 tax)",
  );

  assert.strictEqual(res.body.topics.length, 1);
  const t1 = res.body.topics[0];
  assert.strictEqual(t1.id, "TP1");
  assert.strictEqual(t1.title, "Difficult airway");
  assert.strictEqual(t1.slug, "difficult-airway");
  assert.strictEqual(t1.sort_order, 1);
  // exam_theme is nullable in the schema; this fixture happens to set it.
  assert.strictEqual(t1.exam_theme, "Emergencies");
});

test("images stream binary webp with ETag; If-None-Match -> 304", async () => {
  await resetUserData();
  await seedContent(pool);
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");

  const res = await request(app)
    .get("/images/IM1")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.headers["content-type"], "image/webp");
  assert.strictEqual(res.headers.etag, '"abc123"');
  assert.strictEqual(res.body.length, 4);

  const cached = await request(app)
    .get("/images/IM1")
    .set("Authorization", `Bearer ${tok}`)
    .set("If-None-Match", '"abc123"');
  assert.strictEqual(cached.status, 304);
});

test("unknown chapter/image -> 404; no auth -> 401", async () => {
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  assert.strictEqual(
    (
      await request(app)
        .get("/chapters/NOPE/qnas")
        .set("Authorization", `Bearer ${tok}`)
    ).status,
    404,
  );
  assert.strictEqual(
    (
      await request(app)
        .get("/images/NOPE")
        .set("Authorization", `Bearer ${tok}`)
    ).status,
    404,
  );
  assert.strictEqual(
    (await request(app).get("/chapters/CH1/qnas")).status,
    401,
  );
});
