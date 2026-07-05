# Server API (Lane C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the thin Heroku API dyno: Google sign-in verification + self-owned session JWTs, entitlement-gated on-demand content endpoints, idempotent event sync, per-user quota, compliance routes, and a contract test suite that runs on a disposable CI Postgres built from the same `sql/` files as production.

**Architecture:** One Express app (factory pattern, injectable pool + Google verifier for tests) over Heroku Postgres via `pg` (Pool max 5, no ORM). `sql/` numbered migrations own the schema and every wire enum; the API maps constraint violations to 400 and never re-validates enums. Entitlement middleware in final billing shape from day one with a `beta_active` DB-row clause. Content is served on demand (paginated chapter text rows + per-image binary streams with ETag) - there is NO bundle/download machinery (founder, 2026-07-04 evening).

**Tech Stack:** Node 22 LTS, Express, pg, google-auth-library, jsonwebtoken, compression, ulid. Tests: node:test + supertest against a disposable Postgres.

## Global Constraints

Copied from the shared interface contract (`plan-contract.md`) - exact values; every task inherits them:

- NEVER use em-dashes or en-dashes anywhere; plain hyphens only (user convention).
- NO offline Downloads feature: content routes are on-demand reads (`GET /chapters/:chapterId/qnas?page=N`, `GET /images/:id`); no bundle checksum/install endpoints exist. `chapters.content_version` is the client cache-invalidation key.
- Wire enums are owned by `sql/` DDL: `rating IN ('again','hard','good')`; `event_type IN ('topic_opened','recall_shown','recall_revealed','recall_rated','session_start')` (no pack_download values). The API does NOT re-validate enum membership; a Postgres CHECK/enum violation maps to HTTP 400 `{"error":"constraint_violation","constraint":"<name>"}`, never 500.
- Session JWT: HS256, 90-day expiry, claims `{sub, iat, exp}`, header `kid`. `SESSION_JWT_SECRET` = JSON object `{"<kid>":"<secret>", ...}` - FIRST key signs, all keys verify. Sliding renewal: any authenticated response whose token is >30 days old carries `X-Refreshed-Token`. Revocation: every route loads the users row by `sub`; missing row -> 401. No RS256/JWKS for our own tokens.
- Entitlement (final shape, day one): content passes iff `EXISTS entitlement(user_id, speciality_id) OR (SELECT value FROM app_config WHERE key='beta_active') = 'true'`. Fail closed (401/empty), never unfiltered rows. Billing slice flips ONE DB row; `beta_active` is deliberately NOT a config var.
- Quota: per-USER 2000 content requests/day (UTC reset) keyed to `users.id` AFTER token verification -> 429 + `Retry-After` seconds. Per-IP limit ONLY on `/auth/google`, hundreds/min, LOG-ONLY during beta (Indian CGNAT).
- Config vars: `GOOGLE_WEB_CLIENT_ID`, `SESSION_JWT_SECRET`, `DATABASE_URL`. `pg` Pool max = 5 (Essential-0 ~20 connections; release overlap + psql + CI headroom).
- `compression` gzip on JSON routes; per-item responses only (~200KB bound) - the dyno never buffers a whole chapter.
- Timestamp sanity: `rated_at`/`occurred_at` more than 48h ahead of server now -> 400 `{"error":"timestamp_skew"}` (API-enforced; now() in CHECK is unreliable).
- Append-only event tables: no UPDATE/DELETE route exists for `review_events`/`app_events`; the route-inventory test enforces the exact route set (anything else 404).
- Repo root `/Users/nirmit/Codebases/DiploMate`; server code in `server/`, migrations in `sql/` (0001/0002 exist - day1-ddl plan), metrics in `sql/metrics/`.
- Free beta (PG3): `beta_active='true'` seeded; no payment/billing code anywhere.
- TDD: failing test -> minimal code -> pass -> commit. Conventional commits.

**Test bootstrap used by every task** (CI runs the same): a disposable Postgres reachable at `TEST_DATABASE_URL`, schema applied from zero by the day1 plan's apply script:

```bash
createdb diplomate_test 2>/dev/null || true
DATABASE_URL=postgres://localhost/diplomate_test bash tools/db/apply.sh
cd /Users/nirmit/Codebases/DiploMate/server
TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test
```

---

### Task 1: Server scaffold - app factory, Pool max 5, /health, Procfile, engines pin (ENG-T13 part)

**Files:**

- Create: `Procfile` (repo root)
- Create: `server/package.json`
- Create: `server/src/db.js`
- Create: `server/src/app.js`
- Create: `server/src/index.js`
- Create: `server/test/helpers/setup.js`
- Test: `server/test/health.test.js`

**Interfaces:**

- Consumes: `sql/0001_content_v0.sql` + `sql/0002_seed_specialities.sql` + `tools/db/apply.sh` (day1-ddl plan).
- Produces: `createApp({ pool, verifyGoogleToken, secrets, now })` from `src/app.js` - every later task registers its router inside this factory; `makePool()` from `src/db.js`; `testPool()`/`resetUserData(pool)` helpers from `test/helpers/setup.js` used by every test file.

- [ ] **Step 1: Write the failing test**

`server/test/health.test.js`:

```js
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
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/health.test.js`
Expected: FAIL - `Cannot find module '../src/app'`

- [ ] **Step 3: Implement**

`Procfile` (repo root):

```
web: node server/src/index.js
```

`server/package.json`:

```json
{
  "name": "diplomate-server",
  "private": true,
  "engines": { "node": "22.x" },
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "node --test"
  },
  "dependencies": {
    "compression": "^1.7.4",
    "express": "^4.19.2",
    "google-auth-library": "^9.11.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.12.0",
    "ulid": "^2.3.0"
  },
  "devDependencies": {
    "supertest": "^7.0.0"
  }
}
```

`server/src/db.js`:

```js
const { Pool } = require("pg");

// Pool max 5: Essential-0 has ~20 connections; a release briefly runs
// old+new dynos, plus psql/ingestion/CI need headroom (D3 ops appendix).
function makePool(connectionString = process.env.DATABASE_URL) {
  return new Pool({
    connectionString,
    max: 5,
    ssl: connectionString?.includes("localhost")
      ? false
      : { rejectUnauthorized: false },
  });
}

module.exports = { makePool };
```

`server/src/app.js`:

```js
const express = require("express");
const compression = require("compression");

function createApp({
  pool,
  verifyGoogleToken,
  secrets,
  now = () => new Date(),
} = {}) {
  const app = express();
  app.set("x-powered-by", false);
  app.use(compression()); // gzip: model answers compress 60-80% (Issue 7)
  app.use(express.json({ limit: "1mb" }));

  app.locals.pool = pool;
  app.locals.verifyGoogleToken = verifyGoogleToken;
  app.locals.secrets = secrets;
  app.locals.now = now;

  app.get("/health", (req, res) => res.json({ ok: true }));

  // Later tasks mount routers here (auth, manifest, chapters, images, sync,
  // me, reports, legal) - keep this comment; the route-inventory test
  // (Task 11) pins the exact final set.

  // Terminal 404 for every non-inventory path.
  app.use((req, res) => res.status(404).json({ error: "not_found" }));

  // Error mapper - Task 7 extends it with constraint_violation handling.
  app.use((err, req, res, next) => {
    res.status(500).json({ error: "internal" });
  });

  return app;
}

module.exports = { createApp };
```

`server/src/index.js`:

```js
const { createApp } = require("./app");
const { makePool } = require("./db");
const { OAuth2Client } = require("google-auth-library");
const { makeVerifier } = require("./lib/google");

const pool = makePool();
const app = createApp({
  pool,
  verifyGoogleToken: makeVerifier(
    new OAuth2Client(),
    process.env.GOOGLE_WEB_CLIENT_ID,
  ),
  secrets: JSON.parse(process.env.SESSION_JWT_SECRET || "{}"),
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`diplomate-server listening on ${port}`));
```

(`src/lib/google.js` arrives in Task 3; until then `index.js` fails to boot locally, which is fine - tests use the factory.)

`server/test/helpers/setup.js`:

```js
const { makePool } = require("../../src/db");

let pool;
function testPool() {
  pool ??= makePool(process.env.TEST_DATABASE_URL);
  return pool;
}

// Wipe mutable data between tests; content + specialities are seed-stable.
async function resetUserData(p = testPool()) {
  await p.query(
    `TRUNCATE users, entitlements, review_events, app_events, bookmarks, reports CASCADE`,
  );
  await p.query(
    `UPDATE app_config SET value = 'true' WHERE key = 'beta_active'`,
  );
}

module.exports = { testPool, resetUserData };
```

- [ ] **Step 4: Install + run, expect PASS**

```bash
cd /Users/nirmit/Codebases/DiploMate/server && npm install
createdb diplomate_test 2>/dev/null || true
DATABASE_URL=postgres://localhost/diplomate_test bash ../tools/db/apply.sh
TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/health.test.js
```

