# Design System - DiploMate

> **The one memorable thing:** _"It made me recall, not reread."_
> Every token, screen, and word below serves that sentence. When two design
> choices conflict, the one that pushes the user to actively recall (not
> passively read) wins. This is the tiebreaker for all future arguments.

Source of truth for all visual and UI decisions. Read this before writing any
UI code. It codifies `prototype/index.html` (Direction B · Clinical Chart), the
locked plan decisions D13-D20, the 2026-07-03 cross-model design review, and a
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
- **Project type:** Native mobile app (Flutter, Android first). On-demand
  reading surface + spaced-repetition scheduler; content loads from the API as
  needed (no offline Downloads feature - founder call 2026-07-04; device
  caching is transparent and never promised in UI). **Not** a marketing site,
  **not** a dashboard.

---

## Aesthetic Direction

- **Direction:** **Clinical Editorial** - an annotated answer book, not an
  edtech dashboard. A paper-like reading surface with restrained medical
  precision.
- **Decoration level:** **Minimal** - hierarchy comes from typography, spacing,
  and hairline rules. No cards, no gamification, no celebration confetti, no
  decorative shadows, no illustration.
- **Mood:** Calm, adult, exact. The register of a well-set textbook and a
  hospital chart. It should feel like serious software for the most important
  six months of a doctor's training - and never like a habit app cheering you on.
- **Reference points (what we deliberately are / are not):**
  - **Anki** - borrow the 3-tier self-rating mechanic (relabelled Easy/Medium/Hard); reject its raw,
    unstyled surface.
  - **AMBOSS** - borrow clinical-teal as the trust signal; reject its
    testimonial-heavy marketing skin.
  - **Readwise Reader / iA Writer** - borrow reading-surface craft and editorial
    calm; reject Reader's purple gradient hero (banned below).
  - **PrepLadder / Marrow** - the category norm we depart from: card grids,
    blue-gradient heroes, motivational-quote habit-app patterns, "Voices of
    Success" testimonial walls. DiploMate looks like none of it.

### The memorable thing, operationalized

The design must be remembered for **making the user recall** - so:

