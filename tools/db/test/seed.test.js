import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import pg from "pg";

const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
before(() => client.connect());
after(() => client.end());

test("61 specialities seeded: 30 DNB + 31 DrNB", async () => {
  const r = await client.query(
    `SELECT exam_type, count(*)::int AS n FROM specialities
     GROUP BY exam_type ORDER BY exam_type`,
  );
  assert.deepEqual(r.rows, [
    { exam_type: "DNB", n: 30 },
    { exam_type: "DrNB", n: 31 },
  ]);
});

test("every id is a 26-char Crockford base32 ULID and slugs are unique", async () => {
  const r = await client.query(`SELECT id, slug FROM specialities`);
  const ulid = /^[0-9A-HJKMNP-TV-Z]{26}$/;
  for (const row of r.rows) {
    assert.match(row.id, ulid, `bad ULID: ${row.id}`);
  }
  const slugs = r.rows.map((x) => x.slug);
  assert.equal(new Set(slugs).size, 61);
});

test("Anaesthesiology anchor ULID is fixed (beta content anchor)", async () => {
  const r = await client.query(
    `SELECT name, exam_type, slug, sort_order FROM specialities
     WHERE id = '01JZSP3C00DNB0000000000001'`,
  );
  assert.equal(r.rows.length, 1);
  assert.deepEqual(r.rows[0], {
    name: "Anaesthesiology",
    exam_type: "DNB",
    slug: "anaesthesiology",
    sort_order: 1,
  });
});

test("sort_order is global 1..61 with no gaps", async () => {
  const r = await client.query(
    `SELECT sort_order FROM specialities ORDER BY sort_order`,
  );
  assert.deepEqual(
    r.rows.map((x) => x.sort_order),
    Array.from({ length: 61 }, (_, i) => i + 1),
  );
});
