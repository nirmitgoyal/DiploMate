# Design System — DiploMate

> **The one memorable thing:** _"It made me recall, not reread."_
> Every token, screen, and word below serves that sentence. When two design
> choices conflict, the one that pushes the user to actively recall (not
> passively read) wins. This is the tiebreaker for all future arguments.

Source of truth for all visual and UI decisions. Read this before writing any
UI code. It codifies `prototype/index.html` (Direction B · Clinical Chart), the
locked plan decisions D13–D20, the 2026-07-03 cross-model design review, and a
category research pass (Anki, AMBOSS, Readwise, PrepLadder).

---

## Product Context

- **What this is:** A mobile study app that turns DNB (Diplomate of National
  Board) previous-year theory-exam model answers into an active-recall loop:
  browse the syllabus pyramid → read a model answer → hide, attempt, reveal →
  rate confidence → spaced-repetition queue.
- **Who it's for:** Final-year DNB **Anaesthesia** residents, theory exam
  < 6 months out, in panic mode. Study at 2am, on call, one-handed.
- **Space/industry:** Indian medical exam prep. Peers: Marrow, PrepLadder,
  DAMS (MCQ + video, wrong exam format), Anki (SRS mechanic), AMBOSS (clinical
  reference). The content is the moat; the app is a reader over it.
- **Project type:** Native mobile app (Flutter, Android first). Offline-first
  reading surface + spaced-repetition scheduler. **Not** a marketing site,
  **not** a dashboard.

---

## Aesthetic Direction

- **Direction:** **Clinical Editorial** — an annotated answer book, not an
  edtech dashboard. A paper-like reading surface with restrained medical
  precision.
- **Decoration level:** **Minimal** — hierarchy comes from typography, spacing,
  and hairline rules. No cards, no gamification, no celebration confetti, no
  decorative shadows, no illustration.
- **Mood:** Calm, adult, exact. The register of a well-set textbook and a
  hospital chart. It should feel like serious software for the most important
  six months of a doctor's training — and never like a habit app cheering you on.
- **Reference points (what we deliberately are / are not):**
  - **Anki** — borrow the Again/Hard/Good rating mechanic; reject its raw,
    unstyled surface.
  - **AMBOSS** — borrow clinical-teal as the trust signal; reject its
    testimonial-heavy marketing skin.
  - **Readwise Reader / iA Writer** — borrow reading-surface craft and editorial
    calm; reject Reader's purple gradient hero (banned below).
  - **PrepLadder / Marrow** — the category norm we depart from: card grids,
    blue-gradient heroes, motivational-quote habit-app patterns, "Voices of
    Success" testimonial walls. DiploMate looks like none of it.

### The memorable thing, operationalized

The design must be remembered for **making the user recall** — so:

- The queue comes before the content (queue-first Home).
- The reveal is a physical event, not a content swap (see _Signature moves_).
- The answer is structured like a marked exam script (examiner's margin).
- No streaks, no confetti, no quote-of-the-day. The reward is the answer itself.

---

## Signature Moves (the two deliberate risks — protect these)

These are where DiploMate stops being a coherent-but-generic clinical app and
gets its own face. Do not sand them off in the name of consistency.

1. **The reveal changes the paper.** Model answers — and _only_ model answers —
   render on pure white (`--elevated #FFFFFF`) with a hard hairline
   (`--rule-strong`) at the seam. Every other surface (Home, Syllabus, Topics)
   sits on grey chart-paper (`--paper #F6F8FA`). White is the **material code
   for a model answer**, the way graph paper means chart. Pre-reveal question =
   grey worksheet; post-reveal answer = white answer sheet. The reveal is felt,
   not just seen. Implemented as `.answer { background: var(--elevated); border-top: 1px solid var(--rule-strong) }`.

2. **The examiner's red margin.** The revealed answer carries a 26px hanging
   left margin with a continuous vertical hairline. Each section's **mark
   weight** sits in that margin as a red tabular numeral (`--exam-red`, Manrope
   700, 11px). In Indian exam culture, red pen = examiner; the answer reads as a
   marked script. This replaces the old `01/02` Manrope section numerals. Red is
   reserved: it annotates marks and flags errors, nothing else.
   - **Note:** margin numerals are **per-section weights**, not a re-total of
     the full breakdown. The `.earn` "What earns marks" table above the answer
     remains the authoritative mark breakdown (sums to the paper total).
   - **Deferred (post-beta A/B):** the "pre-reveal skeleton" (showing section
     heads with bodies hidden so the user recalls _into_ the structure). It may
     strengthen recall, but it also changes what the recall test measures, so it
     ships as a measured experiment keyed to recall-quality data, not a v1
     default. Until then, pre-reveal shows the question + a plain attempt prompt.

---

## Typography

Two families, loaded via `google_fonts` (Flutter) / Google Fonts CDN (web).

- **Reading body — Source Serif 4.** Questions and answer prose. The serif is
  the product's voice: it says "textbook," not "app." Optical-size axis in use.
- **UI / labels / metadata / controls — Manrope.** Nav, overlines, chips,
  counts, buttons. A neutral geometric sans that stays quiet behind the serif.
- **Data / counts — Manrope with `tabular-nums`.** All numerals that change
  (due counts, mark weights, intervals, `n/N` search matches)
  render tabular so they don't jitter. `font-variant-numeric: tabular-nums` is
  the default for every count in the app.
- **Code:** none in-product. If ever needed (debug), JetBrains Mono.

### Type scale (fixed — do not add sizes)

The prototype drifted to ~22 ad-hoc sizes. This is the law. Every text element
maps to one of these steps. `sp` on device (respects system text scale).

| Token     | Size   | Family / weight      | Used for                                            |
| --------- | ------ | -------------------- | --------------------------------------------------- |
| `display` | 28px   | Serif 600            | Home title (`.tt.big`), sign-in wordmark            |
| `title`   | 24px   | Serif 600            | Screen titles (`.tt`), the **question** (`.qtxt`)   |
| `section` | 19px   | Serif 600            | Answer section heads (`.ah`)                        |
| `body`    | 17px   | Serif 400 / 1.55–1.6 | Answer prose + list items (`.asec p`, `.asec li`)   |
| `body-ui` | 15px   | Manrope 600          | Row titles (`.t1`), CTA labels                      |
| `meta`    | 12.5px | Manrope 500–600      | Row subtitles (`.t2`), breadcrumb, secondary meta   |
| `label`   | 11px   | Manrope 700, caps    | Overlines (`.ovl`), mark numerals, pips, nav labels |

Rules:

- **Body is 17px minimum** (D16). Must survive system `textScale 1.3` without
  breaking layout. No answer text below 17px.
- **Section heads (19px) are larger than the body (17px) they head.** Never
  invert this. (The prototype had 14px heads over 15.5px body — fixed.)
- **Answer prose is one size (17px).** Paragraphs and bullet lists at the same
  semantic level share size _and_ leading. No 15.5/14.5 split.
- **Overline tracking is one value: `0.14em`.** Not .08/.1/.16 scattered.
- **The question is the object.** `.qtxt` at 24px serif 600, line-height 1.4.
  Never let it shrink toward body size.

---

## Color

Two themes ship in v1 (D20): **Clinical Chart** (light, default) and **Night
Desk** (dark — this persona studies at 2am). Same product, one token set,
swapped values. Tokens are semantic, never raw hex, at call sites.

### Approach

**Restrained.** One accent (medical teal) + a warm-cool neutral ink ramp +
three reserved semantic colors. Color is rare and meaningful. No purple, no
gradient fills, no decorative color.

### Light — Clinical Chart (`.dir-b`, default)

| Token           | Hex       | Role                                                       |
| --------------- | --------- | ---------------------------------------------------------- |
| `--paper`       | `#F6F8FA` | App background (grey chart-paper — the worksheet surface)  |
| `--elevated`    | `#FFFFFF` | **Model-answer surface only** + diagram plates + inputs    |
| `--sunk`        | `#EDF1F5` | Row hover, inset chips                                     |
| `--ink`         | `#0E1626` | Primary text (17:1 on paper)                               |
| `--ink-2`       | `#57657A` | Secondary text / answer prose (5.6:1)                      |
| `--ink-3`       | `#5F6F84` | Muted labels, metadata (**4.8:1** — was `#8A97A8`, failed) |
| `--rule`        | `#E1E7EE` | Hairline dividers                                          |
| `--rule-strong` | `#CFD8E2` | Answer seam, input borders, tray top                       |
| `--teal`        | `#087A72` | **Fills & icons only** (white-on-teal CTA = 5.2:1)         |
| `--teal-ink`    | `#0A6E67` | **Teal used as text** (overlines, active nav) — 5.7:1      |
| `--amber`       | `#A85B10` | Due / overdue emphasis (4.7:1)                             |
| `--exam-red`    | `#B4271F` | Examiner margin marks + errors only (6.1:1)                |
| `--ok`          | `#1E7A46` | "rated Good" positive stat (5.0:1)                         |

### Dark — Night Desk (`.dir-c`)

| Token        | Hex       | Role                                                                                 |
| ------------ | --------- | ------------------------------------------------------------------------------------ |
| `--paper`    | `#19181A` | App background (warm near-black)                                                     |
| `--elevated` | `#211F22` | Answer / plate surface                                                               |
| `--ink`      | `#ECE6DC` | Primary text (14:1)                                                                  |
| `--ink-2`    | `#9C9488` | Secondary / prose (5.9:1)                                                            |
| `--ink-3`    | `#908878` | Muted (**5.0:1 paper / 4.7:1 elevated** — `#8A8275` failed AA on the answer surface) |
| `--teal`     | `#3ED8C4` | Fills & icons (dark CTA text `#0C1413` on it = 10.5:1)                               |
| `--teal-ink` | `#8CEBDD` | Teal-as-text (12.7:1)                                                                |
| `--amber`    | `#F2B44C` | Due / overdue (9.6:1)                                                                |
| `--exam-red` | `#F08A82` | Examiner marks / errors                                                              |

### Color laws (enforced — these are the D20 lock, corrected)

1. **`--teal` is for fills and strokes; `--teal-ink` is for text.** The raw
   teal (`#087A72`, 3.7:1 as the old `#0D8F86`) fails AA as small text. Any
   teal-colored _text_ — overlines, active nav labels, links — uses `--teal-ink`.
   The prototype violated this (`.dir-b .ovl`, `.nav .on`); it is now fixed and
   is law. Dark mode inherits the same rule.
2. **`--ink-3` passes 4.5:1** on its surface, because it is used for the
   _smallest_ text in the app (10.5–12px overlines, pips, nav, footnotes).
   Never re-introduce a muted grey that fails AA for text.
3. **Body contrast ≥ 4.5:1** everywhere (D20). Verified for every ramp step above.
4. **Color is never the only signal** (D20, a11y). Recall pips, download states,
   and rating buttons all carry a label or icon/shape in addition to color.
   "Due today" is amber _and_ says "Due today."
5. **Red is reserved.** `--exam-red` annotates mark weights and flags errors.
   It never decorates, never themes a section, never marks "danger" on
   non-error content. The `Again` (unable-to-recall) rating uses a full-strength
   red border — because failing to recall _is_ the signal, not a muted footnote.
6. **No purple, no gradient fills, no decorative shadows.** (Anti-slop + D20.)

---

## Spacing

- **Base unit:** 4px grid. Every padding/margin is a multiple of 4 (occasional
  2px hairline offsets excepted).
- **Density:** Comfortable-clinical. Roomy enough to read a long answer without
  fatigue; tight enough that the queue feels like a worklist, not a poster.
- **Gutter:** **18px** — the single horizontal screen gutter. One value.
  (Sign-in's old 26px and the sheet's 20px were drift; standardize to 18px
  except the paywall sheet's own inset.)
- **Scale:** `2xs(2) xs(4) sm(8) md(12) lg(16) xl(18-gutter) 2xl(24) 3xl(32)`.
- **Topbar bottom padding is one value (8px).** The prototype had 12/6/4 via
  inline overrides — do not reintroduce per-screen topbar paddings.
- **Examiner margin:** answer sections indent **26px** with the margin rail at
  19px; diagram plates share the 26px indent so figures align to the text column.

---

## Layout

- **Approach:** **List-and-rule, grid-disciplined.** Rows separated by hairline
  rules. Sections separated by space and overlines. **No cards** (D-review lock).
- **The no-cards boundary (explicit, so the law survives contact):**
  - **Forbidden:** chapter cards, topic cards, card-wrapped answers, stat cards,
    tinted "callout" boxes for informational content. Information lives in
    rows, sections, and prose — never in a floating rounded container.
  - **Allowed (named exceptions):** **buttons** (bounded by definition),
    **diagram plates** (`.diagram` — a framed figure is a plate, like a textbook
    plate), the **paywall sheet** (a modal surface, not content), and **inputs**.
    Nothing else gets a border + radius + fill.
  - The old tinted `.prompt` callout was a card in disguise — it is now a plain
    icon + line, no fill, no border.
- **Bottom navigation: three tabs — Home · Syllabus · Account** (Manrope 11px
  labels; active = `--teal-ink`). This **supersedes** D13's four-tab spec
  (Today · Syllabus · Downloads · Account): Downloads is no surface at all —
  no tab, no screen, no Account row (struck 2026-07-03; offline state appears
  inline on syllabus rows, "offline ✓") — and Topics/Bookmarks are stack
  children of their parent tab (Topics under Syllabus, Bookmarks under Home) —
  a child screen lights its parent tab. The Reader has **no** bottom nav (full
  focus on recall).
- **Thumb zone:** every primary loop action (Reveal, the rating tray, Continue,
  Start recall) lives in the bottom 25% of the screen for one-handed hospital
  use (D20).
- **Border radius:** used sparingly, only where containment is real.
  `sm 8px` (chips, lozenges, inputs), `md 12px` (buttons, diagram plates,
  sheet corners). No radius on rows or content. Never "bubble-radius everything."
- **Max readable measure:** answer prose caps its line length; never full-bleed
  17px serif across a tablet width.

---

## Motion

- **Approach:** **Minimal-functional.** Motion only where it aids comprehension
  of a state change. No entrance choreography, no scroll-driven effects, no
  playful bounce. (D20 motion budget.)
- **The three sanctioned motions (D20):**
  1. **Answer reveal** — brief vertical uncover, 150–220ms, scroll position
     preserved. This is the one "event" motion; it earns its keep by making the
     grey→white material change feel physical.
  2. **Rating acknowledgement** — the "Back today / Next in 3 days" toast, then
     auto-advance to the next due QnA.
  3. **Queue transition** — moving to the next card.
- **Easing:** enter `ease-out`, exit `ease-in`, move `ease-in-out`.
- **Duration:** micro 50–100ms (taps), short 150–250ms (reveal, toast),
  medium 250–400ms (sheet). Nothing longer.
- **`prefers-reduced-motion` / TalkBack:** all motion disabled under
  reduced-motion; the reveal becomes an instant state swap. Non-negotiable (D20).

---

## Copy Voice

The words are part of the clinical-editorial register. Utility language, calm,
adult, exact. The serif is doing the "textbook" work; the copy must not undercut
it with app-speak or motivational filler.

- **Say the true noun.** The queue is **"due"** everywhere — Topics says "Due
  today," Reader says "10 due." (Home's CTA keeps the founder-locked "suggested"
  framing — "View 12 suggested answers" — because that framing is a deliberate
  product choice: the queue reads as guidance, not homework. "Suggested" and
  "due" both stay, each in its lane. Never invent a third word.)
- **Count honest things.** "This Week" shows "41 answers recalled" and "71%
  rated Good" — real recall data. **Never a streak.** ("6 day streak-free" is
  banned: it is a streak wearing an anti-gamification fig leaf.)