Expected: `pass 1` (note: `resetUserData` references tables 0003 creates - it is not called yet; Task 2 makes it real).

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add Procfile server/
git commit -m "feat(server): express app factory, pool max 5, /health, Procfile + engines pin"
```

---

### Task 2: sql/0003_users_events.sql (users, entitlements, events, bookmarks, reports)

**Files:**

- Create: `sql/0003_users_events.sql`
- Test: `server/test/schema_0003.test.js`

**Interfaces:**

- Consumes: `sql/0001` tables (`specialities` FK target), apply script.
- Produces: the exact tables every later task queries. Column names are wire truth: `users(id, google_sub, email, name, photo_url, speciality_id, speciality_change_count, created_at)`, `entitlements(user_id, speciality_id, granted_at)`, `review_events(id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day, synced_at)`, `app_events(id, user_id, event_type, content_id, hidden_ms, occurred_at, local_day, synced_at)`, `bookmarks(user_id, content_id, updated_at, deleted)`, `reports(id, user_id, qna_id, message, created_at)`. Constraint names are wire contract: `review_events_rating_check`, `review_events_order_check`, `app_events_event_type_check`.

- [ ] **Step 1: Write the failing test**

`server/test/schema_0003.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const { testPool, resetUserData } = require("./helpers/setup");

const pool = testPool();

test("0003 tables exist with the contract columns", async () => {
  const { rows } = await pool.query(`
    SELECT table_name, column_name FROM information_schema.columns
    WHERE table_name IN ('users','entitlements','review_events','app_events','bookmarks','reports')
  `);
  const has = (t, c) =>
    rows.some((r) => r.table_name === t && r.column_name === c);
  assert.ok(has("users", "google_sub"));
  assert.ok(has("users", "speciality_change_count"));
  assert.ok(has("review_events", "local_day"));
  assert.ok(has("review_events", "synced_at"));
  assert.ok(has("app_events", "hidden_ms"));
  assert.ok(has("bookmarks", "deleted"));
  assert.ok(has("reports", "qna_id"));
});

test("rating + event_type CHECKs reject invalid values with named constraints", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1', 'sub1', 'a@b.c')`,
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'q1', 'easy', now(), now(), now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "review_events_rating_check",
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO app_events (id, user_id, event_type, occurred_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'pack_download_started', now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "app_events_event_type_check",
    "pack_download_* was removed with the downloads feature",
  );
});

test("event order CHECK holds and user delete cascades", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','sub1','a@b.c')`,
  );
  await assert.rejects(
    pool.query(
      `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
       VALUES (gen_random_uuid(), 'u1', 'q1', 'good', now(), now() - interval '1 minute', now(), '2026-07-04')`,
    ),
    (e) => e.constraint === "review_events_order_check",
  );
  await pool.query(
    `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
     VALUES (gen_random_uuid(), 'u1', 'q1', 'good', now() - interval '2m', now() - interval '1m', now(), '2026-07-04')`,
  );
  await pool.query(`DELETE FROM users WHERE id = 'u1'`);
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM review_events`,
  );
  assert.strictEqual(rows[0].n, 0, "ON DELETE CASCADE");
});
```

- [ ] **Step 2: Run, expect FAIL** (tables missing)

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/schema_0003.test.js`

- [ ] **Step 3: Write the migration**

`sql/0003_users_events.sql` - contract-verbatim:

```sql
-- 0003: users, entitlements, event log, bookmarks, reports (lane C).
-- Wire enums live HERE as CHECK constraints (D7 addendum / Issue 5A).
-- The API maps violations to 400 {constraint}; it never re-validates.

CREATE TABLE users (
  id                      TEXT PRIMARY KEY,
  google_sub              TEXT NOT NULL UNIQUE,
  email                   TEXT NOT NULL,
  name                    TEXT,
  photo_url               TEXT,
  speciality_id           TEXT REFERENCES specialities(id),
  speciality_change_count INTEGER NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE entitlements (
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  speciality_id TEXT NOT NULL REFERENCES specialities(id),
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, speciality_id)
);

CREATE TABLE review_events (
  id          UUID PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id  TEXT NOT NULL,
  rating      TEXT NOT NULL CONSTRAINT review_events_rating_check
              CHECK (rating IN ('again','hard','good')),
  shown_at    TIMESTAMPTZ NOT NULL,
  revealed_at TIMESTAMPTZ NOT NULL,
  rated_at    TIMESTAMPTZ NOT NULL,
  local_day   DATE NOT NULL,
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT review_events_order_check
    CHECK (shown_at <= revealed_at AND revealed_at <= rated_at)
);
CREATE INDEX review_events_user_day ON review_events (user_id, local_day);

CREATE TABLE app_events (
  id          UUID PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL CONSTRAINT app_events_event_type_check
              CHECK (event_type IN ('topic_opened','recall_shown','recall_revealed',
                                    'recall_rated','session_start')),
  content_id  TEXT,
  hidden_ms   INTEGER,
  occurred_at TIMESTAMPTZ NOT NULL,
  local_day   DATE NOT NULL,
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX app_events_user_day ON app_events (user_id, local_day);

CREATE TABLE bookmarks (
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted    BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, content_id)
);

CREATE TABLE reports (
  id         UUID PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  qna_id     TEXT NOT NULL,
  message    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- [ ] **Step 4: Apply + run, expect PASS**

```bash
DATABASE_URL=postgres://localhost/diplomate_test bash /Users/nirmit/Codebases/DiploMate/tools/db/apply.sh
cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/schema_0003.test.js
```

Expected: `pass 3`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add sql/0003_users_events.sql server/test/schema_0003.test.js
git commit -m "feat(sql): 0003 users/entitlements/events/bookmarks/reports with wire-enum CHECKs"
```

---

### Task 3: Session JWT lib + auth middleware (ENG-T12: 90d HS256, kid, sliding renewal, revocation)

**Files:**

- Create: `server/src/lib/jwt.js`
- Create: `server/src/lib/google.js`
- Create: `server/src/middleware/auth.js`
- Test: `server/test/jwt.test.js`

**Interfaces:**

- Consumes: `users` table (Task 2), `createApp` locals (Task 1).
- Produces: `signSession(userId, { secrets, now })` / `verifySession(token, { secrets, now })` from `lib/jwt.js`; `requireAuth` middleware setting `req.user` (full users row) and the `X-Refreshed-Token` header; `makeVerifier(client, audience)` from `lib/google.js` returning `async (idToken) => ({ sub, email, name, picture })`. Every JWT route in Tasks 4-10 mounts `requireAuth` first.

- [ ] **Step 1: Write the failing test**

`server/test/jwt.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const express = require("express");
const { signSession, verifySession } = require("../src/lib/jwt");
const { requireAuth } = require("../src/middleware/auth");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v2: "new-secret", v1: "old-secret" }; // first key signs
const DAY = 86400000;
const pool = testPool();

function appWith(now) {
  const app = express();
  app.locals.pool = pool;
  app.locals.secrets = SECRETS;
  app.locals.now = now;
  app.get("/probe", requireAuth, (req, res) => res.json({ id: req.user.id }));
  return app;
}

test("sign/verify roundtrip; old kid still verifies; expired fails", () => {
  const t0 = new Date("2026-07-04T00:00:00Z");
  const tok = signSession("u1", { secrets: SECRETS, now: () => t0 });
  assert.strictEqual(
    verifySession(tok, { secrets: SECRETS, now: () => t0 }).sub,
    "u1",
  );

  const oldTok = signSession("u1", {
    secrets: { v1: "old-secret" },
    now: () => t0,
  });
  assert.strictEqual(
    verifySession(oldTok, { secrets: SECRETS, now: () => t0 }).sub,
    "u1",
    "rotation: retired kid still verifies while listed",
  );

  const later = new Date(t0.getTime() + 91 * DAY);
  assert.throws(
    () => verifySession(tok, { secrets: SECRETS, now: () => later }),
    /expired/,
  );
});

