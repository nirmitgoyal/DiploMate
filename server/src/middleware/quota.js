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