- **No app-speak in editorial slots.** "answers," not "QnAs," in user-facing
  copy. "QnA" is the internal data-model term (D14) and stays out of the UI.
- **Never expose the plumbing.** No "checksum," "bundle," "atomic swap," "RLS,"
  "entitlement" in user copy. Downloads say "Available offline," "Update
  available," "Download failed — retry."
- **Labels don't lie.** If a gesture isn't wired, don't label it. Inline
  diagrams say "Tap to enlarge" (they open the fullscreen viewer); only the
  fullscreen viewer says "Pinch … to zoom," because only it has the gesture.
- **Empty states carry direction, not apology** (D13 first-run funnel):
  "Nothing scheduled yet. Study one answer to start your recall queue." /
  "Today's recall is complete. 8 reviewed; next due tomorrow."
- **Store-compliance copy is exact.** The paywall restore affordance is
  **"Restore purchase"** (store requirement), a distinct slot from any support
  contact. Delete/Privacy/Terms lines present where policy requires (sign-in,
  Account).

---

## Screen Anatomy (canonical layouts)

Nine screens + one sheet. Reference `prototype/index.html`.

1. **Sign-in** — wordmark → serif lede ("Master DNB theory answers by recalling
   them, not rereading them") → **content specimen** (a cropped real model
   answer with fade-out — the one visual proof of what you're buying; never ship
   sign-in without it) → "Continue with Google" (sole auth, D5) → utility line
   (sync note + Terms/Privacy). No splash, no carousel, no stock doctor photo.