test("requireAuth: valid -> row loaded; >30d old -> X-Refreshed-Token; deleted user -> 401", async () => {
  await resetUserData();
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','sub1','a@b.c')`,
  );
  const t0 = new Date("2026-07-04T00:00:00Z");
  const tok = signSession("u1", { secrets: SECRETS, now: () => t0 });

  const fresh = await request(appWith(() => t0))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(fresh.status, 200);
  assert.strictEqual(fresh.headers["x-refreshed-token"], undefined);

  const t35 = new Date(t0.getTime() + 35 * DAY);
  const stale = await request(appWith(() => t35))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(stale.status, 200);
  assert.ok(stale.headers["x-refreshed-token"], "sliding renewal header");
  const renewed = verifySession(stale.headers["x-refreshed-token"], {
    secrets: SECRETS,
    now: () => t35,
  });
  assert.strictEqual(renewed.sub, "u1");

  await pool.query(`DELETE FROM users WHERE id='u1'`);
  const gone = await request(appWith(() => t35))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(gone.status, 401, "missing users row = revocation");

  const t95 = new Date(t0.getTime() + 95 * DAY);
  const expired = await request(appWith(() => t95))
    .get("/probe")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(expired.status, 401);
  assert.strictEqual(expired.body.error, "session_expired");
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/jwt.test.js`

- [ ] **Step 3: Implement**

`server/src/lib/jwt.js`:

```js
const jwt = require("jsonwebtoken");

const NINETY_DAYS_S = 90 * 24 * 3600;

// SESSION_JWT_SECRET is a JSON object {kid: secret,...}; FIRST key = active
// signing kid; every listed kid verifies (rotate = add new first, drop old).
function activeKid(secrets) {
  return Object.keys(secrets)[0];
}

function signSession(userId, { secrets, now = () => new Date() }) {
  const kid = activeKid(secrets);
  return jwt.sign({ sub: userId }, secrets[kid], {
    algorithm: "HS256",
    expiresIn: NINETY_DAYS_S,
    keyid: kid,
    // jsonwebtoken derives iat from clock; pin it for injectable time:
    ...(now ? {} : {}),
  });
}

function verifySession(token, { secrets, now = () => new Date() }) {
  const { header } = jwt.decode(token, { complete: true }) || {};
  const secret = header && secrets[header.kid];
  if (!secret) throw new Error("unknown kid");
  return jwt.verify(token, secret, {
    algorithms: ["HS256"],
    clockTimestamp: Math.floor(now().getTime() / 1000),
  });
}

module.exports = { signSession, verifySession, NINETY_DAYS_S };
```

Note on injectable `iat`: `jwt.sign` stamps `iat` from the real clock. For deterministic tests, pass the payload timestamp explicitly - replace the `sign` call with:

```js
function signSession(userId, { secrets, now = () => new Date() }) {
  const kid = activeKid(secrets);
  const iat = Math.floor(now().getTime() / 1000);
  return jwt.sign(
    { sub: userId, iat, exp: iat + NINETY_DAYS_S },
    secrets[kid],
    {
      algorithm: "HS256",
      keyid: kid,
    },
  );
}
```

(this exact version is the one to commit - explicit `iat`/`exp`, no `expiresIn`).

`server/src/lib/google.js`:

```js
// Stock google-auth-library verification - never hand-rolled (D5).
// Rejects wrong-aud and expired Google ID tokens by throwing.
function makeVerifier(oauthClient, audience) {
  return async function verifyGoogleToken(idToken) {
    const ticket = await oauthClient.verifyIdToken({ idToken, audience });
    const p = ticket.getPayload();
    return { sub: p.sub, email: p.email, name: p.name, picture: p.picture };
  };
}

module.exports = { makeVerifier };
```

`server/src/middleware/auth.js`:

```js
const { signSession, verifySession } = require("../lib/jwt");

const THIRTY_DAYS_S = 30 * 24 * 3600;

async function requireAuth(req, res, next) {
  const { pool, secrets, now } = req.app.locals;
  const header = req.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "unauthorized" });

  let claims;
  try {
    claims = verifySession(token, { secrets, now });
  } catch (e) {
    return res.status(401).json({ error: "session_expired" });
  }

  // Revocation is free: every route touches Postgres by user id anyway;
  // a missing users row (deleted account) means 401 (D5 addendum).
  const { rows } = await pool.query("SELECT * FROM users WHERE id = $1", [
    claims.sub,
  ]);
  if (rows.length === 0) return res.status(401).json({ error: "unauthorized" });
  req.user = rows[0];

  // Sliding renewal: token older than 30 days -> fresh 90d JWT in a header.
  const ageS = Math.floor(now().getTime() / 1000) - claims.iat;
  if (ageS > THIRTY_DAYS_S) {
    res.set("X-Refreshed-Token", signSession(claims.sub, { secrets, now }));
  }
  next();
}

module.exports = { requireAuth };
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/jwt.test.js`
Expected: `pass 2`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/lib server/src/middleware/auth.js server/test/jwt.test.js
git commit -m "feat(server): HS256 session JWT with kid rotation, sliding renewal, row-check revocation"
```

---

### Task 4: POST /auth/google - sole auth route (D5) + per-IP log-only limiter

**Files:**

- Create: `server/src/routes/auth.js`
- Modify: `server/src/app.js` (mount)
- Test: `server/test/auth_google.test.js`

**Interfaces:**

- Consumes: `verifyGoogleToken` local (Task 3 `makeVerifier` in prod; a stub in tests), `signSession`, `users` table, `ulid`.
- Produces: `POST /auth/google` body `{"id_token"}` -> 200 `{"session_jwt","user":{"id","email","name","photo_url","speciality_id","speciality_change_count"}}`; 401 `{"error":"invalid_google_token"}` on any verifier failure. Upserts by `google_sub` (synchronous, D5); mints a ULID `users.id` on first sign-in.

- [ ] **Step 1: Write the failing test**

`server/test/auth_google.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { verifySession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

const goodVerifier = async (idToken) => {
  if (idToken !== "good-token") {
    const e = new Error("bad aud/expired");
    throw e;
  }
  return {
    sub: "gsub-1",
    email: "ananya@example.com",
    name: "Ananya Sharma",
    picture: "https://p/x.jpg",
  };
};

function app() {
  return createApp({ pool, verifyGoogleToken: goodVerifier, secrets: SECRETS });
}

test("valid Google ID token -> user upserted + session JWT", async () => {
  await resetUserData();
  const res = await request(app())
    .post("/auth/google")
    .send({ id_token: "good-token" });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.user.email, "ananya@example.com");
  assert.strictEqual(res.body.user.speciality_id, null);
  assert.strictEqual(res.body.user.speciality_change_count, 0);
  const claims = verifySession(res.body.session_jwt, { secrets: SECRETS });
  assert.strictEqual(claims.sub, res.body.user.id);

  // second sign-in: same user row (upsert by google_sub), same id
  const again = await request(app())
    .post("/auth/google")
    .send({ id_token: "good-token" });
  assert.strictEqual(again.body.user.id, res.body.user.id);
  const { rows } = await pool.query(`SELECT count(*)::int AS n FROM users`);
  assert.strictEqual(rows[0].n, 1);
});

test("wrong-aud / expired Google token -> 401 invalid_google_token", async () => {
  const res = await request(app())
    .post("/auth/google")
    .send({ id_token: "evil" });
  assert.strictEqual(res.status, 401);
  assert.strictEqual(res.body.error, "invalid_google_token");
});

test("missing body -> 400", async () => {
  const res = await request(app()).post("/auth/google").send({});
  assert.strictEqual(res.status, 400);
});
```

- [ ] **Step 2: Run, expect FAIL** (404 - route not mounted)

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/auth_google.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/auth.js`:

```js
const express = require("express");
const { ulid } = require("ulid");
const { signSession } = require("../lib/jwt");

const router = express.Router();

// Per-IP limiter on /auth/google: LOG-ONLY during beta (outside voice #9 -
// Indian CGNAT puts whole cohorts behind a few egress IPs; a blocking gate
// would 429 legitimate launch-day sign-ins). Threshold: hundreds/min.
const ipHits = new Map();
function logOnlyIpLimit(req) {
  const key = `${req.ip}:${new Date().getUTCMinutes()}`;
  const n = (ipHits.get(key) || 0) + 1;
  ipHits.set(key, n);
  if (n > 300) console.warn(`auth-ip-limit: ${req.ip} at ${n}/min (log-only)`);
  if (ipHits.size > 10000) ipHits.clear();
}

