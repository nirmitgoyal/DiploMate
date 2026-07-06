-- Valid recall (D9): rating whose reveal kept the answer hidden >= 10s.
-- Unit = QnA (D14); the leading metric counts DISTINCT PARENT CHAPTERS of
-- validly-rated QnAs in the user's FIRST WEEK (first 7 local_days from
-- first chapter_opened). Chapter grain since 2026-07-06 (0004 removed the
-- topics layer; see README for the TD4 re-derivation). Windows ride
-- event-carried local_day - never synced_at.
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type IN ('chapter_opened', 'topic_opened')
  GROUP BY user_id
),
valid_reveals AS (
  SELECT user_id, content_id, local_day
  FROM app_events
  WHERE event_type = 'recall_revealed' AND hidden_ms >= 10000
)
SELECT f.user_id,
       count(DISTINCT q.chapter_id) AS valid_recall_chapters,
       count(DISTINCT re.content_id) AS valid_recall_qnas
FROM first_day f
JOIN review_events re
  ON re.user_id = f.user_id
 AND re.local_day BETWEEN f.d0 AND f.d0 + 6
JOIN valid_reveals vr
  ON vr.user_id = re.user_id AND vr.content_id = re.content_id
JOIN qnas q ON q.id = re.content_id
GROUP BY f.user_id
ORDER BY valid_recall_chapters DESC;
