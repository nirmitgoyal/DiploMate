import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
before(() => client.connect());
after(() => client.end());

async function columns(table) {
  const r = await client.query(
    `SELECT column_name FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1
     ORDER BY column_name`,
    [table],
  );
  return r.rows.map((x) => x.column_name);
}

// Exact column sets: deepEqual pins presence AND absence in one assertion.
// chapters must NOT have bundle_version/bundle_sha256/download_bytes;
// qnas must NOT have row_hash (NO OFFLINE DOWNLOADS revision, 2026-07-04).

test("app_config columns exact", async () => {
  assert.deepEqual(await columns("app_config"), ["key", "value"]);
});

test("specialities columns exact", async () => {
  assert.deepEqual(await columns("specialities"), [
    "exam_type",
    "id",
    "name",
    "slug",
    "sort_order",
  ]);
});

test("chapters columns exact (content_version in, bundle columns out)", async () => {
  assert.deepEqual(await columns("chapters"), [
    "content_version",
    "exam_weight",
    "id",
    "slug",
    "sort_order",
    "speciality_id",
    "title",
  ]);
});

test("qnas columns exact (no row_hash)", async () => {
  assert.deepEqual(await columns("qnas"), [
    "chapter_id",
    "earns_marks",
    "id",
    "marks",
    "question",
    "sections",
    "sort_order",
    "years",
  ]);
});

test("images columns exact", async () => {
  assert.deepEqual(await columns("images"), [
    "byte_size",
    "caption",
    "content_description",
    "id",
    "qna_id",
    "sha256",
    "sort_order",
    "webp",
  ]);
});

test("beta_active row is true", async () => {
  const r = await client.query(
    `SELECT value FROM app_config WHERE key = 'beta_active'`,
  );
  assert.equal(r.rows.length, 1);
  assert.equal(r.rows[0].value, "true");
});

test("invalid exam_type is rejected by specialities_exam_type_check", async () => {
  await client.query("BEGIN");
  const err = await client
    .query(
      `INSERT INTO specialities (id, name, exam_type, slug)
       VALUES ('0000000000000000000000TEST', 'Test', 'MD', 'test-exam-type')`,
    )
    .then(
      () => null,
      (e) => e,
    );
  await client.query("ROLLBACK");
  assert.ok(err, "insert with exam_type MD must fail");
  assert.equal(err.constraint, "specialities_exam_type_check");
});

test("images byte_size over 204800 is rejected by images_byte_size_check", async () => {
  await client.query("BEGIN");
  await client.query(
    `INSERT INTO specialities (id, name, exam_type, slug)
     VALUES ('0000000000000000000000TSPC', 'Tmp', 'DNB', 'tmp-spec')`,
  );
  await client.query(
    `INSERT INTO chapters (id, speciality_id, title, slug)
     VALUES ('0000000000000000000000TCHP', '0000000000000000000000TSPC', 'Tmp', 'tmp-ch')`,
  );
  await client.query(
    `INSERT INTO qnas (id, chapter_id, question, sections)
     VALUES ('0000000000000000000000TQNA', '0000000000000000000000TCHP', 'Q?', '[]')`,
  );
  const err = await client
    .query(
      `INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256)
       VALUES ('0000000000000000000000TIMG', '0000000000000000000000TQNA', 'c', 'd', '\\x00', 204801, 'deadbeef')`,
    )
    .then(
      () => null,
      (e) => e,
    );
  await client.query("ROLLBACK");
  assert.ok(err, "insert with byte_size 204801 must fail");
  assert.equal(err.constraint, "images_byte_size_check");
});

test("0004 indexes exist", async () => {
  const idx = (
    await client.query(
      `SELECT indexname FROM pg_indexes WHERE schemaname = 'public'`,
    )
  ).rows.map((r) => r.indexname);
  assert.ok(idx.includes("qnas_chapter_id_idx"));
  assert.ok(idx.includes("images_qna_id_idx"));
});
