# Speciality select (onboarding + one-time change) — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

One screen, two modes (`onboard` / `change`), set by `openSpec(mode)`. Sits
between Sign-in and Home on first run; reachable later exactly once from
Account. Single-select over all 61 DNB/DrNB exam tracks.

## UI (top → bottom)

- Topbar: title `Your speciality`; back button present but hidden — shown only
  in `change` mode (→ Account).
- Lede: `Model answers, syllabus and your recall queue are built for one exam.
Pick yours.`
- Search input, placeholder `Search — e.g. cardio, ENT, DrNB…`
  (aria-label `Search specialities`).
- Count line (aria-live): `30 DNB · 31 DrNB` at rest; `N match` / `N matches`
  while filtering.
- Two grouped radiogroup lists with headers `DNB — Broad Specialities` (30
  rows) and `DrNB — Super Specialities` (31 rows); each row = name + type tag.
  Row inventory lives in `SPEC_DNB` / `SPEC_DRNB` in the source (61 total).
- Empty state: `No speciality matches "<query>".` + `Try a shorter term —
e.g. "cardio" or "paediatric".`
- CTA: `Continue` (onboard) / `Save change` (change); disabled until a row is
  pending.
- Note under CTA — onboard: `Required to continue · you can change it once
later in Account.` (once bolded); change: `You can change your speciality
once — this is that change.`
- No bottom nav in either mode.

## Behaviors

- **Filter:** substring, case-insensitive, over the full `"Name (DNB/DrNB)"`
  string — so `drnb` filters by type. Matched substring inside the visible
  name wraps in `<mark>`; empty groups hide their header; count updates.
- **Enter** in the search box picks the top visible match.
- Row tap → selected style (teal fill, check icon), CTA enables.
- **Onboard mode:** unskippable — no back, no nav, no skip. Shown once:
  `openSpec('onboard')` short-circuits to Home if already chosen (demo chip
  passes `force` to re-show).
- **Change mode:** current track **pre-selected** (`pending = chosen`), so the
  CTA starts enabled; re-saving the same value does **not** burn the change;
  a real change increments `changesUsed` (max 1 — Account row disables after).
- Commit → `updateAcct()` then Home (onboard) or Account (change).

## Non-goals

- Persistence (`speciality_id` on Neon Auth profile — backend), content
  availability messaging for non-Anaesthesia picks (open edge state D6).

## Verify (manual, preview server)

1. `cardio` → count shows matches across both groups, substring highlighted;
   `drnb` → only DrNB rows.
2. Gibberish query → empty state with the query echoed; clearing restores
   `30 DNB · 31 DrNB`.
3. Enter picks the top match; CTA enables only after a selection.
4. Complete onboarding → Home. Account row reads `<Speciality> · can change
once`; change to another track → row reads `· one-time change used` and no
   longer opens the screen; re-saving the same value doesn't consume it.
