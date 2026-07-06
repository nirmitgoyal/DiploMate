const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");
const { quotaGuard } = require("../middleware/quota");
const { PAGE_SIZE, SCHEMA_VERSION } = require("../lib/constants");

const router = express.Router();

async function chapterSpeciality(req, pool) {
  const { rows } = await pool.query(
    `SELECT speciality_id FROM chapters WHERE id = $1`,
    [req.params.chapterId],
  );
  return rows[0]?.speciality_id ?? null; // null -> middleware 404s
}

// On-demand content read (no bundles, no downloads - 2026-07-04 revision).
// Per-item rows only; the dyno never buffers a whole chapter (Issue 7).
router.get(
  "/chapters/:chapterId/qnas",
  requireAuth,
  quotaGuard,
  requireEntitlement(chapterSpeciality),
  async (req, res, next) => {
    try {
      const { pool } = req.app.locals;
      const { chapterId } = req.params;
      const page = Math.max(1, parseInt(req.query.page, 10) || 1);

      const meta = await pool.query(
        `SELECT content_version FROM chapters WHERE id = $1`,
        [chapterId],
      );
      const total = await pool.query(
        `SELECT count(*)::int AS n FROM qnas WHERE chapter_id = $1`,
        [chapterId],
      );
      const pages = Math.max(1, Math.ceil(total.rows[0].n / PAGE_SIZE));

      // ORDER BY (sort_order, id): 0004 renumbers sort_order per chapter, and
      // the id tiebreak keeps LIMIT/OFFSET pages stable forever after (C1).
      const { rows: items } = await pool.query(
        `SELECT q.id, q.chapter_id, q.question, q.years, q.marks, q.earns_marks,
                q.sections, q.sort_order,
                COALESCE((
                  SELECT json_agg(json_build_object(
                    'id', i.id, 'caption', i.caption,
                    'content_description', i.content_description,
                    'byte_size', i.byte_size, 'sha256', i.sha256,
                    'sort_order', i.sort_order) ORDER BY i.sort_order)
                  FROM images i WHERE i.qna_id = q.id), '[]') AS images
         FROM qnas q
         WHERE q.chapter_id = $1
         ORDER BY q.sort_order, q.id
         LIMIT $2 OFFSET $3`,
        [chapterId, PAGE_SIZE, (page - 1) * PAGE_SIZE],
      );

      res.json({
        chapter_id: chapterId,
        content_version: meta.rows[0].content_version,
        schema_version: SCHEMA_VERSION,
        page,
        pages,
        items,
      });
    } catch (e) {
      next(e);
    }
  },
);

module.exports = router;
