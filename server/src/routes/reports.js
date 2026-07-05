const express = require("express");
const crypto = require("node:crypto");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

// TD1 content-QA loop. Ops read path is heroku pg:psql - deliberately no
// client read endpoint in v1.
router.post("/qna/:id/report", requireAuth, async (req, res, next) => {
  try {
    const { pool } = req.app.locals;
    await pool.query(
      `INSERT INTO reports (id, user_id, qna_id, message)
       VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO NOTHING`,
      [
        req.body?.id || crypto.randomUUID(),
        req.user.id,
        req.params.id,
        req.body?.message || null,
      ],
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
