-- 0004_drop_topics.sql - content pass 2026-07-06: qnas hang directly off
-- chapters; the topics layer is removed (design doc jolly-banach-f5aef8,
-- eng-review amendments 4/9/15).
--
-- OPS (amendment 15): apply via `heroku pg:psql < sql/0004_drop_topics.sql`
-- IMMEDIATELY BEFORE promoting the topics-less server deploy. The brief
-- old-code-new-schema window is acceptable at zero-user beta; never leave a
-- migrated DB under old server code unattended. Local/CI: tools/db/apply.sh.
--
-- EVENT RENAME (amendment 4): the CHECK below admits 'chapter_opened' (the
-- event the app emits from now on) AND keeps 'topic_opened' for safety;
-- production app_events is empty pre-launch, so no historical rows exist
-- either way. Metrics key on event_type IN ('chapter_opened','topic_opened').
-- Dropping 'topic_opened' entirely is deferred post-beta.
--
-- SWEEP CRITERION (amendment 14, identifier-level): after the four rewrites,
--   grep -rniE 'topic_id|topic_count|topicId|topics?\b' \
--     app/lib app/test server/src server/test ingestion/src ingestion/test \
--     ingestion/fixtures ingestion/generator sql/metrics ingestion/AUTHORING.md \
--   | grep -viE 'topical|topic_opened'
-- must return zero lines. Exempt: medical content strings ("topical
-- anaesthesia"), the retained 'topic_opened' literal (this CHECK, metrics
-- IN-lists, constants mirrors), and append-only history (sql/0001, sql/0003,
-- this file).

BEGIN;

ALTER TABLE qnas ADD COLUMN chapter_id TEXT REFERENCES chapters(id);

UPDATE qnas q SET chapter_id = t.chapter_id
FROM topics t WHERE q.topic_id = t.id;

ALTER TABLE qnas ALTER COLUMN chapter_id SET NOT NULL;

-- C1: per-topic sort_order values collide once topics collapse into one
-- chapter; renumber 1..N per chapter in (topic order, qna order, id) so
-- ORDER BY sort_order LIMIT/OFFSET pagination is stable. The rewritten page
-- query ALSO orders by (sort_order, id) as a permanent tiebreak.
WITH renumbered AS (
  SELECT q.id,
         ROW_NUMBER() OVER (
           PARTITION BY q.chapter_id
           ORDER BY t.sort_order, q.sort_order, q.id
         ) AS rn
  FROM qnas q JOIN topics t ON q.topic_id = t.id
)
UPDATE qnas q SET sort_order = r.rn FROM renumbered r WHERE q.id = r.id;

ALTER TABLE qnas DROP COLUMN topic_id;
DROP TABLE topics;

-- Perf 1: 0001 shipped zero secondary indexes; the manifest EXISTS filter,
-- qna_count subqueries, page queries, and publish orphan-deletes all filter
-- on these columns.
CREATE INDEX qnas_chapter_id_idx ON qnas (chapter_id);
CREATE INDEX images_qna_id_idx ON images (qna_id);

ALTER TABLE app_events DROP CONSTRAINT app_events_event_type_check;
ALTER TABLE app_events ADD CONSTRAINT app_events_event_type_check
  CHECK (event_type IN ('chapter_opened','topic_opened','recall_shown',
                        'recall_revealed','recall_rated','session_start'));

COMMIT;
