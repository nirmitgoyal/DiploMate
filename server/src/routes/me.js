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
      try {
        await pool.query(
          `INSERT INTO bookmarks (user_id, content_id, updated_at, deleted)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (user_id, content_id) DO UPDATE
             SET updated_at = EXCLUDED.updated_at, deleted = EXCLUDED.deleted
             WHERE bookmarks.updated_at < EXCLUDED.updated_at`,
          [req.user.id, b.content_id, b.updated_at, !!b.deleted],
        );
      } catch {
        // A malformed element can never wedge the batch; the trailing full-set
        // SELECT lets the client reconcile. (Matches sync.js per-row isolation.)
      }
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
