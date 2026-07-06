# Metrics pack

Run each file against prod with `heroku pg:psql < sql/metrics/activation.sql`
(swap in `valid_recall.sql` or `d7_return.sql` as needed) to compute the ONE
beta experiment from the event log.

## Grain change, 2026-07-06 (content pass, eng amendment 4)

The topics layer was removed (sql/0004); questions hang directly off Miller
chapters. The activation event is `chapter_opened`, emitted when a chapter is
opened - the chapter list is the nav level that replaced topics, so
"opened >= 1 content unit" keeps its meaning. `topic_opened` remains legal in
the CHECK and in every query's IN-list for back-compat; production app_events
was EMPTY at the rename (pre-launch), so no historical rows straddle the grain.

`valid_recall.sql` now counts DISTINCT CHAPTERS (`valid_recall_chapters`,
formerly `valid_recall_topics`). A Miller chapter aggregates what were
several topics, so per-user unit counts read LOWER at chapter grain than the
old topic grain would have; this is a denominator change to the experiment's
unit, re-derived here deliberately rather than silently.

## TD4 gates (re-stated at chapter grain)

TD4 reads the two leading numbers together, per activated user cohort:

- GREEN: >= 40% of activated users record >= 1 valid-recall CHAPTER in their
  first week AND D7 return >= 30%.
- YELLOW: recall share 20-40% or D7 15-30%.
- RED: below both.

All three colors only mean something at >= 30 activated users (opened >= 1
chapter); below that floor, treat output as qualitative. Because activation
is well under 100% of installs, TODOS item 4 recruits 45-50 installs to
reliably clear the 30-activated floor and start TD4's four-week decision
clock. Every window rides the event-carried `local_day` column (first 7
local_days from a user's first `chapter_opened` for the recall window,
`local_day >= first_day + 7` for D7) - `synced_at` is never used for
windowing and is reserved for a separate skew sanity check on how late
offline-first clients sync.
