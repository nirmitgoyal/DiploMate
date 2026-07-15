-- 0005_qna_summary.sql - 2026-07-14: persist the chapter question-list
-- summary. The app's question list previously derived a one-line gist from
-- `sections` at render; storing it makes the value canonical and lets the
-- wire ship it. Derivation matches ingestion/src/summarize.js and the app's
-- summarizeSections: the `Summary` section if the author wrote one, else the
-- first section, markdown stripped. Publishers set it going forward; the
-- backfill below populates rows already in the corpus.
--
-- Nullable on purpose: a row with an empty `sections` array has no source to
-- derive from and stays NULL, where the app falls back to deriving at render.

ALTER TABLE qnas ADD COLUMN summary TEXT;

WITH chosen AS (
  SELECT q.id,
         COALESCE(
           (SELECT s->>'body_md'
              FROM jsonb_array_elements(q.sections) s
             WHERE lower(s->>'heading') = 'summary'
             LIMIT 1),
           q.sections->0->>'body_md'
         ) AS raw
    FROM qnas q
)
UPDATE qnas q
   SET summary = btrim(
         regexp_replace(
           regexp_replace(
             regexp_replace(chosen.raw,
               '^[[:space:]]*[-*+>#]+[[:space:]]*', '', 'ng'),  -- leading list/heading markers, per line
             '[*_`#]', '', 'g'),                                -- inline emphasis/code/heading chars
           '[[:space:]]+', ' ', 'g'))                           -- collapse whitespace/newlines
  FROM chosen
 WHERE q.id = chosen.id
   AND chosen.raw IS NOT NULL;
