# Bookmarks — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Saved questions, reached from Home's ghost CTA (stack child of the Home tab —
not a nav destination). Rows reopen the QnA in the Reader.

## UI (top → bottom)

- Topbar: back (→ Home) + title `Bookmarks`.
- Breadcrumb: `Home` (tappable, → Home) › `Saved · 4 questions` (count =
  row count).
- **Rows** (question · `Chapter · Topic` source), filled-bookmark badge, each
  → Reader:
  1. `TAP block — anatomy, technique & complications` · `Airway · Difficult airway`
  2. `Rapid sequence induction — steps & drug doses` · `Airway Management`
  3. `Difficult airway algorithm (DAS 2015)` · `Airway · Difficult airway`
  4. `Cricothyroidotomy — front-of-neck access` · `Airway Management`
- Footer microcopy: `Questions you bookmark while revising are saved here for
quick recall. Tap any to reopen the answer.`
- Bottom nav: **Home tab active**.

## Behaviors

- Row tap → Reader (pre-reveal, per the global gate). Back and crumb ancestor
  → Home.

## Verify (manual, preview server)

1. Home ghost CTA → Bookmarks; Home tab stays lit.
2. Crumb count matches the number of rows.
3. Any row opens the Reader at pre-reveal; back returns Home.
