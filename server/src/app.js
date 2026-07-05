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
  app.use(require("./routes/auth"));
  app.use(require("./routes/manifest"));
  app.use(require("./routes/chapters"));
  app.use(require("./routes/images"));

  // Terminal 404 for every non-inventory path.
  app.use((req, res) => res.status(404).json({ error: "not_found" }));

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

  return app;
}

module.exports = { createApp };
