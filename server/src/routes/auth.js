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