2. **Speciality onboarding** — mandatory, unskippable (D13). 61 DNB/DrNB tracks,
   grouped, single-select radio, substring search with highlight + result count,
   Enter = pick top match. Continue disabled until one is chosen. Shown once;
   changeable **once** later from Account.
3. **Home** — queue-first. Top matter is the greeting ("Good morning, Ananya,"
   name in `--teal-ink`) → primary CTA "View N suggested answers" (**hidden
   entirely when N = 0** — no empty or disabled CTA; the ghost "View your
   bookmarks" drops its top margin to close the gap) → ghost CTA "View your
   bookmarks" → "This Week" (two honest stats) → **pinned resume row** (sticky
   above the nav, never scrolls away). No countdown, no epigraph — both struck
   (see Decisions Log 2026-07-03).
4. **Syllabus** — chapter rows: title, topic count, offline note in the subtitle,
   and **recall progress as the loud right-side signal** ("8/14 recalled" in
   `--teal-ink`) — recall is the data, offline is a footnote. Locked chapters
   stay visible (title + count, never answer previews); one lock signal, not
   three.
5. **Topics** — chapter → topic rows, each with an aggregate recall pip
   (Due today / in N days / New — label + color, never color alone). Chapter
   recall progress bar at top. Lights the **Syllabus** tab (stack child).
