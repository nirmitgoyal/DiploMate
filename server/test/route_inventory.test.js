const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { testPool } = require("./helpers/setup");

const pool = testPool();

// D3 addendum B (amended by the NO OFFLINE DOWNLOADS revision) - the EXACT
// public surface. A route in code but not here (or vice versa) is a bug.
const INVENTORY = [
  ["POST", "/auth/google"],
  ["GET", "/health"],
  ["GET", "/manifest"],
  ["GET", "/chapters/:chapterId/qnas"],
  ["GET", "/images/:id"],
  ["POST", "/sync/review-events"],
  ["POST", "/sync/app-events"],
  ["PUT", "/me/bookmarks"],
  ["POST", "/me/speciality"],
  ["DELETE", "/me"],
  ["POST", "/qna/:id/report"],
  ["GET", "/legal/privacy"],
  ["GET", "/legal/terms"],
  ["GET", "/account/delete"],
];

function implementedRoutes(app) {
  const out = [];
  for (const layer of app._router.stack) {
    if (layer.route) {
      for (const m of Object.keys(layer.route.methods)) {
        out.push([m.toUpperCase(), layer.route.path]);
      }
    } else if (layer.name === "router" && layer.handle.stack) {
      for (const sub of layer.handle.stack) {
        if (sub.route) {
          for (const m of Object.keys(sub.route.methods)) {
            out.push([m.toUpperCase(), sub.route.path]);
          }
        }
      }
    }
  }
  return out.sort((a, b) => (a[0] + a[1]).localeCompare(b[0] + b[1]));
}

test("implemented route set exactly matches the D3 inventory (4A)", () => {
  const app = createApp({ pool });
  const got = implementedRoutes(app);
  const want = [...INVENTORY].sort((a, b) =>
    (a[0] + a[1]).localeCompare(b[0] + b[1]),
  );
  assert.deepStrictEqual(got, want);
});

test("/auth/google is the sole auth route (D5)", () => {
  const authRoutes = INVENTORY.filter(([, p]) => p.startsWith("/auth"));
  assert.deepStrictEqual(authRoutes, [["POST", "/auth/google"]]);
});

test("non-inventory paths 404", async () => {
  const app = createApp({ pool });
  for (const path of ["/bundles/CH1", "/users", "/auth/password", "/admin"]) {
    const res = await request(app).get(path);
    assert.strictEqual(res.status, 404, path);
  }
});

test("legal pages are public HTML", async () => {
  const app = createApp({ pool });
  for (const path of ["/legal/privacy", "/legal/terms", "/account/delete"]) {
    const res = await request(app).get(path);
    assert.strictEqual(res.status, 200, path);
    assert.match(res.headers["content-type"], /text\/html/);
    assert.ok(res.text.length > 500, `${path} carries real copy, not lorem`);
  }
});
