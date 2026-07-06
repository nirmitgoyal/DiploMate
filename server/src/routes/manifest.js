const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");
const { SCHEMA_VERSION, MIN_APP_VERSION } = require("../lib/constants");

const router = express.Router();

router.get("/manifest", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    const { rows: specialities } = await pool.query(`
      SELECT s.id, s.name, s.exam_type, s.slug, s.sort_order,
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
      // Empty-chapter filter (design deliverable): Stage 0 publishes only
      // populated chapters; this WHERE EXISTS is the belt-and-braces server
      // invariant that keeps nav clean even if an empty chapter ever lands.
      const { rows: chapters } = await pool.query(
        `
        SELECT c.id, c.title, c.slug, c.sort_order, c.exam_weight, c.content_version,
               (SELECT count(*)::int FROM qnas q WHERE q.chapter_id = c.id) AS qna_count
        FROM chapters c
        WHERE c.speciality_id = $1
          AND EXISTS (SELECT 1 FROM qnas q WHERE q.chapter_id = c.id)
        ORDER BY c.sort_order`,
        [spec],
      );
      res.json({ ...body, chapters });
    });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