6. **Reader / Recall** — one surface, two states:
   - **Before:** question (24px serif) + year + marks; a plain attempt prompt
     (pen icon + one line, no card); Reveal Answer full-width in the thumb zone.
     No countdown, no hard lock — the ≥10s validity rule (D9) stays invisible.
   - **After:** answer renders on **white** with the **examiner's red margin**
     (per-section mark weights). Anatomy: "What earns marks" outline → numbered
     serif sections → full-width diagram plate (with fullscreen viewer) →
     summary → rating tray. **Rating tray is in-flow**, last thing in the
     answer (Again · Hard · Good, fixed order, interval hints, icon+label)
     with a "N done · M due" counter (D15 reversed — see Decisions Log).
     In-answer fuzzy search appears
     **only after reveal** (never leaks answers). Diagram reproduction practice
     is post-v1 (D15).
7. **Account** — identity → Exam speciality (one-time change) → daily
   reminder → sign out → delete account (Play mandate).
8. **Bookmarks** — saved questions as rows (question + `Chapter · Topic` source),
   reached from Home, lights the Home tab.
9. **Paywall sheet** — locked contents (titles + counts, never previews) →
   exact price (₹499 one-time) → what's included → **Purchase** → **Restore
   purchase** (compliance) + one support line. No UPI explainer in the sheet
   (beta payment mechanics live in the ops runbook, not the design).

