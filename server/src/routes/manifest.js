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
