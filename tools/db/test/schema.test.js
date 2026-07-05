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

test("topics columns exact", async () => {
  assert.deepEqual(await columns("topics"), [
    "chapter_id",
    "exam_theme",
    "id",
    "slug",
    "sort_order",
    "title",
  ]);
});

test("qnas columns exact (no row_hash)", async () => {
  assert.deepEqual(await columns("qnas"), [
    "earns_marks",
    "id",
    "marks",
    "question",
    "sections",
    "sort_order",
    "topic_id",
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
