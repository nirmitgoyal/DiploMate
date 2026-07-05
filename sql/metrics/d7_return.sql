-- D7 return: any event on or after first_day + 7 (local_day windows).
-- TD4 gates: green >= 40% recall AND D7 >= 30% on >= 30 activated;
-- yellow recall 20-40% or D7 15-30%; red below.
WITH first_day AS (
  SELECT user_id, min(local_day) AS d0
  FROM app_events WHERE event_type = 'topic_opened'
  GROUP BY user_id
),
returned AS (
  SELECT DISTINCT e.user_id
  FROM app_events e JOIN first_day f ON f.user_id = e.user_id
  WHERE e.local_day >= f.d0 + 7
)
SELECT (SELECT count(*) FROM first_day) AS activated_users,
       (SELECT count(*) FROM returned) AS returned_d7,
       round(100.0 * (SELECT count(*) FROM returned)
             / GREATEST((SELECT count(*) FROM first_day), 1), 1) AS d7_pct;