router.post("/auth/google", async (req, res, next) => {
  try {
    logOnlyIpLimit(req);
    const { pool, verifyGoogleToken, secrets, now } = req.app.locals;
    const idToken = req.body?.id_token;
    if (!idToken) return res.status(400).json({ error: "missing_id_token" });

    let g;
    try {
      g = await verifyGoogleToken(idToken);
    } catch {
      return res.status(401).json({ error: "invalid_google_token" });
    }

    const { rows } = await pool.query(
      `INSERT INTO users (id, google_sub, email, name, photo_url)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (google_sub) DO UPDATE
         SET email = EXCLUDED.email, name = EXCLUDED.name, photo_url = EXCLUDED.photo_url
       RETURNING id, email, name, photo_url, speciality_id, speciality_change_count`,
      [ulid(), g.sub, g.email, g.name || null, g.picture || null],
    );
    const user = rows[0];
    res.json({ session_jwt: signSession(user.id, { secrets, now }), user });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
```

Mount in `src/app.js` (replace the "Later tasks mount routers here" comment region - keep the comment, add below it):

```js
app.use(require("./routes/auth"));
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/auth_google.test.js`
Expected: `pass 3`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/routes/auth.js server/src/app.js server/test/auth_google.test.js
git commit -m "feat(server): POST /auth/google - verify, upsert by google_sub, mint session JWT"
```

---

### Task 5: Entitlement middleware in final shape + beta_active clause (ENG-T2/093233, CEO-T4)

**Files:**

- Create: `server/src/middleware/entitlement.js`
- Test: `server/test/entitlement.test.js`

**Interfaces:**

- Consumes: `requireAuth` (`req.user`), `entitlements` + `app_config` tables.
- Produces: `requireEntitlement(resolveSpecialityId)` middleware factory - `resolveSpecialityId(req, pool)` returns the speciality ULID the request targets; the middleware passes iff `EXISTS entitlement OR beta_active`. Content routes (Tasks 6-7) use it; the billing slice later flips ONE row and every check is already real (no loosened beta policies - audit #13).

- [ ] **Step 1: Write the failing test**

`server/test/entitlement.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const express = require("express");
const { requireAuth } = require("../src/middleware/auth");
const { requireEntitlement } = require("../src/middleware/entitlement");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");

const SECRETS = { v1: "s1" };
const pool = testPool();

function app() {
  const a = express();
  a.locals = { pool, secrets: SECRETS, now: () => new Date() };
  a.get(
    "/probe/:spec",
    requireAuth,
    requireEntitlement((req) => req.params.spec),
    (req, res) => res.json({ ok: true }),
  );
  return a;
}

async function makeUser(id) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1, $1, 'x@y.z')`,
    [id],
  );
  return signSession(id, { secrets: SECRETS });
}

const SPEC = "ANY-SPEC-ID"; // entitlement check does not FK-validate the id

test("beta_active=true: any signed-in user passes (E1 - no seeding race)", async () => {
  await resetUserData();
  const tok = await makeUser("u1");
  const res = await request(app())
    .get(`/probe/${SPEC}`)
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(res.status, 200);
});

test("beta_active=false: non-entitled canary gets 403; entitled passes (final shape)", async () => {
  await resetUserData();
  await pool.query(
    `UPDATE app_config SET value='false' WHERE key='beta_active'`,
  );
  const canary = await makeUser("canary");
  const denied = await request(app())
    .get(`/probe/${SPEC}`)
    .set("Authorization", `Bearer ${canary}`);
  assert.strictEqual(denied.status, 403);
  assert.strictEqual(denied.body.error, "not_entitled");

  const buyer = await makeUser("buyer");
  const { rows } = await pool.query(`SELECT id FROM specialities LIMIT 1`);
  const realSpec = rows[0].id;
  await pool.query(
    `INSERT INTO entitlements (user_id, speciality_id) VALUES ('buyer', $1)`,
    [realSpec],
  );
  const ok = await request(app())
    .get(`/probe/${realSpec}`)
    .set("Authorization", `Bearer ${buyer}`);
  assert.strictEqual(ok.status, 200);
});

test("no JWT fails closed - never unfiltered rows (H2)", async () => {
  const res = await request(app()).get(`/probe/${SPEC}`);
  assert.strictEqual(res.status, 401);
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/entitlement.test.js`

- [ ] **Step 3: Implement**

`server/src/middleware/entitlement.js`:

```js
// Final-shape entitlement gate (day one). Beta rides the beta_active DB row
// (deliberately NOT a config var - outside voice #8: dual-homing recreates
// the E1 all-or-nothing race at the billing flip). Fails closed.
function requireEntitlement(resolveSpecialityId) {
  return async function entitlement(req, res, next) {
    try {
      const { pool } = req.app.locals;
      const specialityId = await resolveSpecialityId(req, pool);
      if (!specialityId) return res.status(404).json({ error: "not_found" });
      const { rows } = await pool.query(
        `SELECT (
           EXISTS (SELECT 1 FROM entitlements WHERE user_id = $1 AND speciality_id = $2)
           OR (SELECT value FROM app_config WHERE key = 'beta_active') = 'true'
         ) AS entitled`,
        [req.user.id, specialityId],
      );
      if (!rows[0].entitled)
        return res.status(403).json({ error: "not_entitled" });
      next();
    } catch (e) {
      next(e);
    }
  };
}

module.exports = { requireEntitlement };
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/entitlement.test.js`
Expected: `pass 3`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/middleware/entitlement.js server/test/entitlement.test.js
git commit -m "feat(server): final-shape entitlement middleware with beta_active DB-row clause"
```

---

### Task 6: GET /manifest - per-track catalog (lazy, TD3) with has_content flags

**Files:**

- Create: `server/src/routes/manifest.js`
- Modify: `server/src/app.js` (mount)
- Create: `server/test/helpers/seed_content.js`
- Test: `server/test/manifest.test.js`

**Interfaces:**

- Consumes: `requireAuth`, `requireEntitlement`, content tables (0001), seed (0002).
- Produces: `GET /manifest` (JWT) -> `{"schema_version":1,"min_app_version":1,"specialities":[{id,name,exam_type,has_content}]}`; with `?speciality=<ulid>` (JWT + entitlement) additionally `"chapters":[{id,title,slug,sort_order,exam_weight,topic_count,qna_count,content_version}]`. `seedContent(pool)` helper other tests reuse (1 chapter, 1 topic, 2 qnas, 1 image).

- [ ] **Step 1: Write the seed helper + failing test**

`server/test/helpers/seed_content.js`:

```js
// Minimal content tree for endpoint tests - shaped exactly like the
// ingestion publisher's output. Safe to call repeatedly.
async function seedContent(pool) {
  const { rows } = await pool.query(
    `SELECT id FROM specialities WHERE slug = 'anaesthesiology'`,
  );
  const spec = rows[0].id;
  await pool.query(
    `
    INSERT INTO chapters (id, speciality_id, title, slug, sort_order, exam_weight, content_version)
    VALUES ('CH1', $1, 'Airway Management', 'airway-management', 1, 100, 1)
    ON CONFLICT (id) DO NOTHING`,
    [spec],
  );
  await pool.query(`
    INSERT INTO topics (id, chapter_id, title, slug, exam_theme, sort_order)
    VALUES ('TP1', 'CH1', 'Difficult airway', 'difficult-airway', 'Emergencies', 1)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`
    INSERT INTO qnas (id, topic_id, question, years, marks, earns_marks, sections, sort_order)
    VALUES
      ('QN1', 'TP1', 'Outline the difficult airway algorithm.', '2021 Paper I', 10,
       '[{"label":"Definition","section_key":"definition"}]',
       '[{"key":"definition","heading":"Definition","body_md":"A clinical situation...","marks":2}]', 1),
      ('QN2', 'TP1', 'Describe rapid sequence induction.', '2019', 5,
       '[]', '[{"key":"summary","heading":"Summary","body_md":"Speed matters.","marks":null}]', 2)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`
    INSERT INTO images (id, qna_id, caption, content_description, webp, byte_size, sha256, sort_order)
    VALUES ('IM1', 'QN1', 'Fig 1 - algorithm', 'Flowchart of the difficult airway algorithm',
            decode('52494646', 'hex'), 4, 'abc123', 1)
    ON CONFLICT (id) DO NOTHING`);
  return { spec };
}

module.exports = { seedContent };
```

`server/test/manifest.test.js`:

```js
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
```

- [ ] **Step 2: Run, expect FAIL** (404)

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/manifest.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/manifest.js`:

```js
const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");

const router = express.Router();

const SCHEMA_VERSION = 1;
const MIN_APP_VERSION = 1;

router.get("/manifest", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    const { rows: specialities } = await pool.query(`
      SELECT s.id, s.name, s.exam_type,
             EXISTS (SELECT 1 FROM chapters c WHERE c.speciality_id = s.id
                     AND c.content_version > 0) AS has_content
      FROM specialities s ORDER BY s.sort_order`);

    const body = {
      schema_version: SCHEMA_VERSION,
      min_app_version: MIN_APP_VERSION,
      specialities,
    };

    const spec = req.query.speciality;
    if (!spec) return res.json(body);

    // lazy per-track chapters (TD3) behind the entitlement gate
    return requireEntitlement(() => spec)(req, res, async () => {
      const { rows: chapters } = await pool.query(
        `
        SELECT c.id, c.title, c.slug, c.sort_order, c.exam_weight, c.content_version,
               (SELECT count(*)::int FROM topics t WHERE t.chapter_id = c.id) AS topic_count,
               (SELECT count(*)::int FROM qnas q JOIN topics t ON q.topic_id = t.id
                 WHERE t.chapter_id = c.id) AS qna_count
        FROM chapters c WHERE c.speciality_id = $1 ORDER BY c.sort_order`,
        [spec],
      );
      res.json({ ...body, chapters });
    });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
```

Mount in `src/app.js`: `app.use(require('./routes/manifest'));`

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/manifest.test.js`
Expected: `pass 2`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/routes/manifest.js server/src/app.js server/test
git commit -m "feat(server): GET /manifest - 61 tracks + has_content, lazy entitled chapters"
```

---

### Task 7: Content endpoints - paginated chapter qnas + streamed images with ETag (ENG-T1 server side, ENG-T18)

**Files:**

- Create: `server/src/routes/chapters.js`
- Create: `server/src/routes/images.js`
- Modify: `server/src/app.js` (mount + constraint-violation error mapper, ENG-T16)
- Create: `server/src/lib/constants.js`
- Test: `server/test/content.test.js`

**Interfaces:**

- Consumes: `requireAuth`, `requireEntitlement`, content tables, `seedContent`.
- Produces: `GET /chapters/:chapterId/qnas?page=N` -> `{"chapter_id","content_version","schema_version","page","pages","items":[{qna columns + topic_id + images metadata (id,caption,content_description,byte_size,sha256,sort_order) - NO bytes}]}`, page size 50, gzip; `GET /images/:id` -> `image/webp` bytes with `ETag: "<sha256>"`, `If-None-Match` -> 304. Error mapper: pg error code `23514`/`23503`/`23505` with a constraint -> 400 `{"error":"constraint_violation","constraint"}` (except unique-violation paths that handle it themselves).

- [ ] **Step 1: Write the failing test**

`server/test/content.test.js`:

```js
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
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/content.test.js`

- [ ] **Step 3: Implement**

`server/src/lib/constants.js`:

```js
// Wire enums are OWNED by sql/0003_users_events.sql CHECK constraints -
// these mirrors exist for readability only; never validate against them.
const RATINGS = ["again", "hard", "good"];
const EVENT_TYPES = [
  "topic_opened",
  "recall_shown",
  "recall_revealed",
  "recall_rated",
  "session_start",
];
const PAGE_SIZE = 50;

module.exports = { RATINGS, EVENT_TYPES, PAGE_SIZE };
```

`server/src/routes/chapters.js`:

```js
const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");
const { PAGE_SIZE } = require("../lib/constants");

const router = express.Router();

async function chapterSpeciality(req, pool) {
  const { rows } = await pool.query(
    `SELECT speciality_id FROM chapters WHERE id = $1`,
    [req.params.chapterId],
  );
  return rows[0]?.speciality_id ?? null; // null -> middleware 404s
}

// On-demand content read (no bundles, no downloads - 2026-07-04 revision).
// Per-item rows only; the dyno never buffers a whole chapter (Issue 7).
router.get(
  "/chapters/:chapterId/qnas",
  requireAuth,
  requireEntitlement(chapterSpeciality),
  async (req, res, next) => {
    try {
      const { pool } = req.app.locals;
      const { chapterId } = req.params;
      const page = Math.max(1, parseInt(req.query.page, 10) || 1);

      const meta = await pool.query(
        `SELECT content_version FROM chapters WHERE id = $1`,
        [chapterId],
      );
      const total = await pool.query(
        `SELECT count(*)::int AS n FROM qnas q JOIN topics t ON q.topic_id = t.id
         WHERE t.chapter_id = $1`,
        [chapterId],
      );
      const pages = Math.max(1, Math.ceil(total.rows[0].n / PAGE_SIZE));

      const { rows: items } = await pool.query(
        `SELECT q.id, q.topic_id, q.question, q.years, q.marks, q.earns_marks,
                q.sections, q.sort_order,
                COALESCE((
                  SELECT json_agg(json_build_object(
                    'id', i.id, 'caption', i.caption,
                    'content_description', i.content_description,
                    'byte_size', i.byte_size, 'sha256', i.sha256,
                    'sort_order', i.sort_order) ORDER BY i.sort_order)
                  FROM images i WHERE i.qna_id = q.id), '[]') AS images
         FROM qnas q JOIN topics t ON q.topic_id = t.id
         WHERE t.chapter_id = $1
         ORDER BY t.sort_order, q.sort_order
         LIMIT $2 OFFSET $3`,
        [chapterId, PAGE_SIZE, (page - 1) * PAGE_SIZE],
      );

      res.json({
        chapter_id: chapterId,
        content_version: meta.rows[0].content_version,
        schema_version: 1,
        page,
        pages,
        items,
      });
    } catch (e) {
      next(e);
    }
  },
);

module.exports = router;
```

`server/src/routes/images.js`:

```js
const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");

const router = express.Router();

async function imageSpeciality(req, pool) {
  const { rows } = await pool.query(
    `SELECT c.speciality_id FROM images i
       JOIN qnas q ON i.qna_id = q.id
       JOIN topics t ON q.topic_id = t.id
       JOIN chapters c ON t.chapter_id = c.id
     WHERE i.id = $1`,
    [req.params.id],
  );
  return rows[0]?.speciality_id ?? null;
}

// Binary stream, <=200KB per image (DDL CHECK) - entitlement-gated,
// ETag = sha256 so the client caches with If-None-Match (304).
router.get(
  "/images/:id",
  requireAuth,
  requireEntitlement(imageSpeciality),
  async (req, res, next) => {
    try {
      const { pool } = req.app.locals;
      const { rows } = await pool.query(
        `SELECT webp, sha256 FROM images WHERE id = $1`,
        [req.params.id],
      );
      if (rows.length === 0)
        return res.status(404).json({ error: "not_found" });
      const etag = `"${rows[0].sha256}"`;
      if (req.get("if-none-match") === etag) return res.status(304).end();
      res.set("ETag", etag).type("image/webp").send(rows[0].webp);
    } catch (e) {
      next(e);
    }
  },
);

module.exports = router;
```

Extend the error mapper in `src/app.js` (replace the existing error middleware):

```js
// pg constraint violations -> 400 with the constraint name (ENG-T16).
// sql/ DDL owns the enums; the API never re-validates membership.
app.use((err, req, res, next) => {
  if (err && err.constraint) {
    return res.status(400).json({
      error: "constraint_violation",
      constraint: err.constraint,
    });
  }
  console.error(err);
  res.status(500).json({ error: "internal" });
});
```

Mount both routers: `app.use(require('./routes/chapters')); app.use(require('./routes/images'));`

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/content.test.js`
Expected: `pass 3`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src server/test/content.test.js
git commit -m "feat(server): on-demand chapter qnas pagination + image streaming with ETag/304"
```

---

### Task 8: Sync endpoints - idempotent event ingestion with poison-row fallback (ENG-T5, CEO-T2, D4)

**Files:**

- Create: `server/src/routes/sync.js`
- Modify: `server/src/app.js` (mount)
- Test: `server/test/sync.test.js`

**Interfaces:**

- Consumes: `requireAuth`, event tables (Task 2), `timestamp_skew` rule.
- Produces: `POST /sync/review-events` and `POST /sync/app-events` - body `{"events":[...]}` -> 200 `{"inserted": n}`. Idempotent (`ON CONFLICT (id) DO NOTHING`); `user_id` is ALWAYS `req.user.id` (body user_id ignored - cross-user isolation); batch insert with per-row fallback so one poison row cannot wedge the batch (T4); events >48h ahead -> that row 400-classed and skipped, reported in `{"rejected":[{id, error}]}`.

- [ ] **Step 1: Write the failing test**

`server/test/sync.test.js`:

```js
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

function reviewEvent(overrides = {}) {
  const t = new Date("2026-07-04T10:00:00Z");
  return {
    id: crypto.randomUUID(),
    content_id: "QN1",
    rating: "good",
    shown_at: new Date(t.getTime() - 120000).toISOString(),
    revealed_at: new Date(t.getTime() - 60000).toISOString(),
    rated_at: t.toISOString(),
    local_day: "2026-07-04",
    ...overrides,
  };
}

test("idempotent insert: duplicate sync retries cannot double-count (critical gap 3)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const e = reviewEvent();

  const first = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [e] });
  assert.strictEqual(first.status, 200);
  assert.strictEqual(first.body.inserted, 1);

  const retry = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [e] });
  assert.strictEqual(retry.body.inserted, 0);
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM review_events`,
  );
  assert.strictEqual(rows[0].n, 1);
});

test("poison row falls back per-row; rest of batch lands (T4)", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const good = reviewEvent();
  const poison = reviewEvent({ rating: "easy" }); // invalid wire value

  const res = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [good, poison] });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.inserted, 1);
  assert.strictEqual(res.body.rejected.length, 1);
  assert.strictEqual(res.body.rejected[0].id, poison.id);
  assert.match(res.body.rejected[0].error, /review_events_rating_check/);
});

test("server stamps user_id from the JWT - body cannot write cross-user", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tokA = await tokenFor("userA");
  await tokenFor("userB");
  await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tokA}`)
    .send({ events: [{ ...reviewEvent(), user_id: "userB" }] });
  const { rows } = await pool.query(`SELECT user_id FROM review_events`);
  assert.strictEqual(rows[0].user_id, "userA");
});

