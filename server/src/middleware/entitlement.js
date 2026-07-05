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
