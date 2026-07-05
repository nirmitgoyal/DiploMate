# Reader / Recall - design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior. In-answer search
is specced separately: `2026-07-03-reader-answer-search-design.md`.
Status: **Implemented in the prototype (2026-07-03; founder UI pass synced
2026-07-04 - rating relabel, SRS de-surfaced, anchor links).**

## What

One surface, two states (`before` / `after`), toggled by `setReader()`. The
soft recall gate: attempt first, reveal to check, rate to schedule. The
revealed answer renders on pure white with the examiner's red margin - the two
signature moves (DESIGN.md).

## UI - chrome (both states)

- Topbar: back (→ Topics) · overline `Suggestion · 3 of 12` · search icon
  (`after`-only; see search spec).
- Breadcrumb: `Regional Anaesthesia` › `Truncal blocks` › `TAP block` -
  ancestors tappable (→ Topics), leaf inert. Right-aligned **bookmark toggle**
  (`aria-pressed`).
- Question block: meta chips `2022 Paper II` · `10 marks` (no `Due today`
  chip - SRS de-surfaced 2026-07-04); question text: `Define TAP block.
Describe the anatomical basis, technique, and complications of an
ultrasound-guided Transversus Abdominis Plane block.`
- No bottom nav.

## UI - before reveal

- Prompt (pen icon): `Outline your answer aloud or on paper. Then reveal to
check what earns marks.`
- Attempt line: `Attempting… take your time - nothing’s timing you.` (no
  countdown, no hard lock - the ≥10 s validity rule stays invisible, D9/D15).
- Full-width CTA: `Reveal Answer`, bottom thumb zone.

## UI - after reveal (answer on white)

- **`What earns marks`** (target icon) - criteria + weights, each row an
  **anchor link** (`data-seek` → matching `data-sec`) that jumps to its
  answer section:
  `Definition` 1 · `Anatomy - 3 muscle layers, plane` 2 · `USG-guided
technique` 3 · `Indications` 1 · `Complications` 2 · `Labelled diagram` 1.
- **Answer sections** (`.asec`, each a `data-sec` anchor target) with a red
  examiner's-margin numeral:
  `Definition` (1) → `Anatomical basis` (2) → `Technique - USG-guided` (3) →
  diagram plate (1) → `Indications` (1) → `Complications` (2) →
  `Summary line` (no numeral).
- **Diagram plate:** inline SVG (abdominal-wall layers + in-plane needle),
  caption `Fig 1 - Abdominal wall layers & needle in the TAP plane`, one zoom
  affordance: `Tap to enlarge` button (`data-fs`, aria-label `Open diagram
full screen`); tapping the SVG itself also opens fullscreen.
- **Rating tray** (in-flow at the bottom, scrolls with content):
  header `How well did you recall it?` - no done/due counter, no interval
  hints (SRS de-surfaced 2026-07-04); three buttons, best to worst, face
  icon + word (never color alone), traffic-light colors:
  `Easy` (smile, `--ok` green) · `Medium` (meh, `--amber`) ·
  `Hard` (frown, `--exam-red`/`--danger`).
  Wire enum `{again,hard,good}` unchanged - Easy=good, Medium=hard,
  Hard=again (pure display relabel).
- Toast pill (`.ack`) at bottom.

## Behaviors

- `Reveal Answer` → `after`: shows `.after-only`, hides `.before-only`;
  scrolls to top. Reveal is a brief vertical uncover (DESIGN.md motion
  budget).
- **`What earns marks` row tap** → instant `scrollIntoView` to the matching
  `data-sec` answer section.
- **Rating tap** → toast `✓ Rated <tier> · next answer` (e.g. `✓ Rated
Medium · next answer`) → after 650 ms resets to `before`, clears the
  bookmark, scrolls top - the auto-advance stand-in.
- **Bookmark toggle:** outline ↔ filled teal, `aria-pressed`, label swap;
  toasts `✓ Bookmarked` / `Bookmark removed`. Cleared on rating (auto-advance)
  and on re-entering the screen.
- **Every `show()` re-entry resets to `before`** - the recall gate can't be
  bypassed by navigating away and back.

## Fullscreen diagram viewer (injected dialog, not a pane)

- Opens from `Tap to enlarge` or tapping the diagram. `role="dialog"`,
  `aria-modal`; overline `Diagram` + the figure caption; close button
  (`Close full screen`) or Escape.
- Zoom 1×-5×: pinch, mouse-wheel, double-tap toggles 1× ↔ 2.5×; drag-to-pan,
  clamped to bounds.
- Rotate pill: `Rotate for a larger view` ↔ `Back to portrait` (rotates the
  SVG 90° in-app; zoom resets on rotate).
- Footer gesture hint: `Pinch or double-tap to zoom · drag to pan`
  (mouse-wheel zoom still works; the hint copy is device-true).
- Any navigation (`show()`) closes it.

## Verify (manual, preview server)

1. Pre-reveal: no answer content, no search icon, no due/interval copy
   anywhere.
2. Reveal → answer on white, red margin numerals, search icon appears, tray
   at content end (Easy/Medium/Hard, no counter, no interval hints).
3. Rate `Medium` → toast `✓ Rated Medium · next answer`; ~0.7 s later screen
   is back at pre-reveal with bookmark cleared.
4. Tap a `What earns marks` row → view jumps to that answer section.
5. Bookmark toggles with toasts and `aria-pressed`.
6. Diagram → fullscreen: zoom, pan, rotate pill toggles, Escape closes.
7. Leave mid-reveal via crumb, return → pre-reveal again.

## Beta additions (2026-07-04, DESIGN.md State Specs 1, 12, 13)

Content fetch failure renders the inline retry state (`Couldn't load
this - retry`). `Report an answer error` row sits under the rating tray,
post-reveal only, online-only (disabled offline with `Connect to the
internet to report an error.`); submit toasts `✓ Report sent - thank you`.
End-of-queue completion state (queue mode, plan 5): `Today's recall is
complete. N reviewed; next due tomorrow.` + `Study a new answer`.