test("timestamp skew: rated_at >48h ahead is rejected per-row", async () => {
  await resetUserData();
  const app = createApp({
    pool,
    secrets: SECRETS,
    now: () => new Date("2026-07-04T10:00:00Z"),
  });
  const tok = await tokenFor("u1");
  const skewed = reviewEvent({
    shown_at: "2026-07-10T10:00:00Z",
    revealed_at: "2026-07-10T10:01:00Z",
    rated_at: "2026-07-10T10:02:00Z",
  });
  const res = await request(app)
    .post("/sync/review-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({ events: [skewed] });
  assert.strictEqual(res.body.inserted, 0);
  assert.strictEqual(res.body.rejected[0].error, "timestamp_skew");
});

test("app-events: same pattern incl. hidden_ms; event enum owned by DDL", async () => {
  await resetUserData();
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  const res = await request(app)
    .post("/sync/app-events")
    .set("Authorization", `Bearer ${tok}`)
    .send({
      events: [
        {
          id: crypto.randomUUID(),
          event_type: "recall_revealed",
          content_id: "QN1",
          hidden_ms: 12000,
          occurred_at: "2026-07-04T10:00:00Z",
          local_day: "2026-07-04",
        },
      ],
    });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.inserted, 1);
});

test("no UPDATE/DELETE surface exists for event tables (append-only)", async () => {
  const app = createApp({ pool, secrets: SECRETS });
  const tok = await tokenFor("u1");
  for (const method of ["put", "patch", "delete"]) {
    for (const path of ["/sync/review-events", "/sync/app-events"]) {
      const res = await request(app)
        [method](path)
        .set("Authorization", `Bearer ${tok}`);
      assert.strictEqual(res.status, 404, `${method.toUpperCase()} ${path}`);
    }
  }
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/sync.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/sync.js`:

```js
const express = require("express");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();
const SKEW_MS = 48 * 3600 * 1000;

function makeSyncHandler({ table, columns, timeField }) {
  return async (req, res, next) => {
    try {
      const { pool, now } = req.app.locals;
      const events = req.body?.events;
      if (!Array.isArray(events))
        return res.status(400).json({ error: "missing_events" });

      let inserted = 0;
      const rejected = [];
      for (const e of events) {
        // per-row insert: a poison row can never wedge the batch (T4).
        // Beta scale (~30 users) makes row-at-a-time cost irrelevant.
        if (new Date(e[timeField]).getTime() > now().getTime() + SKEW_MS) {
          rejected.push({ id: e.id, error: "timestamp_skew" });
          continue;
        }
        const values = [e.id, req.user.id, ...columns.map((c) => e[c] ?? null)];
        const params = values.map((_, i) => `$${i + 1}`).join(", ");
        try {
          const r = await pool.query(
            `INSERT INTO ${table} (id, user_id, ${columns.join(", ")})
             VALUES (${params}) ON CONFLICT (id) DO NOTHING`,
            values,
          );
          inserted += r.rowCount;
        } catch (err) {
          rejected.push({ id: e.id, error: err.constraint || "invalid_row" });
        }
      }
      res.json({ inserted, rejected });
    } catch (e) {
      next(e);
    }
  };
}

router.post(
  "/sync/review-events",
  requireAuth,
  makeSyncHandler({
    table: "review_events",
    columns: [
      "content_id",
      "rating",
      "shown_at",
      "revealed_at",
      "rated_at",
      "local_day",
    ],
    timeField: "rated_at",
  }),
);

router.post(
  "/sync/app-events",
  requireAuth,
  makeSyncHandler({
    table: "app_events",
    columns: [
      "event_type",
      "content_id",
      "hidden_ms",
      "occurred_at",
      "local_day",
    ],
    timeField: "occurred_at",
  }),
);

module.exports = router;
```

Mount: `app.use(require('./routes/sync'));`

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/sync.test.js`
Expected: `pass 6`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/routes/sync.js server/src/app.js server/test/sync.test.js
git commit -m "feat(server): idempotent event sync with per-row poison fallback + skew guard"
```

---

### Task 9: /me endpoints - bookmarks LWW, speciality change-once, account deletion cascade (ENG-T8)

**Files:**

- Create: `server/src/routes/me.js`
- Modify: `server/src/app.js` (mount)
- Test: `server/test/me.test.js`

**Interfaces:**

- Consumes: `requireAuth`, `bookmarks`/`users` tables.
- Produces: `PUT /me/bookmarks` body `{"bookmarks":[{content_id, updated_at, deleted}]}` -> LWW merge on `updated_at` (server keeps the newer row, tombstones included) -> 200 `{"bookmarks":[full current set incl tombstones]}`; `POST /me/speciality` body `{"speciality_id"}` -> 200 `{"speciality_id","speciality_change_count"}` / 409 `{"error":"change_limit_reached"}` on the second DISTINCT change (same-value re-save free); `DELETE /me` -> 204 + cascade (review_events, app_events, bookmarks, reports, entitlements).

- [ ] **Step 1: Write the failing test**

`server/test/me.test.js`:

```js
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
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/me.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/me.js`:

```js
const express = require("express");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

// LWW merge on updated_at with tombstones (E7): an incoming row only lands
// if it is strictly newer than what the server holds.
router.put("/me/bookmarks", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    const incoming = req.body?.bookmarks;
    if (!Array.isArray(incoming))
      return res.status(400).json({ error: "missing_bookmarks" });
    for (const b of incoming) {
      await pool.query(
        `INSERT INTO bookmarks (user_id, content_id, updated_at, deleted)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id, content_id) DO UPDATE
           SET updated_at = EXCLUDED.updated_at, deleted = EXCLUDED.deleted
           WHERE bookmarks.updated_at < EXCLUDED.updated_at`,
        [req.user.id, b.content_id, b.updated_at, !!b.deleted],
      );
    }
    const { rows } = await pool.query(
      `SELECT content_id, updated_at, deleted FROM bookmarks WHERE user_id = $1
       ORDER BY updated_at DESC`,
      [req.user.id],
    );
    res.json({ bookmarks: rows });
  } catch (e) {
    next(e);
  }
});

