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
