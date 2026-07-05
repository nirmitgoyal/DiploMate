# Home - design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Queue-first home. The suggested-answers CTA is the day's work; everything else
is quiet context. "Suggested," never "due," on this screen (founder-locked
framing - guidance, not homework).

## UI (top → bottom)

- Topbar title: `Home` (28 px serif display).
- Greeting: `Good morning, Ananya` (name bold, `--teal-ink`).
- **Primary CTA** (play icon, → Reader): `View 12 suggested answers`.
  - Count from `const suggested = 12` - placeholder; wire to real recall-queue
    length when backend lands.
  - Label pluralizes: `answer` when count = 1, else `answers`.
  - **Hidden entirely when count = 0** - no empty or disabled button; the
    ghost CTA below drops its top margin to close the gap.
- **Ghost CTA** (bookmark icon, → Bookmarks): `View your bookmarks`.
- Stats block, overline `This Week`, two honest figures:
  `41` / `answers recalled` and `71%` (ok-green) / `rated Easy`.
  Pair baseline-aligned (number-to-caption baseline, 8px gap, 28px between
  the pair). Never a streak (DESIGN.md ban).
- **Pinned resume row**, overline `Pick up where you left off`: play badge,
  `Airway Management` / `Topic 3 of 14 · Rapid sequence induction`, → Reader.
  Sticky above the bottom nav, outside the scroll area.
  - First run (no starter-chapter auto-download; downloads/offline feature
    removed 2026-07-04, founder): the pinned slot shows `Start here`, routing
    into the highest-exam-weight chapter's first topic.
- Bottom nav: Home active.

## Verify (manual, preview server)

1. Default render: CTA reads `View 12 suggested answers`; ghost CTA 10 px
   below; both stats show.
2. Set `suggested = 0` in source → primary CTA absent, ghost CTA closes the
   gap (no orphan margin).
3. Set `suggested = 1` → label is singular `answer`.
4. Resume row stays pinned above the nav while the view scrolls.

## States (2026-07-04, DESIGN.md State Specs 6-8)

N=0: primary CTA absent, ghost CTA closes the gap. This Week: `% rated
Easy` renders only at n>=5 ratings in the trailing 7 days. Day-zero resume
slot: overline `Start here`, highest-exam-weight chapter title, subtitle
`Begin with the highest-yield chapter`, routes to that chapter's Topics.
