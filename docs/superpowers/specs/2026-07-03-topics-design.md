# Topics — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

The middle browse level: chapter → topics-in-chapter → Reader. Each topic row
carries an aggregate recall pip (label + color, never color alone — D20 a11y).

## UI (top → bottom)

- Topbar: back button (→ Syllabus) + title `Airway Management`.
- Breadcrumb: `Anaesthesia` (tappable, → Syllabus) `›`
  `Airway Management · 14 topics` (leaf, non-interactive).
- Chapter progress block: `Chapter recall` / `8 of 14 recalled`, bar at 57 %.
- **Topic rows** (title · meta · pip state · when-label) — demo subset, 8 of
  the 14:
  1. `Airway anatomy & landmarks` · `3 model answers · 14 marks` · good · `in 6 days`
  2. `Assessing the difficult airway` · `2 answers · 10 marks` · good · `in 4 days`
  3. `Rapid sequence induction` · `2 answers · 10 marks` · due · `Due today`
  4. `Difficult airway algorithm (DAS)` · `1 answer · 10 marks` · due · `Due today`
  5. `Supraglottic airway devices` · `2 answers · 8 marks` · good · `in 3 days`
  6. `Videolaryngoscopy` · `1 answer · 6 marks` · good · `in 5 days`
  7. `Awake fibreoptic intubation` · `1 answer · 10 marks` · new · `New`
  8. `Cricothyroidotomy / front-of-neck` · `1 answer · 8 marks` · new · `New`
- Pip colors: good = green, due = amber, new = neutral — always with the text
  label.
- Footer microcopy: `Each topic is one recall unit — open it to hide, attempt,
then reveal the model answer. Due topics surface automatically in Home.`
- Bottom nav: **Syllabus tab stays active** (Topics is part of the syllabus
  stack, not a nav destination).

## Behaviors

- Every topic row → Reader (`data-go="reader"`); crumb ancestor `Anaesthesia`
  → Syllabus.

## Verify (manual, preview server)

1. Back button and crumb ancestor both return to Syllabus; Syllabus tab stays
   lit on this screen.
2. Due rows show amber pip + `Due today`; new rows show `New`; none rely on
   color alone.
3. Any row opens the Reader at pre-reveal.
