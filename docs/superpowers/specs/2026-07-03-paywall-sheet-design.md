# Paywall sheet — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Bottom sheet (injected into `.paywall-host`, scrim + slide-up), opened by any
locked Syllabus row. The simplified D18 sheet: contents → price → one action →
one support line. No UPI explainer, no activation-time promise, no restore row
(restore is implicit under Google-only sign-in, D5).

## UI (top → bottom)

- Overline: `Unlock`. Heading: `Full Anaesthesia access`.
- Price line: `₹499` + `one-time · 18 chapters`.
- Included list (check icons):
  - `All 18 chapters — every previous-year model answer, structured for recall`
  - `Mark-earning diagrams (TAP block, oxygen cascade…) offline`
  - `Spaced-repetition queue across the whole syllabus`
  - `Free updates as new papers are added`
- Footer CTA: `Purchase`. Sub-link: `Trouble? Mail us`.

## Behaviors

- Opened by locked Syllabus rows (`data-sheet`) or the demo `__paywall` chip
  (shows Syllabus first, then the sheet).
- Scrim tap closes; sheet animates in/out.
- `Purchase` is inert — what it does in beta is an **open decision** (plan
  D18 refinement; beta is manual UPI + hand-set entitlements).

## Verify (manual, preview server)

1. Any locked Syllabus row opens the sheet; scrim tap closes it.
2. Copy shows exactly one action (`Purchase`) and one support route
   (`Trouble? Mail us`) — no restore row, no payment-instructions CTA.
3. No answer content is visible behind or inside the sheet.