// Change-once server rule (UC4/S3): initial set free; same-value re-save
// free; ONE real change; the second distinct change is rejected HERE, not
// hidden in UI. No empty-track exemption (founder lock, UC4).
router.post("/me/speciality", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    const specialityId = req.body?.speciality_id;
    if (!specialityId)
      return res.status(400).json({ error: "missing_speciality_id" });

    const current = req.user;
    if (current.speciality_id === specialityId) {
      return res.json({
        speciality_id: specialityId,
        speciality_change_count: current.speciality_change_count,
      });
    }
    const isChange = current.speciality_id !== null;
    if (isChange && current.speciality_change_count >= 1) {
      return res.status(409).json({ error: "change_limit_reached" });
    }
    const { rows } = await pool.query(
      `UPDATE users SET speciality_id = $1,
              speciality_change_count = speciality_change_count + $2
       WHERE id = $3
       RETURNING speciality_id, speciality_change_count`,
      [specialityId, isChange ? 1 : 0, current.id],
    );
    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

// Play-mandated account deletion: users-row delete + ON DELETE CASCADE
// covers review_events, app_events, bookmarks, reports, entitlements (S4).
router.delete("/me", requireAuth, async (req, res, next) => {
  try {
    await req.app.locals.pool.query(`DELETE FROM users WHERE id = $1`, [
      req.user.id,
    ]);
    res.status(204).end();
  } catch (e) {
    next(e);
  }
});

module.exports = router;
```

Mount: `app.use(require('./routes/me'));`

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/me.test.js`
Expected: `pass 4`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/routes/me.js server/src/app.js server/test/me.test.js
git commit -m "feat(server): bookmarks LWW+tombstones, speciality change-once, deletion cascade"
```

---

### Task 10: Report endpoint (TD1/ENG-T17) + per-user daily quota (ENG-T14)

**Files:**

- Create: `server/src/routes/reports.js`
- Create: `server/src/middleware/quota.js`
- Modify: `server/src/app.js` (mount reports; wrap content routes with quota)
- Test: `server/test/reports.test.js`, `server/test/quota.test.js`

**Interfaces:**

- Consumes: `requireAuth`, `reports` table, content routes (Task 7).
- Produces: `POST /qna/:id/report` body `{"message"}` (optional client `{"id"}` uuid) -> 201; unauth -> 401; rows readable via `heroku pg:psql` only (no client read endpoint in v1). `quotaGuard` middleware: per-user 2000 content requests/day (UTC), 429 + `Retry-After`; in-memory counter (`ponytail:` single dyno + 30 beta users - move to Postgres/Redis counters if dynos ever scale past one).

- [ ] **Step 1: Write the failing tests**

`server/test/reports.test.js`:

```js
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
```

`server/test/quota.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { createApp } = require("../src/app");
const { signSession } = require("../src/lib/jwt");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");
const { _resetQuota } = require("../src/middleware/quota");

const SECRETS = { v1: "s1" };
const pool = testPool();

test("past N/day -> 429 + Retry-After; under quota a heavy day passes (3A, #9)", async () => {
  await resetUserData();
  await seedContent(pool);
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ('u1','u1','x@y.z')`,
  );
  _resetQuota({ limit: 3 }); // shrink N for the test; prod default 2000
  const app = createApp({ pool, secrets: SECRETS });
  const tok = signSession("u1", { secrets: SECRETS });

  for (let i = 0; i < 3; i++) {
    const ok = await request(app)
      .get("/chapters/CH1/qnas")
      .set("Authorization", `Bearer ${tok}`);
    assert.strictEqual(ok.status, 200, `request ${i + 1} under quota`);
  }
  const blocked = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok}`);
  assert.strictEqual(blocked.status, 429);
  assert.ok(
    Number(blocked.headers["retry-after"]) > 0,
    "Retry-After seconds present",
  );
  _resetQuota({ limit: 2000 });
});

test("quota keys on user, not IP (CGNAT-safe): second user unaffected", async () => {
  await resetUserData();
  await seedContent(pool);
  await pool.query(`INSERT INTO users (id, google_sub, email) VALUES
                    ('u1','u1','x@y.z'), ('u2','u2','q@y.z')`);
  _resetQuota({ limit: 1 });
  const app = createApp({ pool, secrets: SECRETS });
  const tok1 = signSession("u1", { secrets: SECRETS });
  const tok2 = signSession("u2", { secrets: SECRETS });

  await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok1}`);
  const blocked = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok1}`);
  assert.strictEqual(blocked.status, 429);
  const other = await request(app)
    .get("/chapters/CH1/qnas")
    .set("Authorization", `Bearer ${tok2}`);
  assert.strictEqual(other.status, 200, "same IP, different user: passes");
  _resetQuota({ limit: 2000 });
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/reports.test.js test/quota.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/reports.js`:

```js
const express = require("express");
const crypto = require("node:crypto");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

