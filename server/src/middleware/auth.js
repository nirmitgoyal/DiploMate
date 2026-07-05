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
