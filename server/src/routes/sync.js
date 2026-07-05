const express = require("express");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();
const SKEW_MS = 48 * 3600 * 1000;

function makeSyncHandler({ table, columns, timeField }) {
  return async (req, res, next) => {
    try {
      const { pool, now } = req.app.locals;
      const events = req.body?.events;
      if (!Array.isArray(events))
        return res.status(400).json({ error: "missing_events" });

      let inserted = 0;
      const rejected = [];
      for (const e of events) {
        // per-row try: a poison row - malformed element included - can never
        // wedge the batch (T4). Beta scale (~30 users) makes row-at-a-time
        // cost irrelevant.
        try {
          if (new Date(e?.[timeField]).getTime() > now().getTime() + SKEW_MS) {
            rejected.push({ id: e?.id, error: "timestamp_skew" });
            continue;
          }
          const values = [
            e.id,
            req.user.id,
            ...columns.map((c) => e[c] ?? null),
          ];
          const params = values.map((_, i) => `$${i + 1}`).join(", ");
          const r = await pool.query(
            `INSERT INTO ${table} (id, user_id, ${columns.join(", ")})
             VALUES (${params}) ON CONFLICT (id) DO NOTHING`,
            values,
          );
          inserted += r.rowCount;
        } catch (err) {
          rejected.push({ id: e?.id, error: err.constraint || "invalid_row" });
        }
      }
      res.json({ inserted, rejected });
    } catch (e) {
      next(e);
    }
  };
}

router.post(
  "/sync/review-events",
  requireAuth,
  makeSyncHandler({
    table: "review_events",
    columns: [
      "content_id",
      "rating",
      "shown_at",
      "revealed_at",
      "rated_at",
      "local_day",
    ],
    timeField: "rated_at",
  }),
);

router.post(
  "/sync/app-events",
  requireAuth,
  makeSyncHandler({
    table: "app_events",
    columns: [
      "event_type",
      "content_id",
      "hidden_ms",
      "occurred_at",
      "local_day",
    ],
    timeField: "occurred_at",
  }),
);

module.exports = router;
