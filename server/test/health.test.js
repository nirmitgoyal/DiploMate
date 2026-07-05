const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { testPool } = require("./helpers/setup");

test("GET /health returns 200 {ok:true}", async () => {
  const app = createApp({ pool: testPool() });
  const res = await request(app).get("/health");
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(res.body, { ok: true });
});
