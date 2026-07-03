# Reader / Recall — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior. In-answer search
is specced separately: `2026-07-03-reader-answer-search-design.md`.
Status: **Implemented in the prototype (2026-07-03).**

## What

One surface, two states (`before` / `after`), toggled by `setReader()`. The
soft recall gate: attempt first, reveal to check, rate to schedule. The
revealed answer renders on pure white with the examiner's red margin — the two
signature moves (DESIGN.md).

## UI — chrome (both states)

- Topbar: back (→ Topics) · overline `Suggestion · 3 of 12` · search icon
  (`after`-only; see search spec).
- Breadcrumb: `Regional Anaesthesia` › `Truncal blocks` › `TAP block` —
  ancestors tappable (→ Topics), leaf inert. Right-aligned **bookmark toggle**
  (`aria-pressed`).
- Question block: meta chips `2022 Paper II` · `10 marks` · `Due today` (the
  due chip hides after reveal); question text: `Define TAP block. Describe the
anatomical basis, technique, and complications of an ultrasound-guided
Transversus Abdominis Plane block.`
- No bottom nav.

## UI — before reveal

- Prompt (pen icon): `Outline your answer aloud or on paper. Then reveal to
check what earns marks.`
- Attempt line: `Attempting… take your time — nothing’s timing you.` (no
  countdown, no hard lock — the ≥10 s validity rule stays invisible, D9/D15).
- Full-width CTA: `Reveal Answer`, bottom thumb zone.

## UI — after reveal (answer on white)

- **`What earns marks`** (target icon) — criteria + weights:
  `Definition` 1 · `Anatomy — 3 muscle layers, plane` 2 · `USG-guided
technique` 3 · `Indications` 1 · `Complications` 2 · `Labelled diagram` 1.
- **Answer sections** (`.asec`), each with a red examiner's-margin numeral:
  `Definition` (1) → `Anatomical basis` (2) → `Technique — USG-guided` (3) →
  diagram plate → `Complications` (2) → `Summary line` (1).
- **Diagram plate:** inline SVG (abdominal-wall layers + in-plane needle),
  caption `Fig 1 — Abdominal wall layers & needle in the TAP plane`, zoom
  affordance `Tap to enlarge`, `Full screen` button.
- **Rating tray** (in-flow at the bottom, scrolls with content):
  header `How well did you recall it?` + counter `2 done · 10 due`;
  three buttons (icon + label + interval hint):
  `Unable to recall` / `today` · `Hard` / `2 days` · `Good` / `3 days`.
- Toast pill (`.ack`) at bottom.

## Behaviors

- `Reveal Answer` → `after`: shows `.after-only`, hides `.before-only` and the
  due chip; scrolls to top. Reveal is a brief vertical uncover (DESIGN.md
  motion budget).
- **Rating tap** → toast `✓ <interval> · next answer` (e.g. `✓ in 2 days ·
next answer`) → after 650 ms resets to `before`, clears the bookmark, scrolls
  top — the auto-advance stand-in.
- **Bookmark toggle:** outline ↔ filled teal, `aria-pressed`, label swap;
  toasts `✓ Bookmarked` / `Bookmark removed`. Cleared on rating (auto-advance)
  and on re-entering the screen.
- **Every `show()` re-entry resets to `before`** — the recall gate can't be
  bypassed by navigating away and back.

## Fullscreen diagram viewer (injected dialog, not a pane)

- Opens from `Full screen` or tapping the diagram. `role="dialog"`,
  `aria-modal`; overline `Diagram` + the figure caption; close button
  (`Close full screen`) or Escape.
- Zoom 1×–5×: pinch, mouse-wheel, double-tap toggles 1× ↔ 2.5×; drag-to-pan,
  clamped to bounds.
- Rotate pill: `Rotate for a larger view` ↔ `Back to portrait` (rotates the
  SVG 90° in-app; zoom resets on rotate).
- Footer gesture hint: `Pinch, double-tap or scroll to zoom · drag to pan`.
- Any navigation (`show()`) closes it.

## Verify (manual, preview server)

1. Pre-reveal: no answer content, no search icon, due chip visible.
2. Reveal → answer on white, red margin numerals, due chip gone, search icon
   appears, tray at content end.
3. Rate `Hard` → toast `✓ in 2 days · next answer`; ~0.7 s later screen is
   back at pre-reveal with bookmark cleared.
4. Bookmark toggles with toasts and `aria-pressed`.
5. Diagram → fullscreen: zoom, pan, rotate pill toggles, Escape closes.
6. Leave mid-reveal via crumb, return → pre-reveal again.
