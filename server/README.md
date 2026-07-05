# DiploMate API server

Thin Heroku API dyno: Google sign-in verification + self-owned session JWTs,
entitlement-gated on-demand content endpoints, idempotent event sync,
per-user quota, and compliance routes. One Express app over Heroku Postgres
via `pg` (no ORM). `sql/` numbered migrations own the schema and every wire
enum.

## 1. Local dev

```bash
createdb diplomate_dev
DATABASE_URL=postgres://localhost/diplomate_dev bash tools/db/apply.sh
SESSION_JWT_SECRET='{"v1":"dev-secret"}' GOOGLE_WEB_CLIENT_ID=<web-client-id> DATABASE_URL=postgres://localhost/diplomate_dev npm start
```

Run the first two commands from the repo root; run `npm start` from `server/`.

## 2. Tests

Disposable Postgres, schema applied from zero by the same script CI and
production use - one schema truth, no drift:

```bash
createdb diplomate_test 2>/dev/null || true
DATABASE_URL=postgres://localhost/diplomate_test bash tools/db/apply.sh
cd server
TEST_DATABASE_URL=postgres://localhost/diplomate_test npm test
```

`npm test` runs `node --test --test-concurrency=1`. The suite shares one
Postgres and resets tables via TRUNCATE between files, so tests must run
serially - a plain `node --test` runs files in parallel and races on the
shared DB, producing flaky failures. Always use `npm test`, never bare
`node --test`, when running the full suite.

## 3. Deploy (Heroku, monorepo)

```bash
heroku create diplomate-api
heroku addons:create heroku-postgresql:essential-0
heroku config:set GOOGLE_WEB_CLIENT_ID=<web-client-id> SESSION_JWT_SECRET='{"v1":"<openssl rand -hex 32>"}'
git push heroku main
```

The root `Procfile` points at `server/src/index.js`, so no subdirectory
buildpack config is needed.

Migrations are not run automatically - apply each numbered file in order,
in a single release:

```bash
heroku pg:psql < sql/0001_content_v0.sql
heroku pg:psql < sql/0002_seed_specialities.sql
heroku pg:psql < sql/0003_users_events.sql
```

Record the applied file numbers in the release notes.

## 4. Dyno tier

**Basic ($7/mo, never sleeps) is RECOMMENDED for beta.** Content is served
on demand (no offline downloads), so a cold-start wake is user-facing on
every study session, not hidden behind a one-time install. The Eco wake
path also cannot be exercised in CI.

If Eco is kept anyway, the client's `dio` RECEIVE timeout must be at least
35 seconds with visible progress shown to the user during a wake.

## 5. Config truth

`beta_active` lives in the `app_config` DB row, not a Heroku config var -
this is deliberate, so the billing slice can flip it without a deploy:

```bash
heroku pg:psql -c "UPDATE app_config SET value='false' WHERE key='beta_active'"
```

## 6. JWT rotation

`SESSION_JWT_SECRET` is a JSON object of `{"<kid>": "<secret>"}` pairs. The
first key signs new tokens; every key verifies existing ones.

To rotate: add the new kid FIRST in the JSON, then deploy.

```bash
heroku config:set SESSION_JWT_SECRET='{"v2":"<new>","v1":"<old>"}'
```

Retire `v1` (remove it from the JSON) after 90 days, once every token
signed with it has expired.

## 7. Deploy smoke

After every push:

```bash
curl -fsS https://<app>.herokuapp.com/health
```

Expect `{"ok":true}`. Then sign in and fetch one chapter from the app
build to confirm the full path end to end (lane D automates this).
