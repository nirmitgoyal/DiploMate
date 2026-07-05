-- Activated user = opened >= 1 topic (D9). Cohort floor: quantitative reads
-- need >= 30 activated users (D11); below that treat as qualitative.
-- Empty-track picks are excluded by definition (no topic to open, PG2/TD3).
SELECT count(DISTINCT user_id) AS activated_users
FROM app_events
WHERE event_type = 'topic_opened';
