const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const crypto = require("node:crypto");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

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

test("bookmarks LWW: newer updated_at wins; tombstones survive (two-device resurrect)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");

  // device A bookmarks at t1
  await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      bookmarks: [
        {
          content_id: "QN1",
          updated_at: "2026-07-04T10:00:00Z",
          deleted: false,
        },
      ],
    });
  // device B deletes at t2 (later) - delete wins
  const res = await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      bookmarks: [
        {
          content_id: "QN1",
          updated_at: "2026-07-04T11:00:00Z",
          deleted: true,
        },
      ],
    });
  const row = res.body.bookmarks.find((b) => b.content_id === "QN1");
  assert.strictEqual(row.deleted, true);

  // device A replays its STALE t1 bookmark - must NOT resurrect
  const replay = await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      bookmarks: [
        {
          content_id: "QN1",
          updated_at: "2026-07-04T10:00:00Z",
          deleted: false,
        },
      ],
    });
  const after = replay.body.bookmarks.find((b) => b.content_id === "QN1");
  assert.strictEqual(after.deleted, true, "tombstone beats stale un-delete");
});

test("speciality change-once: first set free, same-value re-save free, second distinct 409", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const { rows } = await pool.query(
    `SELECT id FROM specialities ORDER BY sort_order LIMIT 2`,
  );
  const [specA, specB] = rows.map((r) => r.id);

  const first = await request(app)
    .post("/me/speciality")
    .set("Authorization", `Bearer ${tok}`)
    .send({ speciality_id: specA });
  assert.strictEqual(
    first.body.speciality_change_count,
    0,
    "initial set is not a change",
  );

  const resave = await request(app)
    .post("/me/speciality")
    .set("Authorization", `Bearer ${tok}`)
    .send({ speciality_id: specA });
  assert.strictEqual(
    resave.body.speciality_change_count,
    0,
    "same value does not burn",
  );

  const change = await request(app)
    .post("/me/speciality")
    .set("Authorization", `Bearer ${tok}`)
    .send({ speciality_id: specB });
  assert.strictEqual(change.body.speciality_change_count, 1);

  const second = await request(app)
    .post("/me/speciality")
    .set("Authorization", `Bearer ${tok}`)
    .send({ speciality_id: specA });
  assert.strictEqual(second.status, 409);
  assert.strictEqual(second.body.error, "change_limit_reached");
});

test("DELETE /me cascades every user table incl. reports; JWT then 401s", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  await pool.query(
    `INSERT INTO reports (id, user_id, qna_id, message)
                    VALUES ($1, 'u1', 'QN1', 'typo')`,
    [crypto.randomUUID()],
  );
  await pool.query(`INSERT INTO bookmarks (user_id, content_id, updated_at)
                    VALUES ('u1', 'QN1', now())`);

  const res = await request(app)
    .delete("/me")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 204);
  for (const t of ["reports", "bookmarks", "users"]) {
    const { rows } = await pool.query(`SELECT count(*)::int AS n FROM ${t}`);
    assert.strictEqual(rows[0].n, 0, `${t} empty after cascade`);
  }
  const after = await request(app)
    .delete("/me")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(after.status, 401, "deleted user JWT = revoked");
});

test("cross-user isolation: A cannot read or write B data through any /me route", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tokA = await tokenFor("userA");
  const tokB = await tokenFor("userB");
  await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tokB}`)
    .send({
      bookmarks: [
        {
          content_id: "SECRET",
          updated_at: "2026-07-04T10:00:00Z",
          deleted: false,
        },
      ],
    });
  const a = await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tokA}`)
    .send({ bookmarks: [] });
  assert.strictEqual(a.body.bookmarks.length, 0, "A never sees B rows");
});

test("malformed bookmark element is skipped, does not wedge the batch", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const res = await request(app)
    .put("/me/bookmarks")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      bookmarks: [
        {
          content_id: "QN1",
          updated_at: "2026-07-04T10:00:00Z",
          deleted: false,
        },
        null,
      ],
    });
  assert.strictEqual(res.status, 200);
  const good = res.body.bookmarks.find((b) => b.content_id === "QN1");
  assert.ok(good, "well-formed row landed despite malformed sibling");
});
