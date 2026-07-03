# Syllabus — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Chapter list for the chosen speciality — first level of the Syllabus →
Topics → Reader drill. Locked chapters stay visible (titles + counts, never
answer previews) and sell the unlock.

## UI (top → bottom)

- Topbar title: `Anaesthesia`.
- Breadcrumb: `Syllabus ›` + `18 chapters`.
- **Chapter rows** (title · meta · state · progress):
  1. `Airway Management` · `14 topics · offline ✓` · done · 57 %
  2. `General Anaesthesia — Pharmacology` · `18 topics` · locked
  3. `Regional Anaesthesia` · `16 topics` · locked
  4–18. locked: `Monitoring & Equipment` 11 · `Obstetric Anaesthesia` 13 ·
  `Cardiac Anaesthesia` 15 · `Neuroanaesthesia` 12 · `Paediatric
  Anaesthesia` 13 · `Critical Care & Ventilation` 19 · `Pain Medicine` 9 ·
  `Trauma, Burns & Resuscitation` 10 · `Blood, Fluids & Transfusion` 8 ·
  `Acid–Base & Electrolytes` 7 · `Anaesthesia for Comorbid Disease` 14 ·
  `Day-care & Remote-location Anaesthesia` 6 · `Physics, Equipment &
  Machines` 12 · `Statistics & Research Methodology` 5 · `Ethics, Consent &
  Medicolegal` 6 (topic counts)
- Row rendering by state:
  - **done** → tappable (→ Topics), progress bar at 57 %, right stat `8/14`
    over `recalled`.
  - **locked** → lock icon before title, `Locked` lozenge, no progress bar;
    tap opens the **paywall sheet**.
- Footer microcopy: `Locked chapters unlock with Anaesthesia access. Titles
shown so you can see the full syllabus — answers stay hidden until unlock.`
- Bottom nav: Syllabus active.

## Behaviors

- Only the unlocked chapter navigates (→ Topics); every locked row opens the
  paywall sheet (`data-sheet`). No answer content leaks from locked rows.

## Verify (manual, preview server)

1. Row 1 → Topics; rows 2–18 → paywall sheet (no navigation).
2. Locked rows show lock icon + `Locked` lozenge and no progress bar.
3. Footer copy present; crumb count matches the row count.