- The queue comes before the content (queue-first Home).
- The reveal is a physical event, not a content swap (see _Signature moves_).
- The answer is structured like a marked exam script (examiner's margin).
- No streaks, no confetti, no quote-of-the-day. The reward is the answer itself.

---

## Signature Moves (the two deliberate risks - protect these)

These are where DiploMate stops being a coherent-but-generic clinical app and
gets its own face. Do not sand them off in the name of consistency.

1. **The reveal changes the paper.** Model answers - and _only_ model answers -
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

- **Reading body - Source Serif 4.** Questions and answer prose. The serif is
  the product's voice: it says "textbook," not "app." Optical-size axis in use.
- **UI / labels / metadata / controls - Manrope.** Nav, overlines, chips,
  counts, buttons. A neutral geometric sans that stays quiet behind the serif.
- **Data / counts - Manrope with `tabular-nums`.** All numerals that change
  (mark weights, marks, stat counts, `n/N` search matches)
  render tabular so they don't jitter. `font-variant-numeric: tabular-nums` is
  the default for every count in the app. The Home "This Week" stat numerals
  are the one large-count slot: Manrope 700 at 24px (data voice, not serif).
- **Code:** none in-product. If ever needed (debug), JetBrains Mono.

### Type scale (fixed - do not add sizes)

The prototype drifted to ~22 ad-hoc sizes. This is the law. Every text element
maps to one of these steps. `sp` on device (respects system text scale).

| Token     | Size   | Family / weight      | Used for                                            |
| --------- | ------ | -------------------- | --------------------------------------------------- |
| `display` | 28px   | Serif 600            | Home title (`.tt.big`), sign-in wordmark            |
| `title`   | 24px   | Serif 600            | Screen titles (`.tt`), the **question** (`.qtxt`)   |
| `section` | 19px   | Serif 600            | Answer section heads (`.ah`)                        |
| `body`    | 17px   | Serif 400 / 1.55-1.6 | Answer prose + list items (`.asec p`, `.asec li`)   |
| `body-ui` | 15px   | Manrope 600          | Row titles (`.t1`), CTA labels                      |
| `meta`    | 12.5px | Manrope 500-600      | Row subtitles (`.t2`), breadcrumb, secondary meta   |
| `label`   | 11px   | Manrope 700, caps    | Overlines (`.ovl`), mark numerals, pips, nav labels |

Rules:

- **Body is 17px minimum** (D16). Must survive system `textScale 1.3` without
  breaking layout. No answer text below 17px.
- **Section heads (19px) are larger than the body (17px) they head.** Never
  invert this. (The prototype had 14px heads over 15.5px body - fixed.)
- **Answer prose is one size (17px).** Paragraphs and bullet lists at the same
  semantic level share size _and_ leading. No 15.5/14.5 split.
- **Overline tracking is one value: `0.14em`.** Not .08/.1/.16 scattered.
- **The question is the object.** `.qtxt` at 24px serif 600, line-height 1.4.
  Never let it shrink toward body size.

---

## Color

Two themes ship in v1 (D20): **Clinical Chart** (light, default) and **Night
Desk** (dark - this persona studies at 2am). Same product, one token set,
swapped values. Tokens are semantic, never raw hex, at call sites.

### Approach

**Restrained.** One accent (medical teal) + a warm-cool neutral ink ramp +
three reserved semantic colors. Color is rare and meaningful. No purple, no
gradient fills, no decorative color.

### Light - Clinical Chart (`.dir-b`, default)

| Token           | Hex                                      | Role                                                       |
| --------------- | ---------------------------------------- | ---------------------------------------------------------- |
| `--paper`       | `#F6F8FA`                                | App background (grey chart-paper - the worksheet surface)  |
| `--elevated`    | `#FFFFFF`                                | **Model-answer surface only** + diagram plates + inputs    |
| `--sunk`        | `#EDF1F5`                                | Row hover, inset chips                                     |
| `--ink`         | `#0E1626`                                | Primary text (17:1 on paper)                               |
| `--ink-2`       | `#57657A`                                | Secondary text / answer prose (5.6:1)                      |
| `--ink-3`       | `#5F6F84`                                | Muted labels, metadata (**4.8:1** - was `#8A97A8`, failed) |
| `--rule`        | `#E1E7EE`                                | Hairline dividers                                          |
| `--rule-strong` | `#CFD8E2`                                | Answer seam, input borders, tray top                       |
| `--teal`        | `#087A72`                                | **Fills & icons only** (white-on-teal CTA = 5.2:1)         |
| `--teal-ink`    | `#0A6E67`                                | **Teal used as text** (overlines, active nav) - 5.7:1      |
| `--amber`       | `#A85B10`                                | Medium rating tier + "Due" status (4.7:1)                  |
| `--exam-red`    | `#B4271F`                                | Examiner marks, errors, + Hard tier (6.1:1)                |
| `--ok`          | `#1E7A46`                                | Easy tier + "rated Easy" stat (5.0:1)                      |
| `--teal-soft`   | `#087A72` at 8% alpha (`#14087A72` ARGB) | Tint fills behind teal chips/marks (never text)            |
| `--amber-soft`  | `#A85B10` at 7% alpha (`#12A85B10` ARGB) | Tint fill behind the active search match                   |
| `--nav-bg`      | `#FBFCFD`                                | Bottom-nav surface                                         |
| `--nav-rule`    | `#E4EAF0`                                | Bottom-nav top hairline                                    |
| `--danger`      | alias of `--exam-red`                    | One red, one source                                        |

### Dark - Night Desk (`.dir-c`)

| Token           | Hex                                      | Role                                                                                 |
| --------------- | ---------------------------------------- | ------------------------------------------------------------------------------------ |
| `--paper`       | `#19181A`                                | App background (warm near-black)                                                     |
| `--elevated`    | `#211F22`                                | Answer / plate surface                                                               |
| `--ink`         | `#ECE6DC`                                | Primary text (14:1)                                                                  |
| `--ink-2`       | `#9C9488`                                | Secondary / prose (5.9:1)                                                            |
| `--ink-3`       | `#908878`                                | Muted (**5.0:1 paper / 4.7:1 elevated** - `#8A8275` failed AA on the answer surface) |
| `--teal`        | `#3ED8C4`                                | Fills & icons (dark CTA text `#0C1413` on it = 10.5:1)                               |
| `--teal-ink`    | `#8CEBDD`                                | Teal-as-text (12.7:1)                                                                |
| `--amber`       | `#F2B44C`                                | Medium rating tier + "Due" status (9.6:1)                                            |
| `--exam-red`    | `#F08A82`                                | Examiner marks / errors + Hard tier                                                  |
| `--sunk`        | `#141315`                                | Row hover, inset chips                                                               |
| `--rule`        | `#302D31`                                | Hairline dividers                                                                    |
| `--rule-strong` | `#3E3A3F`                                | Answer seam, input borders                                                           |
| `--ok`          | `#5FCF8A`                                | Easy tier + "rated Easy" stat                                                        |
| `--teal-soft`   | `#3ED8C4` at 9% alpha (`#183ED8C4` ARGB) | Tint fills (never text)                                                              |
| `--amber-soft`  | `#F2B44C` at 8% alpha (`#14F2B44C` ARGB) | Active search match tint                                                             |
| `--nav-bg`      | `#141315`                                | Bottom-nav surface                                                                   |
| `--nav-rule`    | `#2A282C`                                | Bottom-nav top hairline                                                              |
| `--danger`      | alias of `--exam-red`                    | One red, one source                                                                  |

### Color laws (enforced - these are the D20 lock, corrected)

1. **`--teal` is for fills and strokes; `--teal-ink` is for text.** The raw
   teal (`#087A72`, 3.7:1 as the old `#0D8F86`) fails AA as small text. Any
   teal-colored _text_ - overlines, active nav labels, links - uses `--teal-ink`.
   The prototype violated this (`.dir-b .ovl`, `.nav .on`); it is now fixed and
   is law. Dark mode inherits the same rule.
2. **`--ink-3` passes 4.5:1** on its surface, because it is used for the
   _smallest_ text in the app (10.5-12px overlines, pips, nav, footnotes).
   Never re-introduce a muted grey that fails AA for text.
3. **Body contrast ≥ 4.5:1** everywhere (D20). Verified for every ramp step above.
4. **Color is never the only signal** (D20, a11y). Recall pips and rating
   buttons all carry a label or icon/shape in addition to color.
   The rating tiers are green/amber/red _and_ carry a face icon + word
   (Easy · Medium · Hard); the Topics "Due" pip is amber _and_ says "Due."
5. **Red is reserved - one relaxation (2026-07-04).** `--exam-red` annotates
   mark weights and flags errors; it never themes an arbitrary section. Beyond
   marks/errors, two sanctioned uses: the Account **"Delete account"** row
   (irreversible destructive action), and - new - the **Hard** rating tier, the
   red end of a green→amber→red recall scale (`Easy` = `--ok`, `Medium` =
   `--amber`, `Hard` = `--exam-red`). The traffic-light rating supersedes the
   former rule that red signalled only failure/destruction. `--danger` aliases
   `--exam-red` - one red, one source.
6. **No purple, no gradient fills, no decorative shadows.** (Anti-slop + D20.)

---

## Spacing

- **Base unit:** 4px grid. Every padding/margin is a multiple of 4 (occasional
  2px hairline offsets excepted).
- **Density:** Comfortable-clinical. Roomy enough to read a long answer without
  fatigue; tight enough that the queue feels like a worklist, not a poster.
- **Gutter:** **18px** - the single horizontal screen gutter. One value.
  (Sign-in's old 26px and the sheet's 20px were drift; standardize to 18px
  except the paywall sheet's own inset.)
- **Scale:** `2xs(2) xs(4) sm(8) md(12) lg(16) xl(18-gutter) 2xl(24) 3xl(32)`.
- **Topbar bottom padding is one value (8px).** The prototype had 12/6/4 via
  inline overrides - do not reintroduce per-screen topbar paddings.
- **Examiner margin:** answer sections indent **26px** with the margin rail at
  19px; diagram plates share the 26px indent so figures align to the text column.

---

## Layout

- **Approach:** **List-and-rule, grid-disciplined.** Rows separated by hairline
  rules. Sections separated by space and overlines. **No cards** (D-review lock).
- **The no-cards boundary (explicit, so the law survives contact):**
  - **Forbidden:** chapter cards, topic cards, card-wrapped answers, stat cards,
    tinted "callout" boxes for informational content. Information lives in
    rows, sections, and prose - never in a floating rounded container.
  - **Allowed (named exceptions):** **buttons** (bounded by definition),
    **diagram plates** (`.diagram` - a framed figure is a plate, like a textbook
    plate), the **paywall sheet** (a modal surface, not content), **inputs**,
    the **sign-in content specimen** (`.specimen` - a cropped model answer;
    white is its material code and the frame is a plate, per anatomy #1), and
    the **transient toast** (`.ack` - feedback, not content).
    Nothing else gets a border + radius + fill.
  - The old tinted `.prompt` callout was a card in disguise - it is now a plain
    icon + line, no fill, no border.
- **Bottom navigation: three tabs - Home · Syllabus · Account** (Manrope 11px
  labels; active = `--teal-ink`). This **supersedes** D13's four-tab spec
  (Today · Syllabus · Downloads · Account): Downloads is no surface at all -
  no tab, no screen, no Account row (struck 2026-07-03; since 2026-07-04 there
  is NO offline/download state anywhere - not even inline on syllabus rows;
  content loads on demand) - and Bookmarks is a stack
  child of its parent tab (Bookmarks under Home) -
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
  1. **Answer reveal** - brief vertical uncover, 150-220ms, scroll position
     preserved.
     (Law, landed + test-enforced 2026-07-05 (design T7). The prototype
     clamps scroll-to-top on reveal - a demo limitation, not the spec; the
     app preserves the reading position.)
     This is the one "event" motion; it earns its keep by making the
     grey→white material change feel physical.
  2. **Rating acknowledgement** - the "Rated Easy · next answer" toast, then
     auto-advance to the next QnA.
  3. **Queue transition** - moving to the next card.
- **Easing:** enter `ease-out`, exit `ease-in`, move `ease-in-out`.
- **Duration:** micro 50-100ms (taps), short 150-250ms (reveal, toast),
  medium 250-400ms (sheet). Nothing longer.
- **`prefers-reduced-motion` / TalkBack:** all motion disabled under
  reduced-motion; the reveal becomes an instant state swap. Non-negotiable (D20).

---

## Copy Voice

The words are part of the clinical-editorial register. Utility language, calm,
adult, exact. The serif is doing the "textbook" work; the copy must not undercut
it with app-speak or motivational filler.

- **Brand strap.** Sign-in carries one tagline under the wordmark: **"Written by
  Doctors. Solved for Success!"** (teal small-caps) - the single permitted
  exclamation in the product, a credential claim, not a cheer.
- **Say the true noun.** Spaced-repetition scheduling is no longer surfaced as
  dates (2026-07-04): the Reader "Due today" badge, the tray "N done · M due"
  counter, and per-tier interval hints are gone. What remains is the Topics
  recall pip as a bare status word - **"Due"** (amber), "Recalled" (green),
  "New." Home's CTA keeps the founder-locked "suggested" framing - "View 12
  suggested answers" - the queue reads as guidance, not homework. Never invent a
  third word.
- **Count honest things.** "This Week" shows "41 answers recalled" and "71%
  rated Easy" - real recall data. **Never a streak.** ("6 day streak-free" is
  banned: it is a streak wearing an anti-gamification fig leaf.)
- **No app-speak in editorial slots.** "answers," not "QnAs," in user-facing
  copy. "QnA" is the internal data-model term (D14) and stays out of the UI.
- **Never expose the plumbing.** No "checksum," "cache," "version," "RLS,"
  "entitlement" in user copy. There is no download UI (2026-07-04); a failed
  content fetch says "Couldn't load this - retry," nothing more technical.
- **Labels don't lie.** If a gesture isn't wired, don't label it. Inline
  diagrams say "Tap to enlarge" (they open the fullscreen viewer); only the
  fullscreen viewer says "Pinch … to zoom," because only it has the gesture.
- **Empty states carry direction, not apology** (D13 first-run funnel):
  "Nothing scheduled yet. Study one answer to start your recall queue." /
  "Today's recall is complete. 8 reviewed; next due tomorrow."
- **Store-compliance copy is exact.** On Play with Google-only sign-in (D5),
  purchase restore is implicit - entitlements re-attach on sign-in, so the
  sheet carries **no Restore row**, only the support line ("Trouble? Mail us").
  **If iOS ever ships, an explicit "Restore purchase" affordance becomes
  mandatory in the sheet** (App Store rule). Delete/Privacy/Terms lines present
  where policy requires (sign-in, Account).

---

## Screen Anatomy (canonical layouts)

Eight screens + one sheet. Reference `prototype/index.html`.

1. **Sign-in** - wordmark → serif lede ("Master DNB theory answers by recalling
   them, not rereading them") → **content specimen** (a cropped real model
   answer with fade-out - the one visual proof of what you're buying; never ship
   sign-in without it) → "Continue with Google" (sole auth, D5) → utility line
   (sync note + Terms/Privacy). No splash, no carousel, no stock doctor photo.
2. **Speciality onboarding** - mandatory, unskippable (D13). 61 DNB/DrNB tracks,
   grouped, single-select radio, substring search with highlight + result count,
   Enter = pick top match. Continue disabled until one is chosen. Shown once;
   changeable **once** later from Account.
3. **Home** - queue-first. Top matter is the greeting ("Good morning, Ananya,"
   name in `--teal-ink`) → primary CTA "View N suggested answers" (**hidden
   entirely when N = 0** - no empty or disabled CTA; the ghost "View your
   bookmarks" drops its top margin to close the gap) → ghost CTA "View your
   bookmarks" → "This Week" (two honest stats) → **pinned resume row** (sticky
   above the nav, never scrolls away). No countdown, no epigraph - both struck
   (see Decisions Log 2026-07-03).
4. **Syllabus** - chapter rows: title, question count in the subtitle,
   recall progress; tapping a chapter opens the Reader on its first
   question. Locked chapters stay visible (title + count, never answer
   previews); the lock signal is lock icon + `Locked` lozenge, nothing else
   (no third signal, no preview). **Billing slice - not rendered in beta
   (PG3):** in the free beta every chapter row is open and tappable; see the
   Free-Beta UI Contract section.
5. **Reader / Recall** - one surface, two states:
   - **Before:** question (24px serif) + year + marks; a plain attempt prompt
     (pen icon + one line, no card); Reveal Answer full-width in the thumb zone.
     No countdown, no hard lock - the ≥10s validity rule (D9) stays invisible.
   - **After:** answer renders on **white** with the **examiner's red margin**
     (per-section mark weights). Anatomy: "What earns marks" outline → numbered
     serif sections → full-width diagram plate (with fullscreen viewer) →
     summary → rating tray. **Rating tray is in-flow**, last thing in the
     answer (Easy · Medium · Hard - a 3-tier self-rating; green/amber/red
     traffic-light, smile/meh/frown face icon + word, fixed order, no interval
     hints and no "done/due" counter as of 2026-07-04; D15 reversed - see
     Decisions Log).
     In-answer fuzzy search appears
     **only after reveal** (never leaks answers). Diagram reproduction practice
     is post-v1 (D15).
6. **Account** - identity → Exam speciality (one-time change) → daily
   reminder → sign out → delete account (Play mandate).
7. **Bookmarks** - saved questions as rows (question + chapter title source),
   reached from Home, lights the Home tab.
8. **Paywall sheet** - **Billing slice - not rendered in beta (PG3).**
   locked contents (titles + counts, never previews) →
   exact price (₹499 one-time) → what's included → **Purchase** → one support
   line ("Trouble? Mail us"). **No Restore row** - restore is implicit under
   Google-only sign-in (D5) on Play; an explicit "Restore purchase" slot
   becomes mandatory if iOS ever ships. No UPI explainer in the sheet
   (beta payment mechanics live in the ops runbook, not the design).

---

## Accessibility (D20 - non-negotiable)

- 48dp minimum touch targets; primary loop actions in the bottom 25% thumb zone.
- Body contrast ≥ 4.5:1 (verified for every token pair above).
- Color never the sole signal (labels/icons/shapes accompany every state color).
- TalkBack semantic order; diagram content descriptions on every figure.
- Survives system `textScale 1.3` without layout breakage.
- `prefers-reduced-motion` disables all motion (reveal → instant swap).

---

## Free-Beta UI Contract (PG3, 2026-07-04)

The beta is a fully free app. This section is the render contract for lane B;
it supersedes any lock/paywall rendering described elsewhere in this document.

- **Beta screen inventory (8):** Sign-in, Speciality onboarding (+ change
  mode), Home, Syllabus, Reader/Recall, Bookmarks, Account, and the
  fullscreen diagram viewer. The paywall sheet is NOT in the beta widget tree.
- **No monetization UI anywhere:** no lock icons, no `Locked` lozenges, no
  Purchase/price/unlock copy, no "locked chapters" footer. Entitlement lives
  in the API schema (plan 2), never in beta widgets.
- **Syllabus row contract:** every chapter row renders title + question-count
  subtitle (`N questions`) + recall progress as the loud right-side signal
  (`8/14` over `recalled`, `--teal-ink`) with a thin progress bar once
  recall has started. No download/offline state of any kind (feature removed
  2026-07-04): no lozenges, no percentages, no remove-download, no storage
  lines.
- **Chapter tap contract:** tapping ANY chapter row opens the Reader in
  browse mode on the chapter's first question. Content is fetched on demand
  on entry; while fetching, the Reader shows its loading state; on failure
  it shows the inline retry state (below). No "download prep" percentage
  anywhere.
- **Syllabus footer:** removed in beta. Its only job was selling the unlock;
  with nothing locked it says nothing true.
- **Lock/paywall material elsewhere in this doc** (Screen Anatomy items 4
  and 8, Copy Voice store-compliance lines) is annotated in place as
  "billing slice - not rendered in beta" and kept for the billing slice.

## State Specs (D6 edge inventory, amended 2026-07-04)

Pack/storage edges are gone with the Downloads feature. The inventory below
is exhaustive for lane B; each state ships with a widget test. Copy is exact.

1. **Content fetch failed (any screen that loads content):** inline state,
   centered in the failed region: body text `Couldn't load this - retry`
   with a `Retry` text button under it. One string product-wide. No jargon,
   no error codes.
2. **Sign-in in-flight:** after tapping `Continue with Google` the button
   disables and shows a small progress spinner in place of its icon; no
   second action appears. Cancelling the Google sheet returns to idle with
   no error shown.
3. **Sign-in auth-error vs offline (distinct copies):**
   - auth error: `Sign-in failed - try again.`
   - offline: `You're offline - connect and retry.`
     Both render as a single meta-size line under the button, `--exam-red`.
4. **Speciality commit pending:** CTA disables, label swaps to a spinner;
   list stays interactive-off (taps ignored) until resolution.
5. **Speciality commit failure vs offline (distinct copies), shown as a
   meta line above the CTA, `--exam-red`, with the CTA re-enabled to retry:**
   - offline: `You're offline - your speciality wasn't saved. Retry.`
   - failure: `Couldn't save your speciality - retry.`
6. **Home N=0:** the primary CTA is hidden entirely (no empty or disabled
   button); the ghost bookmarks CTA drops its top margin to close the gap.
7. **This Week % floor (n>=5):** the `% rated Easy` stat renders only when
   at least 5 ratings exist in the trailing 7 days; below that the block
   shows the `answers recalled` figure alone. Counts render from 0 honestly.
8. **Resume slot, day zero ("Start here"):** with no reading history the
   pinned row shows overline `Start here` + the highest-exam-weight
   chapter's title + subtitle `Begin with the highest-yield chapter`;
   tapping opens the Reader on that chapter's first question. No
   auto-download exists. With history it shows overline `Pick up where you
left off` + chapter title + `Question i of N`.
9. **Empty track (PG2, first-class screen):** when the chosen speciality
   has no published chapters, Syllabus renders (not a dialog, not a toast):
   heading `No answers here yet` (serif title size), body `<Speciality>
answers are being written. Your pick counts - it tells us which
speciality we publish next.`, sub-line `You can change your speciality
once in Account.` Bottom nav stays live. Empty-track picks are excluded
   from the activation cohort (analytics note, plan 2/6).
10. **Catalog loading / catalog error (Syllabus):** loading = centered
    progress indicator; error = state 1 (inline retry) filling the list
    region.
11. **Empty Bookmarks:** heading `Nothing saved yet.` + body `Bookmark an
answer while reading and it will be kept here.` Centered in the list
    region; crumb count reads `Saved · 0 questions`.
12. **Reader end-of-queue completion (queue mode - built in plan 5, specced
    here):** after rating the last due answer the Reader shows a completion
    state, not a bounce: `Today's recall is complete. N reviewed; next due
tomorrow.` + ghost CTA `Study a new answer` (routes to Syllabus).
13. **Report an answer error (TD1):** post-reveal only, a quiet row action
    under the rating tray: `Report an answer error`. Online-only in v1:
    when offline the row is disabled with subtitle `Connect to the internet
to report an error.` Submitting shows toast `✓ Report sent - thank you`.
14. **One-way door confirmations (T8):** - Speciality change (Account -> change mode -> Save change with a
    different track): confirm dialog title `Use your one change?`, body
    `<Old> -> <New>. You can change your speciality once - this is that
change.`, actions `Cancel` / `Change speciality`. Re-saving the same
    track commits without a dialog and does not consume the change. - Delete account, 2-step: dialog 1 title `Delete your account?`, body
    `This permanently removes your recall history, bookmarks and profile
from DiploMate. There is no undo.`, actions `Cancel` / `Continue`;
    dialog 2 title `This is permanent`, body `Your account and all data
are deleted immediately. You would start again from zero.`, actions
    `Keep my account` / `Delete account` (destructive red).
15. **Account "Last synced" line (TD2):** subtitle of a quiet sync row:
    `Not synced yet` before first sync, `Last synced today`, `Last synced
1 day ago`, `Last synced N days ago`. Renders `--amber` when 3 or more
    days stale, `--ink-3` otherwise.

## Responsive Rules (2026-07-04, design T5 - landed, test-enforced 2026-07-05)

The prototype is a fixed 344x720 frame; the app is not. One set of rules:

- **320dp compact floor:** every screen lays out at 320dp width with no
  horizontal overflow. Long titles (speciality, chapter, topic) ellipsize on
  one line in rows; the Reader question never truncates (it wraps).
- **Short landscape:** all screens scroll vertically; nothing is pinned that
  makes content unreachable at 360dp height. The Reader pre-reveal state is
  one scrollable column so `Reveal Answer` is always reachable.
- **600dp+ (tablet) reading measure:** the Reader content column is centered
  with `max-width 560dp`. Never full-bleed 17px serif across a tablet width.
  Other screens keep list rows full-width (rows are scannable, prose is not).
- **Keyboard-visible search:** the speciality screen's search field and
  result list stay visible above the soft keyboard (the list shrinks; the
  CTA may scroll below the fold while the keyboard is up).
- **Safe areas:** all screens render inside SafeArea; the bottom nav and the
  pinned Home resume row respect the gesture inset.
- **textScale 1.3:** every screen survives system textScale 1.3 with no
  layout breakage (test-enforced). Body text is already 17sp minimum.

## A11y Executable Pack (2026-07-04, design T6 - build floor, landed + test-enforced 2026-07-05)

- **48dp is the build floor** for every interactive target (44px was the
  HTML-demo compromise). Android tap-target guideline tests run per screen.
- **Visible focus:** every focusable control shows the Material focus
  highlight; keyboard traversal reaches every interactive element.
- **Roving radio focus (speciality list):** the grouped list is a
  radiogroup; ArrowDown/ArrowUp move selection to the next/previous visible
  row (selection follows focus); Enter in the search field picks the top
  visible match. Keyboard acceptance test required.
- **aria-current on nav:** the active bottom-nav tab is exposed as selected
  to accessibility services.
- **Announcements:** the toast (`.ack` equivalent) is a live region; rating
  acknowledgement and auto-advance are announced.
- **Diagram content descriptions:** every figure carries its
  `content_description` from the content DDL as its semantic label.
- **Fullscreen-viewer focus trap:** the diagram viewer is a modal dialog
  that traps focus while open and restores focus to the opening control on
  close; Escape closes it.
- **TalkBack semantic order per screen:** reading order matches visual
  order top-to-bottom (Home: greeting -> primary CTA -> ghost CTA -> stats
  -> resume row -> nav). Traversal-order tests run on Home and Reader.
- **Reduced motion:** all three sanctioned motions become instant swaps
  under the system reduce-motion setting.

## Decisions Log

| Date       | Decision                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Rationale                                                                                                                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-07-03 | Initial DESIGN.md created from prototype + plan D13-D20 + cross-model review + category research                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `/design-consultation`                                                                                                                                                                                |
| 2026-07-03 | `--ink-3` light `#8A97A8`→`#5F6F84`, dark `#6E675C`→`#8A8275`; `--teal` `#0D8F86`→`#087A72`                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Old values failed the D20 4.5:1 body-contrast lock (2.8/3.2/3.97:1); corrected to pass. Verified WCAG.                                                                                                |
| 2026-07-03 | Teal-for-fills / teal-ink-for-text made law                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Raw teal fails AA as small text; splits the token so overlines + active nav stay legible in both themes                                                                                               |
| 2026-07-03 | Fixed 7-step type scale replaces ~22 ad-hoc sizes; body locked at 17px; section heads (19px) > body                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Prototype drift; D16 readability; hierarchy inversion in the reading surface                                                                                                                          |
| 2026-07-03 | Bottom nav 3 tabs (Home · Syllabus · Account); Downloads → Account row                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Supersedes D13 four-tab spec; matches built prototype                                                                                                                                                 |
| 2026-07-03 | Risk adopted: model answers render on white (`--elevated`) as material code                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Cheap distinctive move; makes the reveal a physical event; serves "recall, not reread"                                                                                                                |
| 2026-07-03 | Risk adopted: examiner's red margin (per-section mark weights) replaces `01/02` numerals                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Culturally exact (red pen = examiner); answer reads as a marked script                                                                                                                                |
| 2026-07-03 | Home top matter = exam countdown, replacing the epigraph/quote                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Persona-exact (days-remaining is the finalist's cosmology); kills the habit-app quote-first pattern; supersedes prior epigraph refinement                                                             |
| 2026-07-03 | Pre-reveal skeleton deferred to a post-beta A/B                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | It changes what the recall metric measures; ship as a measured experiment, not a v1 guess                                                                                                             |
| 2026-07-03 | Rating tray pinned to bottom (was in-flow)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | In-flow tray forced scrolling back through the answer - the exact reread the product forbids (D15)                                                                                                    |
| 2026-07-03 | Copy fixes: "streak-free"→"answers recalled"; "QnAs"→"answers"; nav "Ananya"→"Account"; false "Pinch to zoom"→"Tap to enlarge"; TAP block filed under Regional Anaesthesia (not Airway)                                                                                                                                                                                                                                                                                                                                                                            | Register discipline + a content-taxonomy credibility bug in the demo data                                                                                                                             |
| 2026-07-03 | D15 reversed: rating tray back to in-flow (was pinned bottom)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Explicit user call, made aware of the reread tradeoff D15 documented                                                                                                                                  |
| 2026-07-03 | Struck: Home exam-countdown top matter (Home opens at the greeting) and Account "Downloads & storage" row (no Downloads surface; offline state stays inline on syllabus rows)                                                                                                                                                                                                                                                                                                                                                                                      | Founder call - prototype stands as built; all five sync-3 flagged items discarded                                                                                                                     |
| 2026-07-04 | /design-review pass: touch targets ≥44px; teal-as-text → `--teal-ink` at all 6 call sites; type scale enforced (7 steps, zero drift); overline tracking one value (.14em); 18px gutter + 8px topbar restored; CTA glow removed; radii snapped to 8/12; tabular-nums on every count; reveal motion implemented (200ms uncover); dark `--ink-3` → `#908878` (AA on both dark surfaces); `--teal-soft` rebuilt from corrected teal; `--danger` aliases `--exam-red`                                                                                                   | Prototype brought into full compliance with this document; spec's "now fixed" claims made true in code                                                                                                |
| 2026-07-04 | Demo data one-truth pass: syllabus lists all 18 chapters (matches paywall pitch + "see the full syllabus" promise); resume row "Topic 3 of 14"; bookmarks re-filed TAP under Regional Anaesthesia; examiner-margin weights reconciled to the earn table (added Indications section, diagram plate carries its 1 mark, Summary unnumbered)                                                                                                                                                                                                                          | Counts that disagree read as sloppiness to an examiner-trained audience; the earn table is authoritative                                                                                              |
| 2026-07-04 | Codified: no Restore row on Play (restore implicit under Google-only D5; mandatory if iOS ships); rating label "Unable to recall" (Anki's Again); red also sanctioned for the destructive Delete-account row; specimen + toast added to no-cards exceptions; lock signal = icon + lozenge                                                                                                                                                                                                                                                                          | Doc-spec-prototype contradictions resolved in the direction the specs and prototype had already locked                                                                                                |
| 2026-07-04 | User-directed prototype pass: rating tray Unable/Hard/Good -> **Easy/Medium/Hard** (green/amber/red traffic-light, smile/meh/frown icons, no interval hints, no "done/due" counter); SRS de-surfaced (Reader "Due today" badge + Topics date pips removed -> pip now bare status Recalled/Due/New); "rated Good" -> "rated Easy"; sign-in tagline "Written by Doctors. Solved for Success!" added, util trimmed to legal links; "What earns marks" rows anchor-scroll to sections; Account avatar -> Google profile image; all em/en-dashes -> hyphen product-wide | Founder call - product shifts from a visible spaced-repetition scheduler toward a plain difficulty-rating study tool; Law 5 (red) relaxed to admit the Hard tier; DESIGN.md synced to prototype truth |
| 2026-07-04 | **No offline Downloads feature**: no download/offline state anywhere (no syllabus lozenges, no downloading %, no "Available offline"/"Update available"/"Download failed" copy, no remove-download); content loads on demand with a transparent device cache; failed fetch = inline "Couldn't load this - retry"                                                                                                                                                                                                                                                   | Founder call (evening) - kills bundle-install/storage complexity in v1; online-first accepted; prototype's download lozenges are display-only legacy with no build obligation                         |
| 2026-07-04 | Free-Beta UI Contract + State Specs sections added (design T1/T2/T3/T8): no monetization UI in beta, syllabus rows = title + count + recall progress, chapter tap -> Topics, empty-track first-class screen, exact copy for all D6 edge states incl. one-way-door confirmations                                                                                                                                                                                                                                                                                    | /autoplan design review P1 tasks; lane B builds against written truth                                                                                                                                 |
| 2026-07-04 | Responsive Rules + A11y Executable Pack sections added (design T5/T6); token tables completed from built CSS (teal-soft/amber-soft/nav-\* both themes, dark sunk/rule/rule-strong/ok); reveal scroll-preserve noted as law vs prototype clamp (T7)                                                                                                                                                                                                                                                                                                                 | /autoplan design review; lane B builds against written truth                                                                                                                                          |
| 2026-07-04 | Flutter build (lane B) landed against this document: tokens transcribed to app/lib/theme/tokens.dart, 9 screens + shell built on fixtures, free-beta UI contract + no-downloads enforced by widget tests                                                                                                                                                                                                                                                                                                                                                           | Plan 2026-07-04-flutter-shell-screens.md; per-screen specs are the copy source of truth                                                                                                               |
| 2026-07-05 | Responsive Rules (T5) + A11y Executable Pack (T6) closed out by the acceptance sweep: 320dp/short-landscape/textScale 1.3/600dp+ max-width, 48dp tap-target guideline, roving-radio ArrowDown/ArrowUp keyboard nav, TalkBack labels, reduced-motion instant swap, reveal scroll-preserve (T7) all test-enforced in `app/test/acceptance/`                                                                                                                                                                                                                          | Task 17, plan 2026-07-04-flutter-shell-screens.md; sweep found and fixed two real gaps: rating-tray semantics label collision and missing roving-radio keyboard handler                               |
| 2026-07-06 | Topics nav level removed (content pass): syllabus chapter rows open the Reader directly (one fewer tap); subtitle = question count; crumb "Question i of N"; "Next in chapter"; activation event = chapter_opened on chapter open                                                                                                                                                                                                                                                                                                                                  | Founder-approved book-grounded content pass (design doc jolly-banach-f5aef8 + eng amendments): chapters mirror Miller's own chapter list, questions hang directly off chapters                        |
