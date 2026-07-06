-- Activated user = opened >= 1 chapter (D9 at chapter grain, 2026-07-06).
-- The app emits chapter_opened from schema v2 on; topic_opened stays in the
-- IN-list for back-compat (0004 keeps it legal; prod had zero rows at rename).
-- Cohort floor: quantitative reads need >= 30 activated users (D11); below
-- that treat as qualitative. Empty-track picks are excluded by definition
-- (no chapter to open, PG2/TD3).
SELECT count(DISTINCT user_id) AS activated_users
FROM app_events
WHERE event_type IN ('chapter_opened', 'topic_opened');
