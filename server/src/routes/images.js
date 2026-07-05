const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireEntitlement } = require("../middleware/entitlement");

const router = express.Router();

async function imageSpeciality(req, pool) {
  const { rows } = await pool.query(
    `SELECT c.speciality_id FROM images i
       JOIN qnas q ON i.qna_id = q.id
       JOIN topics t ON q.topic_id = t.id
       JOIN chapters c ON t.chapter_id = c.id
     WHERE i.id = $1`,
    [req.params.id],
  );
  return rows[0]?.speciality_id ?? null;
}

// Binary stream, <=200KB per image (DDL CHECK) - entitlement-gated,
// ETag = sha256 so the client caches with If-None-Match (304).
router.get(
  "/images/:id",
  requireAuth,
  requireEntitlement(imageSpeciality),
  async (req, res, next) => {
    try {
      const { pool } = req.app.locals;
      const { rows } = await pool.query(
        `SELECT webp, sha256 FROM images WHERE id = $1`,
        [req.params.id],
      );
      if (rows.length === 0)
        return res.status(404).json({ error: "not_found" });
      const etag = `"${rows[0].sha256}"`;
      if (req.get("if-none-match") === etag) return res.status(304).end();
      res.set("ETag", etag).type("image/webp").send(rows[0].webp);
    } catch (e) {
      next(e);
    }
  },
);

module.exports = router;