---

## Accessibility (D20 — non-negotiable)

- 48dp minimum touch targets; primary loop actions in the bottom 25% thumb zone.
- Body contrast ≥ 4.5:1 (verified for every token pair above).
- Color never the sole signal (labels/icons/shapes accompany every state color).
- TalkBack semantic order; diagram content descriptions on every figure.
- Survives system `textScale 1.3` without layout breakage.
- `prefers-reduced-motion` disables all motion (reveal → instant swap).

---

## Decisions Log

| Date       | Decision                                                                                                                                                                                | Rationale                                                                                                                                 |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-07-03 | Initial DESIGN.md created from prototype + plan D13–D20 + cross-model review + category research                                                                                        | `/design-consultation`                                                                                                                    |
| 2026-07-03 | `--ink-3` light `#8A97A8`→`#5F6F84`, dark `#6E675C`→`#8A8275`; `--teal` `#0D8F86`→`#087A72`                                                                                             | Old values failed the D20 4.5:1 body-contrast lock (2.8/3.2/3.97:1); corrected to pass. Verified WCAG.                                    |
| 2026-07-03 | Teal-for-fills / teal-ink-for-text made law                                                                                                                                             | Raw teal fails AA as small text; splits the token so overlines + active nav stay legible in both themes                                   |
| 2026-07-03 | Fixed 7-step type scale replaces ~22 ad-hoc sizes; body locked at 17px; section heads (19px) > body                                                                                     | Prototype drift; D16 readability; hierarchy inversion in the reading surface                                                              |
| 2026-07-03 | Bottom nav 3 tabs (Home · Syllabus · Account); Downloads → Account row                                                                                                                  | Supersedes D13 four-tab spec; matches built prototype                                                                                     |
| 2026-07-03 | Risk adopted: model answers render on white (`--elevated`) as material code                                                                                                             | Cheap distinctive move; makes the reveal a physical event; serves "recall, not reread"                                                    |
| 2026-07-03 | Risk adopted: examiner's red margin (per-section mark weights) replaces `01/02` numerals                                                                                                | Culturally exact (red pen = examiner); answer reads as a marked script                                                                    |
| 2026-07-03 | Home top matter = exam countdown, replacing the epigraph/quote                                                                                                                          | Persona-exact (days-remaining is the finalist's cosmology); kills the habit-app quote-first pattern; supersedes prior epigraph refinement |
| 2026-07-03 | Pre-reveal skeleton deferred to a post-beta A/B                                                                                                                                         | It changes what the recall metric measures; ship as a measured experiment, not a v1 guess                                                 |
| 2026-07-03 | Rating tray pinned to bottom (was in-flow)                                                                                                                                              | In-flow tray forced scrolling back through the answer — the exact reread the product forbids (D15)                                        |
| 2026-07-03 | Copy fixes: "streak-free"→"answers recalled"; "QnAs"→"answers"; nav "Ananya"→"Account"; false "Pinch to zoom"→"Tap to enlarge"; TAP block filed under Regional Anaesthesia (not Airway) | Register discipline + a content-taxonomy credibility bug in the demo data                                                                 |
| 2026-07-03 | D15 reversed: rating tray back to in-flow (was pinned bottom)                                                                                                                           | Explicit user call, made aware of the reread tradeoff D15 documented                                                                      |
| 2026-07-03 | Struck: Home exam-countdown top matter (Home opens at the greeting) and Account "Downloads & storage" row (no Downloads surface; offline state stays inline on syllabus rows)           | Founder call — prototype stands as built; all five sync-3 flagged items discarded                                                         |
