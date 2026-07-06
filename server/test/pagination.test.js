const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

const SECRETS = { v1: "s1" };
const pool = testPool();

test("page 2 of a 60-qna chapter has no repeats and no skips (sort_order + id tiebreak)", async () => {
  await resetUserData();
  const { spec } = await seedContent(pool);
  await pool.query(
    `INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
     VALUES ('CHBIG', $1, 'Big', 'big', 50, 1, 1) ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  // Deliberately IDENTICAL sort_order on every row: the id tiebreak alone
  // must keep pages disjoint and exhaustive (the C1 failure mode).
  for (let i = 0; i < 60; i++) {
    await pool.query(
      `INSERT INTO qnas (id, chapter_id, question, sections, sort_order)
       VALUES ($1, 'CHBIG', $2, '[]', 1) ON CONFLICT (id) DO NOTHING`,
      [`BIGQ${String(i).padStart(2, "0")}`, `q${i}`],
    );
  }
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','u1','x@y.z')
     ON CONFLICT (google_sub) DO NOTHING`,
  );
  const tok = signSession("u1", { secrets: SECRETS });
  const app = createApp({ pool, secrets: SECRETS });

  const p1 = await request(app)
    .get("/chapters/CHBIG/qnas?page=1")
    .set("Authorization", `Bearer ${tok}`);
  const p2 = await request(app)
    .get("/chapters/CHBIG/qnas?page=2")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(p1.status, 200);
  assert.strictEqual(p2.status, 200);
  assert.strictEqual(p1.body.pages, 2);
  const ids = [...p1.body.items, ...p2.body.items].map((q) => q.id);
  assert.strictEqual(ids.length, 60, "no skips");
  assert.strictEqual(new Set(ids).size, 60, "no repeats across pages");

  await pool.query(`DELETE FROM qnas WHERE chapter_id = 'CHBIG'`);
  await pool.query(`DELETE FROM chapters WHERE id = 'CHBIG'`);
});
