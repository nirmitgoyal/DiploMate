const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

test("authed report persists a row keyed to user + QnA; unauth 401 (TD1)", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','u1','x@y.z')`,
  );
  const app = createApp({ pool, secrets: SECRETS });
  const tok = signSession("u1", { secrets: SECRETS });

  const res = await request(app)
    .post("/qna/QN1/report")
    .set("Authorization", `Bearer ${tok}`)
    .send({ message: "Dose figure looks wrong" });
  assert.strictEqual(res.status, 201);
  const { rows } = await pool.query(
    `SELECT user_id, qna_id, message FROM reports`,
  );
  assert.deepStrictEqual(rows[0], {
    user_id: "u1",
    qna_id: "QN1",
    message: "Dose figure looks wrong",
  });

  assert.strictEqual(
    (await request(app).post("/qna/QN1/report").send({})).status,
    401,
  );
});