// TD1 content-QA loop. Ops read path is heroku pg:psql - deliberately no
// client read endpoint in v1.
router.post("/qna/:id/report", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    await pool.query(
      `INSERT INTO reports (id, user_id, qna_id, message)
       VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO NOTHING`,
      [
        req.body?.id || crypto.randomUUID(),
        req.user.id,
        req.params.id,
        req.body?.message || null,
      ],
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
```

`server/src/middleware/quota.js`:

```js
// Per-USER daily quota on content endpoints, keyed AFTER token verification
// (outside voice #9: per-IP primary control 429s CGNAT cohorts). UTC reset.
// ponytail: in-memory counter - one dyno, ~30 beta users; move to a
// Postgres/Redis counter if web dynos ever scale past one.
let LIMIT = 2000;
let counters = new Map(); // `${userId}:${utcDate}` -> n

function _resetQuota({ limit } = {}) {
  if (limit) LIMIT = limit;
  counters = new Map();
}

function quotaGuard(req, res, next) {
  const day = new Date().toISOString().slice(0, 10);
  const key = `${req.user.id}:${day}`;
  const n = (counters.get(key) || 0) + 1;
  counters.set(key, n);
  if (n > LIMIT) {
    const midnight = new Date(`${day}T23:59:59.999Z`).getTime();
    const retryAfter = Math.max(1, Math.ceil((midnight - Date.now()) / 1000));
    return res
      .status(429)
      .set("Retry-After", String(retryAfter))
      .json({ error: "quota_exceeded" });
  }
  next();
}

module.exports = { quotaGuard, _resetQuota };
```

Wire the quota into the content routers - in `routes/chapters.js` and `routes/images.js`, add `quotaGuard` after `requireAuth`:

```js
const { quotaGuard } = require('../middleware/quota');
// chapters.js:
router.get('/chapters/:chapterId/qnas', requireAuth, quotaGuard,
  requireEntitlement(chapterSpeciality), /* handler unchanged */
// images.js:
router.get('/images/:id', requireAuth, quotaGuard,
  requireEntitlement(imageSpeciality), /* handler unchanged */
```

Mount reports: `app.use(require('./routes/reports'));`

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/reports.test.js test/quota.test.js`
Expected: `pass 3`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src server/test/reports.test.js server/test/quota.test.js
git commit -m "feat(server): TD1 report endpoint + per-user daily quota (CGNAT-safe)"
```

---

### Task 11: Legal/compliance routes (ENG-T19 server half) + route-inventory contract test (ENG-T15)

**Files:**

- Create: `server/src/routes/legal.js`
- Create: `server/static/privacy.html`, `server/static/terms.html`, `server/static/account-delete.html`
- Modify: `server/src/app.js` (mount)
- Test: `server/test/route_inventory.test.js`

**Interfaces:**

- Consumes: every mounted router (Tasks 4-10).
- Produces: `GET /legal/privacy`, `GET /legal/terms`, `GET /account/delete` (no auth, static HTML); the inventory test that FREEZES the route set - adding any route without updating the inventory table breaks CI.

- [ ] **Step 1: Write the failing test**

`server/test/route_inventory.test.js`:

```js
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
```

- [ ] **Step 2: Run, expect FAIL** (legal routes missing)

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/route_inventory.test.js`

- [ ] **Step 3: Implement**

`server/src/routes/legal.js`:

```js
const express = require("express");
const path = require("node:path");

const router = express.Router();
const staticDir = path.join(__dirname, "..", "..", "static");

router.get("/legal/privacy", (req, res) =>
  res.sendFile(path.join(staticDir, "privacy.html")),
);
router.get("/legal/terms", (req, res) =>
  res.sendFile(path.join(staticDir, "terms.html")),
);
router.get("/account/delete", (req, res) =>
  res.sendFile(path.join(staticDir, "account-delete.html")),
);

module.exports = router;
```

The three static pages carry real compliant copy. `privacy.html` must state, in plain language: what is collected (Google account email/name/photo, chosen speciality, study events - which answers you rated and when, bookmarks, error reports), why (sync your progress, compute study statistics, improve content), where (Heroku Postgres, US region), retention (until account deletion), the in-app AND web deletion paths, crash reporting via Sentry (no answer text, no tokens in payloads), no ads, no data sale, contact email. `terms.html`: personal-study licence, no redistribution of content, account termination for scraping/abuse, beta caveat (free during beta; features may change), governing law India. `account-delete.html` (Play mandate - reachable without the app): what deletion removes, that it is irreversible, and the two paths - in-app `Account -> Delete account`, or email the support address from the Play listing with the Google account address; requests honored within 30 days. Write each as a minimal semantic HTML page (`<main><h1>...`), no styling beyond a readable max-width; each file well over 500 bytes of substantive copy.

Mount in `src/app.js`: `app.use(require('./routes/legal'));`

- [ ] **Step 4: Run the FULL suite, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test`
Expected: every test file passes; the inventory test proves the route set is exactly the amended D3 table.

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add server/src/routes/legal.js server/static server/test/route_inventory.test.js server/src/app.js
git commit -m "feat(server): legal/compliance pages + frozen route-inventory contract test"
```

---

### Task 12: Metrics SQL pack (CEO-T3, ENG-T5) - the beta dashboard

**Files:**

- Create: `sql/metrics/activation.sql`
- Create: `sql/metrics/valid_recall.sql`
- Create: `sql/metrics/d7_return.sql`
- Create: `sql/metrics/README.md`
- Test: `server/test/metrics_pack.test.js`

**Interfaces:**

- Consumes: `review_events` + `app_events` (Task 2), users.
- Produces: three psql-runnable files computing the ONE experiment. All windows use event-carried `local_day` (outside voice #12: offline-first users sync late; `synced_at` windows would undercount week-1 recall/D7 exactly at the 40%/30% thresholds - `synced_at` is a skew sanity bound only). Run in prod: `heroku pg:psql < sql/metrics/activation.sql`.

Definitions (D9/D14/TD4, verbatim):

- **Activated user**: opened >= 1 topic (`app_events.event_type = 'topic_opened'`).
- **Valid recall**: `recall_rated` whose matching `recall_revealed` carries `hidden_ms >= 10000`, joined per `review_events` row; the metric counts DISTINCT PARENT TOPICS of rated QnAs (D14) - the join to topics happens through `qnas.topic_id`.
- **Leading metric (green)**: >= 40% of activated users perform valid recall on >= 5 topics in their first week (first 7 local_days from their first `topic_opened`).
- **D7 return**: user has any event on `local_day >= first_day + 7`.

- [ ] **Step 1: Write the failing test**

`server/test/metrics_pack.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { testPool, resetUserData } = require("./helpers/setup");
const { seedContent } = require("./helpers/seed_content");

const pool = testPool();
const packDir = path.join(__dirname, "..", "..", "sql", "metrics");

async function seedUserJourney(userId, { validRecall }) {
  await pool.query(
    `INSERT INTO users (id, google_sub, email) VALUES ($1,$1,'x@y.z')
                    ON CONFLICT (google_sub) DO NOTHING`,
    [userId],
  );
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, occurred_at, local_day)
     VALUES ($1, $2, 'topic_opened', 'TP1', '2026-07-01T10:00:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId],
  );
  await pool.query(
    `INSERT INTO app_events (id, user_id, event_type, content_id, hidden_ms, occurred_at, local_day)
     VALUES ($1, $2, 'recall_revealed', 'QN1', $3, '2026-07-01T10:05:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId, validRecall ? 15000 : 3000],
  );
  await pool.query(
    `INSERT INTO review_events (id, user_id, content_id, rating, shown_at, revealed_at, rated_at, local_day)
     VALUES ($1, $2, 'QN1', 'good', '2026-07-01T10:04:00Z', '2026-07-01T10:05:00Z', '2026-07-01T10:06:00Z', '2026-07-01')`,
    [crypto.randomUUID(), userId],
  );
}

test("metrics pack computes activation and validity from local_day windows", async () => {
  await resetUserData();
  await seedContent(pool);
  await seedUserJourney("honest", { validRecall: true });
  await seedUserJourney("skimmer", { validRecall: false }); // <10s reveal

  const activation = fs.readFileSync(
    path.join(packDir, "activation.sql"),
    "utf8",
  );
  const act = await pool.query(activation);
  assert.strictEqual(
    Number(act.rows[0].activated_users),
    2,
    "both opened a topic",
  );

  const validRecall = fs.readFileSync(
    path.join(packDir, "valid_recall.sql"),
    "utf8",
  );
  const vr = await pool.query(validRecall);
  const honest = vr.rows.find((r) => r.user_id === "honest");
  const skimmer = vr.rows.find((r) => r.user_id === "skimmer");
  assert.strictEqual(Number(honest.valid_recall_topics), 1);
  assert.ok(
    !skimmer || Number(skimmer.valid_recall_topics) === 0,
    "<10s reveal never counts (D9)",
  );
});

test("pack files never window on synced_at (outside voice #12)", () => {
  for (const f of ["activation.sql", "valid_recall.sql", "d7_return.sql"]) {
    const sql = fs.readFileSync(path.join(packDir, f), "utf8");
    assert.ok(
      !/WHERE[^;]*synced_at/is.test(sql),
      `${f} must window on local_day, not synced_at`,
    );
  }
});
```

- [ ] **Step 2: Run, expect FAIL** (files missing)

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/metrics_pack.test.js`

- [ ] **Step 3: Write the pack**

`sql/metrics/activation.sql`:

```sql
-- Activated user = opened >= 1 topic (D9). Cohort floor: quantitative reads
-- need >= 30 activated users (D11); below that treat as qualitative.
-- Empty-track picks are excluded by definition (no topic to open, PG2/TD3).
SELECT count(DISTINCT user_id) AS activated_users
FROM app_events
WHERE event_type = 'topic_opened';
```

`sql/metrics/valid_recall.sql`:

```sql
-- Valid recall (D9): rating whose reveal kept the answer hidden >= 10s.
-- Unit = QnA (D14); the leading metric counts DISTINCT PARENT TOPICS of
-- validly-rated QnAs in the user's FIRST WEEK (first 7 local_days from
-- first topic_opened). Windows ride event-carried local_day - never synced_at.
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type = 'topic_opened'
  GROUP BY user_id
),
valid_reveals AS (
  SELECT user_id, content_id, local_day
  FROM app_events
  WHERE event_type = 'recall_revealed' AND hidden_ms >= 10000
)
SELECT f.user_id,
       count(DISTINCT q.topic_id) AS valid_recall_topics,
       count(DISTINCT re.content_id) AS valid_recall_qnas
FROM first_day f
JOIN review_events re
  ON re.user_id = f.user_id
 AND re.local_day BETWEEN f.d0 AND f.d0 + 6
JOIN valid_reveals vr
  ON vr.user_id = re.user_id AND vr.content_id = re.content_id
JOIN qnas q ON q.id = re.content_id
GROUP BY f.user_id
ORDER BY valid_recall_topics DESC;
```

`sql/metrics/d7_return.sql`:

```sql
-- D7 return: any event on or after first_day + 7 (local_day windows).
-- TD4 gates: green >= 40% recall AND D7 >= 30% on >= 30 activated;
-- yellow recall 20-40% or D7 15-30%; red below.
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type = 'topic_opened'
  GROUP BY user_id
),
returned AS (
  SELECT DISTINCT e.user_id
  FROM app_events e JOIN first_day f ON f.user_id = e.user_id
  WHERE e.local_day >= f.d0 + 7
)
SELECT (SELECT count(*) FROM first_day) AS activated_users,
       (SELECT count(*) FROM returned) AS returned_d7,
       round(100.0 * (SELECT count(*) FROM returned)
             / GREATEST((SELECT count(*) FROM first_day), 1), 1) AS d7_pct;
```

`sql/metrics/README.md`: one paragraph - how to run each file via `heroku pg:psql`, the TD4 green/yellow/red thresholds, the >= 30 activated-user floor, the 45-50 install recruiting note (TODOS 4), and the rule that windows ride `local_day` with `synced_at` reserved for skew sanity checks.

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test test/metrics_pack.test.js`
Expected: `pass 2`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add sql/metrics server/test/metrics_pack.test.js
git commit -m "feat(sql): leading-metric pack - activation, valid recall (>=10s), D7 return on local_day windows"
```

---

### Task 13: Ops appendix - deploy docs + CI workflow (ENG-T13 close-out)

**Files:**

- Create: `server/README.md`
- Create: `.github/workflows/server-ci.yml`

**Interfaces:**

- Consumes: everything above.
- Produces: the deploy runbook lane D's smoke test follows; CI that builds the disposable Postgres from `sql/` from zero (one schema truth, no drift).

- [ ] **Step 1: Write `server/README.md`**

Sections, each with exact commands:

1. **Local dev**: `createdb diplomate_dev`, `DATABASE_URL=postgres://localhost/diplomate_dev bash tools/db/apply.sh`, `SESSION_JWT_SECRET='{"v1":"dev-secret"}' GOOGLE_WEB_CLIENT_ID=<web-client-id> DATABASE_URL=... npm start`.
2. **Tests**: the bootstrap block from Global Constraints.
3. **Deploy** (Heroku, monorepo): `heroku create diplomate-api`, `heroku addons:create heroku-postgresql:essential-0`, `heroku config:set GOOGLE_WEB_CLIENT_ID=... SESSION_JWT_SECRET='{"v1":"<openssl rand -hex 32>"}'`, `git push heroku main` (root `Procfile` points at `server/src/index.js` - no subdir buildpack needed), migrations: `heroku pg:psql < sql/0001_content_v0.sql` (each file, in order; record applied numbers in the release notes).
4. **Dyno tier**: Basic ($7/mo, never sleeps) RECOMMENDED for beta - content is on demand since the no-downloads revision, so wake latency is user-facing on every study session, and the Eco wake path cannot run in CI (outside voice #6). If Eco is kept anyway: client dio RECEIVE timeout >= 35s + visible progress.
5. **Config truth**: `beta_active` lives in the `app_config` DB row (flip with `heroku pg:psql -c "UPDATE app_config SET value='false' WHERE key='beta_active'"`), deliberately not a config var (#8).
6. **JWT rotation**: add the new kid FIRST in the JSON (`{"v2":"<new>","v1":"<old>"}`), deploy, retire `v1` after 90 days.
7. **Deploy smoke** (after every push): `curl -fsS https://<app>.herokuapp.com/health` -> `{"ok":true}`; then sign-in + one chapter fetch from the app build (lane D automates this).

- [ ] **Step 2: Write `.github/workflows/server-ci.yml`**

```yaml
name: server-ci
on:
  push:
    paths: ["server/**", "sql/**", "tools/db/**"]
jobs:
  contract-suite:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: postgres, POSTGRES_DB: diplomate_test }
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 5s
          --health-timeout 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22" }
      - name: Apply migrations from zero (one schema truth)
        run: DATABASE_URL=postgres://postgres:postgres@localhost:5432/diplomate_test bash tools/db/apply.sh
      - name: Install
        working-directory: server
        run: npm ci || npm install
      - name: Contract suite
        working-directory: server
        env:
          TEST_DATABASE_URL: postgres://postgres:postgres@localhost:5432/diplomate_test
        run: node --test
```

- [ ] **Step 3: Verify CI passes locally (same steps), commit**

```bash
cd /Users/nirmit/Codebases/DiploMate/server && TEST_DATABASE_URL=postgres://localhost/diplomate_test node --test
cd /Users/nirmit/Codebases/DiploMate
git add server/README.md .github/workflows/server-ci.yml
git commit -m "docs(server): ops runbook (deploy, dyno tier, rotation) + CI from zero"
```

---

## Coverage

| Source task / lock                                                                                                               | Plan task(s)                                                       |
| -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| ENG-T12 session-JWT policy (90d HS256 + kid, sliding renewal, revocation, wrong-aud rejection) + 4 contract rows                 | Tasks 3, 4                                                         |
| ENG-T13 ops (Procfile, engines pin, sql/ via pg:psql + CI-from-zero, config vars, Pool max 5, /health, deploy smoke)             | Tasks 1, 13                                                        |
| ENG-T14 quota (per-user daily, 429 + retry-after, heavy-day-under; per-IP log-only on /auth)                                     | Tasks 4 (IP log-only), 10                                          |
| ENG-T15 route inventory == amended D3 table, non-inventory 404, sole auth route                                                  | Task 11                                                            |
| ENG-T16 (API half): constraint violation -> 400 with name; constants point at DDL; end-to-end invalid-enum row                   | Tasks 7 (mapper + constants), 8 (invalid-enum row via poison test) |
| ENG-T17 TD1 report rows (authed persist, unauth 401, psql read path; cascade incl. reports)                                      | Tasks 9 (cascade), 10                                              |
| ENG-T18 compression + per-item responses, never whole-chapter buffering                                                          | Tasks 1 (middleware), 7 (per-item shape)                           |
| ENG-T19 server half (privacy/terms/deletion pages, real copy)                                                                    | Task 11                                                            |
| ENG-T2 (093233) beta_active clause, no seeding race                                                                              | Task 5                                                             |
| ENG-T3 contract suite (two-JWT isolation, append-only 404s, no content writes, canary, CHECKs, one check FIRST - H2 fail-closed) | Tasks 5, 8, 9, 11 (suite accretes per task)                        |
| ENG-T5 app_events DDL + synced_at defaults + metrics WITH the DDL                                                                | Tasks 2, 12                                                        |
| ENG-T8 set_speciality change-once, deletion cascade, bookmark LWW + tombstones                                                   | Task 9                                                             |
| CEO-T2 app_events schema + idempotent sync                                                                                       | Tasks 2, 8                                                         |
| CEO-T3 leading-metric SQL pack (local_day windows, hidden_ms >= 10000, D7)                                                       | Task 12                                                            |
| CEO-T4 entitlement middleware final shape                                                                                        | Task 5                                                             |
| D5 (de-Neoned): plain Google verification via google-auth-library, upsert users, sole route                                      | Tasks 3, 4, 11                                                     |
| NO OFFLINE DOWNLOADS revision: /chapters/:id/qnas + ETag images; no /bundles route anywhere                                      | Tasks 7, 11 (inventory pins it)                                    |
| Test-plan "API / Contract Suite" rows                                                                                            | Tasks 5-11 (each row lands in the named test file)                 |

Out of scope (owned by neighboring plans):

- `sql/0001` + `0002` + apply script: `2026-07-04-day1-content-ddl.md`.
- Content INSERTs + `content_version` bumps: `2026-07-04-ingestion-pipeline.md`.
- Client behavior (dio, X-Refreshed-Token storage mid-batch, backoff + jitter, secure storage, deploy smoke E2E, Play SHA-1/console work, Data Safety form): `2026-07-04-integration-release.md`.
- App UI: `2026-07-04-flutter-shell-screens.md`; drift/Leitner/events: `2026-07-04-study-loop-srs.md`.
- Founder-only: CEO-T1, CEO-T6..T9, TODOS 1-5/7 - explicitly no tasks here.
