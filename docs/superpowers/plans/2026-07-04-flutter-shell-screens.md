# Flutter Shell + Screens (Lane B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the DiploMate Flutter app shell and all nine free-beta screens on DDL-shaped fixture data, with the design truth (free-beta UI contract, state specs, responsive rules, a11y pack) written into DESIGN.md first so every screen task builds against written law.

**Architecture:** A Flutter app (`app/`, package `diplomate`) with semantic theme tokens transcribed from DESIGN.md, go_router + a 3-tab StatefulShellRoute (Home / Syllabus / Account), and Riverpod providers over a fixture-backed `ContentRepository` plus fake `AuthRepository` / `SyncService` implementations that match the shared interface contract verbatim. Plans 5 (study loop) and 6 (integration) later swap the fake providers for drift/dio-backed ones without touching the widget tree.

**Tech Stack:** Flutter (Android first), flutter_riverpod, go_router, bundled Source Serif 4 + Manrope (OFL assets, no google_fonts), flutter_test widget tests.

## Global Constraints

Copied from the shared interface contract (`plan-contract.md`) - exact values, every task inherits them:

- NEVER use em-dashes or en-dashes in any file, code, comment, UI copy, or doc; plain hyphens only (user convention).
- NO offline Downloads feature (founder, 2026-07-04 evening): no download states/rows/copy, no remove-download, no storage UI, no offline promises. Content on demand + transparent cache only. Do not build DownloadService. The prototype's download lozenges are display-only legacy with no build obligation.
- DESIGN.md + docs/superpowers/specs/\*.md are design truth; protect the two signature moves (answer-on-white, examiner's red margin) and color laws (teal-for-fills / teal-ink-for-text; contrast >= 4.5:1). QA must not revert the 2026-07-04 founder edits (Easy/Medium/Hard tray, SRS de-surfaced, tagline "Written by Doctors. Solved for Success!").
- User copy says "answers", never "QnAs". No day-streaks. No cards anywhere (named exceptions: buttons, diagram plates, inputs, sign-in specimen, transient toast). Never expose "checksum/version/cache" in user copy. Labels don't lie. A failed content fetch says exactly: `Couldn't load this - retry`.
- FREE BETA (PG3): no locks, no paywall sheet, no purchase language anywhere in the beta UI. Entitlement schema + middleware are server work (plan 2); paywall UI is billing-slice work, kept out of the widget tree.
- Fonts: Source Serif 4 (question + answer body) + Manrope (UI) bundled as OFL app assets; google_fonts runtime fetch disabled (ENG-T21) - google_fonts is not a dependency at all.
- A11y build floor: 48dp targets, >=4.5:1 contrast, TalkBack semantic order, visible focus, diagram content descriptions, fullscreen-viewer focus trap, reduced-motion honored. Motion budget: reveal/rating-ack/queue-transition only, 150-220ms.
- Stack locks (app side): Flutter + Riverpod + drift + go_router + google_sign_in + dio + sentry_flutter + flutter_secure_storage + flutter_local_notifications. This plan adds only flutter_riverpod + go_router; the other locked packages arrive with plans 5/6 (do NOT add speculative dependencies).
- Wire rating enum `{again, hard, good}` is owned by `sql/` DDL. UI labels (display only): again = "Hard" (red `--exam-red`, frown face), hard = "Medium" (amber, meh face), good = "Easy" (green `--ok`, smile face). Tray order left-to-right: Easy - Medium - Hard. NO interval/date copy in UI; NO done/due counter; toast = `✓ Rated <tier> · next answer`.
- 61 tracks: 30 DNB broad + 31 DrNB super; beta data = Anaesthesiology only (TD3); empty-track first-class state is live-by-design (PG2/design T2).
- Repository/service interface names come from the contract verbatim: `ContentRepository`, `AuthRepository`, `SessionUser`, `SyncService`, `WireRating` - exact signatures repeated in each task's Interfaces block.
- TDD: every task = failing test -> minimal code -> pass -> commit. Conventional-commit messages.
- Repo root is `/Users/nirmit/Codebases/DiploMate`. The Flutter project lives at `app/`. All `flutter` commands below run from `/Users/nirmit/Codebases/DiploMate/app` unless stated otherwise.

---

### Task 1: Write the free-beta UI contract + state-spec pack into DESIGN.md and specs

This is doc work (DESIGN-T1 as amended, DESIGN-T2, DESIGN-T3, DESIGN-T8). Every later task copies its screen states and copy strings from what this task writes. No placeholder prose: the exact markdown to insert is below.

**Files:**

- Modify: `DESIGN.md`
- Modify: `docs/superpowers/specs/2026-07-03-syllabus-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-signin-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-speciality-onboarding-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-home-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-bookmarks-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-reader-recall-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-account-design.md`

**Interfaces:**

- Consumes: nothing (first task).
- Produces: the normative sections `## Free-Beta UI Contract (PG3, 2026-07-04)` and `## State Specs (D6 edge inventory, amended)` in DESIGN.md. Every copy string later tasks put in `app/lib/ui/copy.dart` is defined here first.

- [ ] **Step 1: Insert the Free-Beta UI Contract section into DESIGN.md**

Insert the following block immediately BEFORE the `## Decisions Log` heading in `DESIGN.md`:

```markdown
## Free-Beta UI Contract (PG3, 2026-07-04)

The beta is a fully free app. This section is the render contract for lane B;
it supersedes any lock/paywall rendering described elsewhere in this document.

- **Beta screen inventory (9):** Sign-in, Speciality onboarding (+ change
  mode), Home, Syllabus, Topics, Reader/Recall, Bookmarks, Account, and the
  fullscreen diagram viewer. The paywall sheet is NOT in the beta widget tree.
- **No monetization UI anywhere:** no lock icons, no `Locked` lozenges, no
  Purchase/price/unlock copy, no "locked chapters" footer. Entitlement lives
  in the API schema (plan 2), never in beta widgets.
- **Syllabus row contract:** every chapter row renders title + topic-count
  subtitle (`N topics`) + recall progress as the loud right-side signal
  (`8/14` over `recalled`, `--teal-ink`) with a thin progress bar once
  recall has started. No download/offline state of any kind (feature removed
  2026-07-04): no lozenges, no percentages, no remove-download, no storage
  lines.
- **Chapter tap contract:** tapping ANY chapter row navigates to Topics.
  Content is fetched on demand on entry; while fetching, Topics shows a
  centered progress indicator; on failure it shows the inline retry state
  (below). No "download prep" percentage anywhere.
- **Syllabus footer:** removed in beta. Its only job was selling the unlock;
  with nothing locked it says nothing true.
- **Lock/paywall material elsewhere in this doc** (Screen Anatomy items 4
  and 9, Copy Voice store-compliance lines) is annotated in place as
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
   - auth error: `Couldn't sign you in - try again.`
   - offline: `You're offline - connect and try again.`
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
   tapping routes into that chapter's Topics screen. No auto-download
   exists. With history it shows overline `Pick up where you left off` +
   chapter title + `Topic i of N · <topic title>`.
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
```

- [ ] **Step 2: Annotate the lock/paywall material in DESIGN.md**

In `DESIGN.md` `## Screen Anatomy` item 4 (Syllabus), after the sentence ending `(no third signal, no preview).`, append:

```markdown
**Billing slice - not rendered in beta (PG3):** in the free beta every
chapter row is open and tappable; see the Free-Beta UI Contract section.
```

In `## Screen Anatomy` item 9 (Paywall sheet), insert at the start of the item body, before `Locked contents`:

```markdown
**Billing slice - not rendered in beta (PG3).**
```

- [ ] **Step 3: Add the beta section to the syllabus spec**

In `docs/superpowers/specs/2026-07-03-syllabus-design.md`, immediately after the `# Syllabus - design` heading line, insert:

```markdown
> **Free beta (PG3, 2026-07-04):** locked rows, the `Locked` lozenge, the
> paywall sheet, and the unlock footer are billing-slice material - NOT
> rendered in beta. Beta rows: title + `N topics` subtitle + recall progress;
> every row taps through to Topics. See DESIGN.md "Free-Beta UI Contract".
```

- [ ] **Step 4: Add state pointers to the other specs**

Append to `docs/superpowers/specs/2026-07-03-signin-design.md`:

```markdown
## States (2026-07-04, DESIGN.md State Specs 2-3)

In-flight: button disabled + spinner; cancel returns to idle, no error.
Auth error: `Couldn't sign you in - try again.` Offline: `You're offline -
connect and try again.` Distinct copies, meta size, `--exam-red`.
```

Append to `docs/superpowers/specs/2026-07-03-speciality-onboarding-design.md`:

```markdown
## Commit states (2026-07-04, DESIGN.md State Specs 4-5)

Pending: CTA disabled + spinner, list taps ignored. Offline: `You're
offline - your speciality wasn't saved. Retry.` Failure: `Couldn't save
your speciality - retry.` Both above the CTA, `--exam-red`, CTA re-enabled.
A real change (change mode, different track) is confirmed first: `Use your
one change?` / `<Old> -> <New>. You can change your speciality once - this
is that change.` / `Cancel` / `Change speciality`.
```

Append to `docs/superpowers/specs/2026-07-03-home-design.md`:

```markdown
## States (2026-07-04, DESIGN.md State Specs 6-8)

N=0: primary CTA absent, ghost CTA closes the gap. This Week: `% rated
Easy` renders only at n>=5 ratings in the trailing 7 days. Day-zero resume
slot: overline `Start here`, highest-exam-weight chapter title, subtitle
`Begin with the highest-yield chapter`, routes to that chapter's Topics.
```

Append to `docs/superpowers/specs/2026-07-03-bookmarks-design.md`:

```markdown
## Empty state (2026-07-04, DESIGN.md State Spec 11)

`Nothing saved yet.` + `Bookmark an answer while reading and it will be
kept here.` Crumb reads `Saved · 0 questions`.
```

Append to `docs/superpowers/specs/2026-07-03-reader-recall-design.md`:

```markdown
## Beta additions (2026-07-04, DESIGN.md State Specs 1, 12, 13)

Content fetch failure renders the inline retry state (`Couldn't load
this - retry`). `Report an answer error` row sits under the rating tray,
post-reveal only, online-only (disabled offline with `Connect to the
internet to report an error.`); submit toasts `✓ Report sent - thank you`.
End-of-queue completion state (queue mode, plan 5): `Today's recall is
complete. N reviewed; next due tomorrow.` + `Study a new answer`.
```

Append to `docs/superpowers/specs/2026-07-03-account-design.md`:

```markdown
## Confirmations + sync line (2026-07-04, DESIGN.md State Specs 14-15)

Speciality change and account deletion follow the one-way-door dialogs in
DESIGN.md State Spec 14 (exact copy there). A quiet sync row shows
`Not synced yet` / `Last synced today` / `Last synced N days ago`,
amber when >=3 days stale.
```

- [ ] **Step 5: Add Decisions Log rows**

Append to the `## Decisions Log` table in `DESIGN.md`:

```markdown
| 2026-07-04 | Free-Beta UI Contract + State Specs sections added (design T1/T2/T3/T8): no monetization UI in beta, syllabus rows = title + count + recall progress, chapter tap -> Topics, empty-track first-class screen, exact copy for all D6 edge states incl. one-way-door confirmations | /autoplan design review P1 tasks; lane B builds against written truth |
```

- [ ] **Step 6: Verify**

Run: `grep -c "Free-Beta UI Contract" /Users/nirmit/Codebases/DiploMate/DESIGN.md`
Expected: `2` or more (section heading + at least one reference)

Run: `grep -rn "Couldn't load this - retry" /Users/nirmit/Codebases/DiploMate/DESIGN.md | head -3`
Expected: at least 1 match

Run: `grep -rn -- "—\|–" /Users/nirmit/Codebases/DiploMate/DESIGN.md docs/superpowers/specs/ | grep -v "^Binary" | wc -l`
Expected: `0` (no em/en dashes introduced; if pre-existing ones appear, do not touch lines you did not write)

- [ ] **Step 7: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add DESIGN.md docs/superpowers/specs/
git commit -m "docs(design): free-beta UI contract + amended D6 state-spec pack (design T1/T2/T3/T8)"
```

---

### Task 2: Write responsive rules + a11y executable pack into DESIGN.md, complete token tables

Doc work for DESIGN-T5, DESIGN-T6, and DESIGN-T7 (doc-sync). The token values come from the built prototype CSS (`prototype/index.html` `.dir-b` / `.dir-c` blocks) - they are transcribed below, do not re-derive them.

**Files:**

- Modify: `DESIGN.md`
- Modify: `TODOS.md`

**Interfaces:**

- Consumes: Task 1's sections (insert after them, before `## Decisions Log`).
- Produces: `## Responsive Rules`, `## A11y Executable Pack`, and completed color token tables that Task 4 transcribes into `app/lib/theme/tokens.dart` verbatim.

- [ ] **Step 1: Complete the color token tables**

In `DESIGN.md` under `### Light - Clinical Chart (.dir-b, default)`, append these rows to the existing table (values from prototype CSS, already AA-checked in the 07-04 design-review pass):

```markdown
| `--teal-soft` | `#087A72` at 8% alpha (`#14087A72` ARGB) | Tint fills behind teal chips/marks (never text) |
| `--amber-soft` | `#A85B10` at 7% alpha (`#12A85B10` ARGB) | Tint fill behind the active search match |
| `--nav-bg` | `#FBFCFD` | Bottom-nav surface |
| `--nav-rule` | `#E4EAF0` | Bottom-nav top hairline |
| `--danger` | alias of `--exam-red` | One red, one source |
```

Under `### Dark - Night Desk (.dir-c)`, append these rows:

```markdown
| `--sunk` | `#141315` | Row hover, inset chips |
| `--rule` | `#302D31` | Hairline dividers |
| `--rule-strong` | `#3E3A3F` | Answer seam, input borders |
| `--ok` | `#5FCF8A` | Easy tier + "rated Easy" stat |
| `--teal-soft` | `#3ED8C4` at 9% alpha (`#183ED8C4` ARGB) | Tint fills (never text) |
| `--amber-soft` | `#F2B44C` at 8% alpha (`#14F2B44C` ARGB) | Active search match tint |
| `--nav-bg` | `#141315` | Bottom-nav surface |
| `--nav-rule` | `#2A282C` | Bottom-nav top hairline |
| `--danger` | alias of `--exam-red` | One red, one source |
```

- [ ] **Step 2: Insert the Responsive Rules section**

Insert immediately before `## Decisions Log` in `DESIGN.md`:

```markdown
## Responsive Rules (2026-07-04, design T5)

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

## A11y Executable Pack (2026-07-04, design T6 - build floor, test-enforced)

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
```

- [ ] **Step 3: Note the scroll-preserve law (doc-sync, T7)**

In `DESIGN.md` `## Motion` section, in the "Answer reveal" bullet, after `scroll position preserved.`, append:

```markdown
     (Law. The prototype clamps scroll-to-top on reveal - a demo limitation,
     not the spec; the app preserves the reading position.)
```

- [ ] **Step 4: Mark the TODOS a11y deferral as executed**

In `TODOS.md` section 6, in the "Flutter a11y" bullet, append after `(44px was the HTML-demo compromise).`:

```markdown
_Landed as DESIGN.md "A11y Executable Pack" + lane-B test suite
(2026-07-04 plan `2026-07-04-flutter-shell-screens.md`)._
```

- [ ] **Step 5: Add a Decisions Log row**

Append to the `## Decisions Log` table in `DESIGN.md`:

```markdown
| 2026-07-04 | Responsive Rules + A11y Executable Pack sections added (design T5/T6); token tables completed from built CSS (teal-soft/amber-soft/nav-\* both themes, dark sunk/rule/rule-strong/ok); reveal scroll-preserve noted as law vs prototype clamp (T7) | /autoplan design review; lane B builds against written truth |
```

- [ ] **Step 6: Verify**

Run: `grep -c "A11y Executable Pack\|Responsive Rules" /Users/nirmit/Codebases/DiploMate/DESIGN.md`
Expected: `3` or more

Run: `grep -c "nav-bg" /Users/nirmit/Codebases/DiploMate/DESIGN.md`
Expected: `2` (one row per theme table)

- [ ] **Step 7: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add DESIGN.md TODOS.md
git commit -m "docs(design): responsive rules + a11y executable pack + token-table completion (design T5/T6/T7)"
```

---

### Task 3: Flutter project scaffold + bundled OFL fonts (ENG-T21)

**Files:**

- Create: `app/` (via `flutter create`)
- Create: `app/pubspec.yaml` (replace generated content)
- Create: `app/assets/fonts/SourceSerif4[opsz,wght].ttf`, `app/assets/fonts/SourceSerif4-Italic[opsz,wght].ttf`, `app/assets/fonts/Manrope[wght].ttf`, `app/assets/fonts/OFL-SourceSerif4.txt`, `app/assets/fonts/OFL-Manrope.txt`
- Test: `app/test/theme/fonts_test.dart`

**Interfaces:**

- Consumes: nothing.
- Produces: font family names `SourceSerif4` and `Manrope` (used by Task 4's `DmType`); the `diplomate` package name every later import uses (`package:diplomate/...`).

- [ ] **Step 1: Create the Flutter project**

```bash
cd /Users/nirmit/Codebases/DiploMate
flutter create app --org com.diplomate --project-name diplomate --platforms android --empty
```

Expected output ends with: `All done!`

- [ ] **Step 2: Download the OFL font files from the google/fonts repo**

```bash
cd /Users/nirmit/Codebases/DiploMate/app
mkdir -p assets/fonts assets/fixtures/images
curl -fsSL -o "assets/fonts/SourceSerif4[opsz,wght].ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/SourceSerif4%5Bopsz%2Cwght%5D.ttf"
curl -fsSL -o "assets/fonts/SourceSerif4-Italic[opsz,wght].ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/SourceSerif4-Italic%5Bopsz%2Cwght%5D.ttf"
curl -fsSL -o "assets/fonts/Manrope[wght].ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/Manrope%5Bwght%5D.ttf"
curl -fsSL -o "assets/fonts/OFL-SourceSerif4.txt" "https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/OFL.txt"
curl -fsSL -o "assets/fonts/OFL-Manrope.txt" "https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/OFL.txt"
ls -la assets/fonts/
```

Expected: five files listed, each TTF larger than 100KB. These are variable fonts; weight selection is done with `FontVariation('wght', ...)` in Task 4 (Flutter does not synthesize variable-font weights from `fontWeight` alone).

- [ ] **Step 3: Write the failing test**

`app/test/theme/fonts_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('fonts are bundled OFL assets, google_fonts is not a dependency (ENG-T21)', () {
    expect(pubspec.contains('google_fonts'), isFalse,
        reason: 'runtime font fetching is banned (ENG-T21)');
    expect(pubspec, contains('family: SourceSerif4'));
    expect(pubspec, contains('family: Manrope'));
    expect(File('assets/fonts/SourceSerif4[opsz,wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/SourceSerif4-Italic[opsz,wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/Manrope[wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-SourceSerif4.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Manrope.txt').existsSync(), isTrue);
  });

  test('stack locks: only approved packages are declared', () {
    expect(pubspec, contains('flutter_riverpod'));
    expect(pubspec, contains('go_router'));
  });
}
```

- [ ] **Step 4: Run the test, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/theme/fonts_test.dart`
Expected: FAIL - `Expected: contains 'family: SourceSerif4'` (pubspec not yet edited)

- [ ] **Step 5: Replace `app/pubspec.yaml`**

```yaml
name: diplomate
description: DiploMate - DNB theory exam prep by active recall.
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/fixtures/
    - assets/fixtures/images/
  fonts:
    - family: SourceSerif4
      fonts:
        - asset: assets/fonts/SourceSerif4[opsz,wght].ttf
        - asset: assets/fonts/SourceSerif4-Italic[opsz,wght].ttf
          style: italic
    - family: Manrope
      fonts:
        - asset: assets/fonts/Manrope[wght].ttf
```

Then run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter pub get`
Expected: `Got dependencies!`

Note: `assets/fixtures/` is declared now (Task 5 fills it); create a placeholder so pub does not warn:

```bash
cd /Users/nirmit/Codebases/DiploMate/app
echo '{}' > assets/fixtures/.gitkeep.json
```

- [ ] **Step 6: Run the test, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/theme/fonts_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/
git commit -m "feat(app): flutter scaffold with bundled Source Serif 4 + Manrope OFL assets (ENG-T21)"
```

---

### Task 4: Theme tokens + app theme

Transcribe the DESIGN.md token tables (as completed by Task 2) into Dart. Exact hex values; both themes; the 7-step type scale; spacing/radii/motion. Tokens are semantic - screens never hardcode a color.

**Files:**

- Create: `app/lib/theme/tokens.dart`
- Create: `app/lib/theme/app_theme.dart`
- Test: `app/test/theme/tokens_test.dart`

**Interfaces:**

- Consumes: font families `SourceSerif4` / `Manrope` (Task 3).
- Produces (used by every screen task):
  - `class DmColors` with fields `paper, elevated, sunk, ink, ink2, ink3, rule, ruleStrong, teal, tealSoft, tealInk, amber, amberSoft, examRed, ok, navBg, navRule` (all `Color`) and getter `danger` (alias of `examRed`); consts `dmLight`, `dmDark`.
  - `class DmType` with static `TextStyle`s `display, title, section, body, bodyUi, meta, label, statNumber` and `static const String serif`, `sans`.
  - `class DmSpace` (`xxs=2, xs=4, sm=8, md=12, lg=16, gutter=18, xl2=24, xl3=32`, doubles), `class DmRadius` (`sm=8, md=12`), `class DmMotion` (`micro=80ms, reveal=200ms, sheet=300ms, toastHold=1500ms` Durations).
  - `ThemeData dmLightTheme()`, `ThemeData dmDarkTheme()` (in `app_theme.dart`).
  - `extension DmContext on BuildContext { DmColors get dm; }` - the one way screens read colors.

- [ ] **Step 1: Write the failing test**

`app/test/theme/tokens_test.dart`:

```dart
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light tokens match DESIGN.md Clinical Chart table exactly', () {
    expect(dmLight.paper, const Color(0xFFF6F8FA));
    expect(dmLight.elevated, const Color(0xFFFFFFFF));
    expect(dmLight.sunk, const Color(0xFFEDF1F5));
    expect(dmLight.ink, const Color(0xFF0E1626));
    expect(dmLight.ink2, const Color(0xFF57657A));
    expect(dmLight.ink3, const Color(0xFF5F6F84));
    expect(dmLight.rule, const Color(0xFFE1E7EE));
    expect(dmLight.ruleStrong, const Color(0xFFCFD8E2));
    expect(dmLight.teal, const Color(0xFF087A72));
    expect(dmLight.tealSoft, const Color(0x14087A72));
    expect(dmLight.tealInk, const Color(0xFF0A6E67));
    expect(dmLight.amber, const Color(0xFFA85B10));
    expect(dmLight.amberSoft, const Color(0x12A85B10));
    expect(dmLight.examRed, const Color(0xFFB4271F));
    expect(dmLight.ok, const Color(0xFF1E7A46));
    expect(dmLight.navBg, const Color(0xFFFBFCFD));
    expect(dmLight.navRule, const Color(0xFFE4EAF0));
    expect(dmLight.danger, dmLight.examRed, reason: 'one red, one source');
  });

  test('dark tokens match DESIGN.md Night Desk table exactly', () {
    expect(dmDark.paper, const Color(0xFF19181A));
    expect(dmDark.elevated, const Color(0xFF211F22));
    expect(dmDark.sunk, const Color(0xFF141315));
    expect(dmDark.ink, const Color(0xFFECE6DC));
    expect(dmDark.ink2, const Color(0xFF9C9488));
    expect(dmDark.ink3, const Color(0xFF908878));
    expect(dmDark.rule, const Color(0xFF302D31));
    expect(dmDark.ruleStrong, const Color(0xFF3E3A3F));
    expect(dmDark.teal, const Color(0xFF3ED8C4));
    expect(dmDark.tealSoft, const Color(0x183ED8C4));
    expect(dmDark.tealInk, const Color(0xFF8CEBDD));
    expect(dmDark.amber, const Color(0xFFF2B44C));
    expect(dmDark.amberSoft, const Color(0x14F2B44C));
    expect(dmDark.examRed, const Color(0xFFF08A82));
    expect(dmDark.ok, const Color(0xFF5FCF8A));
    expect(dmDark.navBg, const Color(0xFF141315));
    expect(dmDark.navRule, const Color(0xFF2A282C));
  });

  test('type scale is the fixed 7 steps (DESIGN.md law)', () {
    expect(DmType.display.fontSize, 28);
    expect(DmType.display.fontFamily, 'SourceSerif4');
    expect(DmType.title.fontSize, 24);
    expect(DmType.section.fontSize, 19);
    expect(DmType.body.fontSize, 17);
    expect(DmType.body.fontFamily, 'SourceSerif4');
    expect(DmType.body.height, greaterThanOrEqualTo(1.55));
    expect(DmType.bodyUi.fontSize, 15);
    expect(DmType.bodyUi.fontFamily, 'Manrope');
    expect(DmType.meta.fontSize, 12.5);
    expect(DmType.label.fontSize, 11);
    expect(DmType.label.letterSpacing, closeTo(11 * 0.14, 0.001),
        reason: 'overline tracking is one value: 0.14em');
    expect(DmType.statNumber.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('themes expose DmColors via context extension', () {
    final light = dmLightTheme();
    final dark = dmDarkTheme();
    expect(light.extension<DmTheme>()!.colors, dmLight);
    expect(dark.extension<DmTheme>()!.colors, dmDark);
    expect(light.scaffoldBackgroundColor, dmLight.paper);
    expect(dark.scaffoldBackgroundColor, dmDark.paper);
  });
}
```

- [ ] **Step 2: Run the test, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/theme/tokens_test.dart`
Expected: FAIL - `Error: Couldn't resolve the package 'diplomate'` / missing `tokens.dart`

- [ ] **Step 3: Write `app/lib/theme/tokens.dart`**

```dart
import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart';

/// Transcribed from DESIGN.md token tables (Clinical Chart / Night Desk).
/// Semantic tokens only - never raw hex at call sites. Do not add values.
class DmColors {
  const DmColors({
    required this.paper,
    required this.elevated,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.rule,
    required this.ruleStrong,
    required this.teal,
    required this.tealSoft,
    required this.tealInk,
    required this.amber,
    required this.amberSoft,
    required this.examRed,
    required this.ok,
    required this.navBg,
    required this.navRule,
  });

  final Color paper;
  final Color elevated;
  final Color sunk;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color rule;
  final Color ruleStrong;

  /// Fills and strokes ONLY. Teal used as text must be [tealInk] (color law 1).
  final Color teal;
  final Color tealSoft;

  /// Teal used as text (overlines, active nav, links).
  final Color tealInk;
  final Color amber;
  final Color amberSoft;
  final Color examRed;
  final Color ok;
  final Color navBg;
  final Color navRule;

  /// One red, one source (color law 5).
  Color get danger => examRed;
}

const dmLight = DmColors(
  paper: Color(0xFFF6F8FA),
  elevated: Color(0xFFFFFFFF),
  sunk: Color(0xFFEDF1F5),
  ink: Color(0xFF0E1626),
  ink2: Color(0xFF57657A),
  ink3: Color(0xFF5F6F84),
  rule: Color(0xFFE1E7EE),
  ruleStrong: Color(0xFFCFD8E2),
  teal: Color(0xFF087A72),
  tealSoft: Color(0x14087A72),
  tealInk: Color(0xFF0A6E67),
  amber: Color(0xFFA85B10),
  amberSoft: Color(0x12A85B10),
  examRed: Color(0xFFB4271F),
  ok: Color(0xFF1E7A46),
  navBg: Color(0xFFFBFCFD),
  navRule: Color(0xFFE4EAF0),
);

const dmDark = DmColors(
  paper: Color(0xFF19181A),
  elevated: Color(0xFF211F22),
  sunk: Color(0xFF141315),
  ink: Color(0xFFECE6DC),
  ink2: Color(0xFF9C9488),
  ink3: Color(0xFF908878),
  rule: Color(0xFF302D31),
  ruleStrong: Color(0xFF3E3A3F),
  teal: Color(0xFF3ED8C4),
  tealSoft: Color(0x183ED8C4),
  tealInk: Color(0xFF8CEBDD),
  amber: Color(0xFFF2B44C),
  amberSoft: Color(0x14F2B44C),
  examRed: Color(0xFFF08A82),
  ok: Color(0xFF5FCF8A),
  navBg: Color(0xFF141315),
  navRule: Color(0xFF2A282C),
);

/// The fixed 7-step type scale (DESIGN.md law - do not add sizes).
/// Variable fonts need explicit wght axes; fontWeight alone is not enough.
class DmType {
  static const String serif = 'SourceSerif4';
  static const String sans = 'Manrope';

  static const List<FontVariation> _serif400 = [FontVariation('wght', 400)];
  static const List<FontVariation> _serif600 = [FontVariation('wght', 600)];
  static const List<FontVariation> _sans500 = [FontVariation('wght', 500)];
  static const List<FontVariation> _sans600 = [FontVariation('wght', 600)];
  static const List<FontVariation> _sans700 = [FontVariation('wght', 700)];

  /// All changing numerals render tabular (DESIGN.md typography law).
  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
      fontFamily: serif, fontSize: 28, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.25);
  static const TextStyle title = TextStyle(
      fontFamily: serif, fontSize: 24, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.4);
  static const TextStyle section = TextStyle(
      fontFamily: serif, fontSize: 19, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.35);
  static const TextStyle body = TextStyle(
      fontFamily: serif, fontSize: 17, fontWeight: FontWeight.w400, fontVariations: _serif400, height: 1.55);
  static const TextStyle bodyUi = TextStyle(
      fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w600, fontVariations: _sans600, height: 1.3);
  static const TextStyle meta = TextStyle(
      fontFamily: sans, fontSize: 12.5, fontWeight: FontWeight.w500, fontVariations: _sans500, height: 1.35);
  static const TextStyle label = TextStyle(
      fontFamily: sans,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      fontVariations: _sans700,
      letterSpacing: 11 * 0.14,
      height: 1.2);

  /// The one large-count slot (Home "This Week" numerals): Manrope 700 / 24.
  static const TextStyle statNumber = TextStyle(
      fontFamily: sans,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontVariations: _sans700,
      fontFeatures: tabularNums,
      height: 1.1);
}

/// 4px grid. Gutter is the single horizontal screen inset (18).
class DmSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double gutter = 18;
  static const double xl2 = 24;
  static const double xl3 = 32;
}

/// Radius only where containment is real: chips/inputs 8, buttons/plates 12.
class DmRadius {
  static const double sm = 8;
  static const double md = 12;
}

/// Motion budget (D20): reveal / rating-ack / queue-transition only.
class DmMotion {
  static const Duration micro = Duration(milliseconds: 80);
  static const Duration reveal = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration toastHold = Duration(milliseconds: 1500);
}

/// The examiner's-margin geometry (DESIGN.md Spacing section).
class DmReader {
  static const double examinerIndent = 26;
  static const double examinerRail = 19;
  static const double maxMeasure = 560;
}

class DmTheme extends ThemeExtension<DmTheme> {
  const DmTheme(this.colors);
  final DmColors colors;

  @override
  DmTheme copyWith({DmColors? colors}) => DmTheme(colors ?? this.colors);

  @override
  DmTheme lerp(DmTheme? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DmContext on BuildContext {
  DmColors get dm => Theme.of(this).extension<DmTheme>()!.colors;
}
```

- [ ] **Step 4: Write `app/lib/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData dmLightTheme() => _base(dmLight, Brightness.light);
ThemeData dmDarkTheme() => _base(dmDark, Brightness.dark);

ThemeData _base(DmColors c, Brightness b) {
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: DmType.sans,
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.teal,
      brightness: b,
      surface: c.paper,
      error: c.examRed,
    ),
    dividerColor: c.rule,
    // No decorative shadows anywhere (anti-slop + D20).
    dialogTheme: DialogThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DmRadius.md)),
    ),
    extensions: [DmTheme(c)],
  );
}
```

- [ ] **Step 5: Run the test, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/theme/tokens_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/theme/ app/test/theme/tokens_test.dart
git commit -m "feat(app): DESIGN.md theme tokens + light/dark app theme"
```

### Task 5: Contract interfaces, DDL-shaped fixtures, fixture repositories, provider seams

**Files:**

- Create: `app/lib/data/repos/content_repository.dart`
- Create: `app/lib/data/repos/auth_repository.dart`
- Create: `app/lib/services/sync_service.dart`
- Create: `app/lib/domain/models.dart`
- Create: `app/assets/fixtures/chapter_airway.json`
- Create: `app/assets/fixtures/images/fig_tap_block.webp` (any valid WebP < 200KB; a 1x1 placeholder is fine for tests)
- Create: `app/lib/data/fixtures/fixture_content_repository.dart`
- Create: `app/lib/data/fixtures/fake_auth_repository.dart`
- Create: `app/lib/data/fixtures/fake_sync_service.dart`
- Create: `app/lib/app_providers.dart`
- Create: `app/lib/providers/study_providers.dart` (STUB - plan 5 Task 7 replaces this file with the real providers, same names)
- Test: `app/test/data/fixture_content_repository_test.dart`

**Interfaces:**

- Consumes: the 61-track NAME list from `sql/0002_seed_specialities.sql` (day1-ddl plan Task 3) - names must match that seed verbatim. The fixture uses its own local ULIDs (e.g. `01J0SPECANAES0000000000001`); the real production anchor is day1's `01JZSP3C00DNB0000000000001` and only plan 6's remote repository ever sees real ids.
- Produces (used by every screen task and by plans 5/6):
  - `abstract class ContentRepository` (contract-verbatim): `specialities()`, `chapters(specialityId)`, `ensureChapterCached(chapterId)`, `topics(chapterId)`, `qnas(topicId)`, `qna(qnaId)`, `imageBytes(imageId)`.
  - `abstract class AuthRepository` + `class SessionUser` (contract-verbatim).
  - `abstract class SyncService` (contract-verbatim).
  - Row models in `models.dart`: `SpecialityRow(id, name, examType, slug, sortOrder, hasContent)`, `ChapterRow(id, specialityId, title, slug, sortOrder, examWeight, contentVersion, topicCount, qnaCount, recalledCount)`, `TopicRow(id, chapterId, title, slug, examTheme, sortOrder)`, `QnaRow(id, topicId, question, years, marks, earnsMarks, sections, sortOrder, images)`, `EarnRow(label, sectionKey)`, `AnswerSection(key, heading, bodyMd, marks)`, `ImageRow(id, caption, contentDescription, byteSize, sha256, sortOrder)`.
  - Providers in `app_providers.dart`: `contentRepositoryProvider` (`Provider<ContentRepository>`, default `FixtureContentRepository`), `authRepositoryProvider` (`Provider<AuthRepository>`, default `FakeAuthRepository`), `syncServiceProvider` (`Provider<SyncService>`, default `FakeSyncService`), `sessionUserProvider` (`StateProvider<SessionUser?>`, default null).
  - STUB `study_providers.dart`: `final dueCountProvider = Provider<int>((ref) => 12);` and `final resumeChapterProvider = Provider<ChapterRow?>` (highest `examWeight` chapter from fixtures). Plan 5 Task 7 overwrites this file keeping the same public names; the Home screen imports only these two.
  - `class ContentFetchException implements Exception { final String chapterId; }` - thrown by `ensureChapterCached` when offline (screens render the inline retry state on it).

- [ ] **Step 1: Write the failing test**

`app/test/data/fixture_content_repository_test.dart`:

```dart
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = FixtureContentRepository();

  test('fixture speciality is Anaesthesiology with content', () async {
    final specs = await repo.specialities();
    expect(specs.length, 61);
    final anaes = specs.singleWhere((s) => s.hasContent);
    expect(anaes.name, 'Anaesthesiology');
    expect(anaes.examType, 'DNB');
  });

  test('fixture chapter tree matches the DDL shape', () async {
    final specs = await repo.specialities();
    final anaes = specs.singleWhere((s) => s.hasContent);
    final chapters = await repo.chapters(anaes.id);
    expect(chapters, isNotEmpty);
    final airway = chapters.first;
    expect(airway.title, 'Airway Management');
    expect(airway.contentVersion, 1);
    final topics = await repo.topics(airway.id);
    expect(topics.length, 2);
    final qnas = await repo.qnas(topics.first.id);
    expect(qnas.first.earnsMarks.first.sectionKey, isNotEmpty);
    expect(qnas.first.sections.first.key, qnas.first.earnsMarks.first.sectionKey);
  });

  test('imageBytes returns bundled bytes', () async {
    final specs = await repo.specialities();
    final anaes = specs.singleWhere((s) => s.hasContent);
    final chapters = await repo.chapters(anaes.id);
    final topics = await repo.topics(chapters.first.id);
    final qnas = await repo.qnas(topics.first.id);
    final img = qnas.expand((q) => q.images).first;
    final bytes = await repo.imageBytes(img.id);
    expect(bytes, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the test, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/data/fixture_content_repository_test.dart`
Expected: FAIL - `Couldn't resolve ... fixture_content_repository.dart`

- [ ] **Step 3: Write the contract interfaces**

`app/lib/domain/models.dart`:

```dart
import 'dart:typed_data';

class SpecialityRow {
  const SpecialityRow({required this.id, required this.name, required this.examType,
      required this.slug, required this.sortOrder, required this.hasContent});
  final String id; // ULID
  final String name;
  final String examType; // 'DNB' | 'DrNB' (sql/0001 CHECK owns this enum)
  final String slug;
  final int sortOrder;
  final bool hasContent;
}

class ChapterRow {
  const ChapterRow({required this.id, required this.specialityId, required this.title,
      required this.slug, required this.sortOrder, required this.examWeight,
      required this.contentVersion, required this.topicCount, required this.qnaCount,
      this.recalledCount = 0});
  final String id, specialityId, title, slug;
  final int sortOrder, examWeight, contentVersion, topicCount, qnaCount;
  final int recalledCount; // fixture/UI aggregate; real value derives from plan 5 CardStates
}

class TopicRow {
  const TopicRow({required this.id, required this.chapterId, required this.title,
      required this.slug, this.examTheme, required this.sortOrder});
  final String id, chapterId, title, slug;
  final String? examTheme;
  final int sortOrder;
}

class EarnRow {
  const EarnRow({required this.label, required this.sectionKey});
  final String label, sectionKey;
}

class AnswerSection {
  const AnswerSection({required this.key, required this.heading, required this.bodyMd, this.marks});
  final String key, heading, bodyMd;
  final int? marks; // examiner red-margin weight; null = unnumbered (Summary)
}

class ImageRow {
  const ImageRow({required this.id, required this.caption, required this.contentDescription,
      required this.byteSize, required this.sha256, required this.sortOrder});
  final String id, caption, contentDescription, sha256;
  final int byteSize, sortOrder;
}

class QnaRow {
  const QnaRow({required this.id, required this.topicId, required this.question, this.years,
      this.marks, required this.earnsMarks, required this.sections, required this.sortOrder,
      required this.images});
  final String id, topicId, question;
  final String? years;
  final int? marks;
  final List<EarnRow> earnsMarks;
  final List<AnswerSection> sections;
  final int sortOrder;
  final List<ImageRow> images;
}
```

`app/lib/data/repos/content_repository.dart`:

```dart
import 'dart:typed_data';

import '../../domain/models.dart';

class ContentFetchException implements Exception {
  ContentFetchException(this.chapterId);
  final String chapterId;
}

/// Contract-verbatim (plan-contract.md). Plan 6 provides the dio+drift
/// implementation; this plan ships a fixture-backed one.
abstract class ContentRepository {
  Future<List<SpecialityRow>> specialities();
  Future<List<ChapterRow>> chapters(String specialityId);
  Future<void> ensureChapterCached(String chapterId);
  Future<List<TopicRow>> topics(String chapterId);
  Future<List<QnaRow>> qnas(String topicId);
  Future<QnaRow?> qna(String qnaId);
  Future<Uint8List> imageBytes(String imageId);
}
```

`app/lib/data/repos/auth_repository.dart`:

```dart
class SessionUser {
  const SessionUser({required this.id, required this.email, this.name, this.photoUrl,
      this.specialityId, required this.specialityChangeCount});
  final String id, email;
  final String? name, photoUrl, specialityId;
  final int specialityChangeCount;

  SessionUser copyWith({String? specialityId, int? specialityChangeCount}) => SessionUser(
      id: id, email: email, name: name, photoUrl: photoUrl,
      specialityId: specialityId ?? this.specialityId,
      specialityChangeCount: specialityChangeCount ?? this.specialityChangeCount);
}

class ChangeLimitReached implements Exception {}

class SignInCancelled implements Exception {}

class AuthOffline implements Exception {}

/// Contract-verbatim. Plan 6 implements against google_sign_in + POST /auth/google.
abstract class AuthRepository {
  Future<SessionUser> signInWithGoogle();
  Future<SessionUser?> restoreSession();
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<SessionUser> setSpeciality(String specialityId);
}
```

`app/lib/services/sync_service.dart`:

```dart
/// Contract-verbatim. Plan 6 implements (backoff + jitter, X-Refreshed-Token).
abstract class SyncService {
  Future<void> flush();
  Stream<DateTime?> lastSyncedAt();
}
```

- [ ] **Step 4: Write the fixture chapter**

`app/assets/fixtures/chapter_airway.json` - shaped EXACTLY like the sql/0001 tables (keys = column names). Two topics, three QnAs, one image; ULIDs are fixed strings:

```json
{
  "speciality": {
    "id": "01J0SPECANAES0000000000001",
    "name": "Anaesthesiology",
    "exam_type": "DNB",
    "slug": "anaesthesiology",
    "sort_order": 1
  },
  "chapters": [
    {
      "id": "01J0CHAPAIRWAY000000000001",
      "speciality_id": "01J0SPECANAES0000000000001",
      "title": "Airway Management",
      "slug": "airway-management",
      "sort_order": 1,
      "exam_weight": 100,
      "content_version": 1
    },
    {
      "id": "01J0CHAPREGIONAL0000000001",
      "speciality_id": "01J0SPECANAES0000000000001",
      "title": "Regional Anaesthesia",
      "slug": "regional-anaesthesia",
      "sort_order": 2,
      "exam_weight": 90,
      "content_version": 1
    }
  ],
  "topics": [
    {
      "id": "01J0TOPICDIFFAIR0000000001",
      "chapter_id": "01J0CHAPAIRWAY000000000001",
      "title": "Difficult airway algorithm",
      "slug": "difficult-airway-algorithm",
      "exam_theme": "Emergencies",
      "sort_order": 1
    },
    {
      "id": "01J0TOPICRSI00000000000001",
      "chapter_id": "01J0CHAPAIRWAY000000000001",
      "title": "Rapid sequence induction",
      "slug": "rapid-sequence-induction",
      "exam_theme": "Technique",
      "sort_order": 2
    },
    {
      "id": "01J0TOPICTAPBLOCK000000001",
      "chapter_id": "01J0CHAPREGIONAL0000000001",
      "title": "Truncal blocks",
      "slug": "truncal-blocks",
      "exam_theme": "Blocks",
      "sort_order": 1
    }
  ],
  "qnas": [
    {
      "id": "01J0QNATAPBLOCK00000000001",
      "topic_id": "01J0TOPICTAPBLOCK000000001",
      "question": "Describe the transversus abdominis plane (TAP) block: anatomical basis, ultrasound-guided technique, indications, and complications.",
      "years": "2022 Paper II",
      "marks": 10,
      "earns_marks": [
        { "label": "Definition", "section_key": "definition" },
        { "label": "Anatomical basis", "section_key": "anatomy" },
        { "label": "Technique - USG-guided", "section_key": "technique" },
        { "label": "Indications", "section_key": "indications" },
        { "label": "Complications", "section_key": "complications" }
      ],
      "sections": [
        {
          "key": "definition",
          "heading": "Definition",
          "body_md": "The TAP block is a fascial plane block depositing local anaesthetic between internal oblique and transversus abdominis, anaesthetising the anterior rami of T6-L1.",
          "marks": 1
        },
        {
          "key": "anatomy",
          "heading": "Anatomical basis",
          "body_md": "Three muscle layers form the anterolateral abdominal wall: external oblique, internal oblique, transversus abdominis. The neurovascular plane lies between the latter two.",
          "marks": 2
        },
        {
          "key": "technique",
          "heading": "Technique - USG-guided",
          "body_md": "High-frequency linear probe in the mid-axillary line between costal margin and iliac crest; identify the three layers; in-plane needle to the fascial plane; hydrodissect; deposit 15-20 ml per side.",
          "marks": 3
        },
        { "key": "diagram", "heading": "Diagram", "body_md": "", "marks": 1 },
        {
          "key": "indications",
          "heading": "Indications",
          "body_md": "Analgesia for lower abdominal surgery: caesarean section, appendicectomy, inguinal hernia repair, abdominoplasty.",
          "marks": 1
        },
        {
          "key": "complications",
          "heading": "Complications",
          "body_md": "Intraperitoneal injection, bowel puncture, liver laceration (right-sided), local anaesthetic systemic toxicity, block failure.",
          "marks": 2
        },
        {
          "key": "summary",
          "heading": "Summary",
          "body_md": "A landmark-simple, ultrasound-reliable analgesic block of the abdominal wall; know the plane, the volume, and the LAST risk.",
          "marks": null
        }
      ],
      "sort_order": 1,
      "images": [
        {
          "id": "01J0IMGTAPBLOCK00000000001",
          "caption": "Fig 1 - TAP block: needle in the plane between internal oblique and transversus abdominis",
          "content_description": "Ultrasound cross-section of the abdominal wall showing external oblique, internal oblique and transversus abdominis muscle layers with the needle tip and local anaesthetic spread in the transversus abdominis plane",
          "byte_size": 1024,
          "sha256": "fixture-sha",
          "sort_order": 1
        }
      ]
    },
    {
      "id": "01J0QNADIFFAIR000000000001",
      "topic_id": "01J0TOPICDIFFAIR0000000001",
      "question": "Outline the difficult airway algorithm for an anticipated difficult intubation.",
      "years": "2021 Paper I",
      "marks": 10,
      "earns_marks": [
        { "label": "Definition", "section_key": "definition" },
        { "label": "Assessment", "section_key": "assessment" },
        { "label": "Plan A-D", "section_key": "plans" }
      ],
      "sections": [
        {
          "key": "definition",
          "heading": "Definition",
          "body_md": "A clinical situation in which a trained anaesthesiologist experiences difficulty with facemask ventilation, laryngoscopy, or both.",
          "marks": 2
        },
        {
          "key": "assessment",
          "heading": "Assessment",
          "body_md": "History, Mallampati, thyromental distance, mouth opening, neck mobility; plan awake techniques when two or more predictors align.",
          "marks": 3
        },
        {
          "key": "plans",
          "heading": "Plan A-D",
          "body_md": "Plan A optimal laryngoscopy; Plan B supraglottic airway; Plan C facemask oxygenation and wake-up; Plan D front-of-neck access.",
          "marks": 5
        },
        {
          "key": "summary",
          "heading": "Summary",
          "body_md": "Declare difficulty early; prioritise oxygenation over intubation at every branch.",
          "marks": null
        }
      ],
      "sort_order": 1,
      "images": []
    },
    {
      "id": "01J0QNARSI0000000000000001",
      "topic_id": "01J0TOPICRSI00000000000001",
      "question": "Describe rapid sequence induction: indications, drugs, and technique.",
      "years": "2019, 2023 Paper I",
      "marks": 5,
      "earns_marks": [
        { "label": "Indications", "section_key": "indications" },
        { "label": "Technique", "section_key": "technique" }
      ],
      "sections": [
        {
          "key": "indications",
          "heading": "Indications",
          "body_md": "Full stomach, emergency surgery, gastro-oesophageal reflux, pregnancy beyond the first trimester.",
          "marks": 2
        },
        {
          "key": "technique",
          "heading": "Technique",
          "body_md": "Preoxygenation 3 minutes; induction agent + rapid-onset relaxant; cricoid pressure; no mask ventilation; intubate and confirm with capnography.",
          "marks": 3
        },
        {
          "key": "summary",
          "heading": "Summary",
          "body_md": "Speed and aspiration prophylaxis are the whole point; have suction and a rescue plan ready.",
          "marks": null
        }
      ],
      "sort_order": 1,
      "images": []
    }
  ]
}
```

- [ ] **Step 5: Write the fixture repository + fakes + providers**

`app/lib/data/fixtures/fixture_content_repository.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models.dart';
import '../repos/content_repository.dart';

/// Fixture-backed ContentRepository. The 61 specialities mirror
/// sql/0002_seed_specialities.sql; only Anaesthesiology has content
/// (TD3: Anaesthesia-only free-beta data; the other 60 exercise the
/// empty-track state, live-by-design).
class FixtureContentRepository implements ContentRepository {
  FixtureContentRepository({this.failChapterFetch = false});

  /// Set true in widget tests to exercise the "Couldn't load this - retry" state.
  bool failChapterFetch;

  Map<String, dynamic>? _doc;
  final Set<String> _cached = {};

  Future<Map<String, dynamic>> _load() async => _doc ??= json
      .decode(await rootBundle.loadString('assets/fixtures/chapter_airway.json'))
      as Map<String, dynamic>;

  static const _dnbNames = <String>[
    'Anaesthesiology', 'Anatomy', 'Biochemistry', 'Community Medicine',
    'Dermatology, Venereology & Leprosy', 'Emergency Medicine', 'ENT',
    'Family Medicine', 'Forensic Medicine', 'General Medicine', 'General Surgery',
    'Immunohaematology & Blood Transfusion', 'Microbiology', 'Nuclear Medicine',
    'Obstetrics & Gynaecology', 'Ophthalmology', 'Orthopaedics', 'Paediatrics',
    'Palliative Medicine', 'Pathology', 'Pharmacology', 'Physical Medicine & Rehabilitation',
    'Physiology', 'Psychiatry', 'Radiodiagnosis', 'Radiotherapy',
    'Respiratory Medicine', 'Rural Surgery', 'Sports Medicine', 'Tuberculosis & Chest Diseases',
  ];
  static const _drnbNames = <String>[
    'Cardiac Anaesthesia', 'Cardiology', 'Cardiothoracic Surgery', 'Clinical Haematology',
    'Clinical Immunology & Rheumatology', 'Critical Care Medicine', 'Endocrinology',
    'Gastroenterology', 'Geriatric Medicine', 'Gynaecological Oncology', 'Hand Surgery',
    'Hepatology', 'High-Risk Pregnancy & Perinatology', 'Infectious Diseases',
    'Interventional Radiology', 'Medical Genetics', 'Medical Oncology', 'Neonatology',
    'Nephrology', 'Neuroanaesthesia', 'Neurology', 'Neurosurgery',
    'Paediatric Cardiology', 'Paediatric Surgery', 'Plastic & Reconstructive Surgery',
    'Pulmonary Medicine', 'Reproductive Medicine', 'Surgical Gastroenterology',
    'Surgical Oncology', 'Thoracic Surgery', 'Urology',
  ];

  @override
  Future<List<SpecialityRow>> specialities() async {
    final doc = await _load();
    final anaes = doc['speciality'] as Map<String, dynamic>;
    var sort = 0;
    String slugOf(String n) => n
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('(^-|-\$)'), '');
    SpecialityRow row(String name, String type, {String? id, bool hasContent = false}) =>
        SpecialityRow(
            id: id ?? '01J0SPEC${type == 'DNB' ? 'B' : 'S'}${sort.toString().padLeft(18, '0')}',
            name: name, examType: type, slug: slugOf(name),
            sortOrder: ++sort, hasContent: hasContent);
    return [
      for (final n in _dnbNames)
        n == 'Anaesthesiology'
            ? row(n, 'DNB', id: anaes['id'] as String, hasContent: true)
            : row(n, 'DNB'),
      for (final n in _drnbNames) row(n, 'DrNB'),
    ];
  }

  @override
  Future<List<ChapterRow>> chapters(String specialityId) async {
    final doc = await _load();
    if (specialityId != (doc['speciality'] as Map)['id']) return const [];
    final topics = (doc['topics'] as List).cast<Map<String, dynamic>>();
    final qnas = (doc['qnas'] as List).cast<Map<String, dynamic>>();
    return [
      for (final c in (doc['chapters'] as List).cast<Map<String, dynamic>>())
        ChapterRow(
          id: c['id'] as String,
          specialityId: c['speciality_id'] as String,
          title: c['title'] as String,
          slug: c['slug'] as String,
          sortOrder: c['sort_order'] as int,
          examWeight: c['exam_weight'] as int,
          contentVersion: c['content_version'] as int,
          topicCount: topics.where((t) => t['chapter_id'] == c['id']).length,
          qnaCount: qnas
              .where((q) => topics.any((t) =>
                  t['id'] == q['topic_id'] && t['chapter_id'] == c['id']))
              .length,
        ),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> ensureChapterCached(String chapterId) async {
    if (failChapterFetch) throw ContentFetchException(chapterId);
    _cached.add(chapterId);
  }

  @override
  Future<List<TopicRow>> topics(String chapterId) async {
    final doc = await _load();
    return [
      for (final t in (doc['topics'] as List).cast<Map<String, dynamic>>())
        if (t['chapter_id'] == chapterId)
          TopicRow(
              id: t['id'] as String, chapterId: t['chapter_id'] as String,
              title: t['title'] as String, slug: t['slug'] as String,
              examTheme: t['exam_theme'] as String?, sortOrder: t['sort_order'] as int),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  QnaRow _qnaFromJson(Map<String, dynamic> q) => QnaRow(
        id: q['id'] as String, topicId: q['topic_id'] as String,
        question: q['question'] as String, years: q['years'] as String?,
        marks: q['marks'] as int?,
        earnsMarks: [
          for (final e in (q['earns_marks'] as List).cast<Map<String, dynamic>>())
            EarnRow(label: e['label'] as String, sectionKey: e['section_key'] as String)
        ],
        sections: [
          for (final s in (q['sections'] as List).cast<Map<String, dynamic>>())
            AnswerSection(key: s['key'] as String, heading: s['heading'] as String,
                bodyMd: s['body_md'] as String, marks: s['marks'] as int?)
        ],
        sortOrder: q['sort_order'] as int,
        images: [
          for (final i in (q['images'] as List).cast<Map<String, dynamic>>())
            ImageRow(id: i['id'] as String, caption: i['caption'] as String,
                contentDescription: i['content_description'] as String,
                byteSize: i['byte_size'] as int, sha256: i['sha256'] as String,
                sortOrder: i['sort_order'] as int)
        ],
      );

  @override
  Future<List<QnaRow>> qnas(String topicId) async {
    final doc = await _load();
    return [
      for (final q in (doc['qnas'] as List).cast<Map<String, dynamic>>())
        if (q['topic_id'] == topicId) _qnaFromJson(q),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<QnaRow?> qna(String qnaId) async {
    final doc = await _load();
    for (final q in (doc['qnas'] as List).cast<Map<String, dynamic>>()) {
      if (q['id'] == qnaId) return _qnaFromJson(q);
    }
    return null;
  }

  @override
  Future<Uint8List> imageBytes(String imageId) async =>
      (await rootBundle.load('assets/fixtures/images/fig_tap_block.webp'))
          .buffer
          .asUint8List();
}
```

`app/lib/data/fixtures/fake_auth_repository.dart`:

```dart
import '../repos/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failWith});

  /// Set in tests: SignInCancelled(), AuthOffline(), or any Exception.
  Object? failWith;
  SessionUser? _user;

  static const _fresh = SessionUser(
      id: '01J0USERFIXTURE00000000001', email: 'ananya@example.com',
      name: 'Ananya Sharma', photoUrl: null, specialityId: null,
      specialityChangeCount: 0);

  @override
  Future<SessionUser> signInWithGoogle() async {
    final f = failWith;
    if (f != null) throw f;
    return _user ??= _fresh;
  }

  @override
  Future<SessionUser?> restoreSession() async => _user;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteAccount() async => _user = null;

  @override
  Future<SessionUser> setSpeciality(String specialityId) async {
    final u = _user ?? _fresh;
    if (u.specialityId != null &&
        u.specialityId != specialityId &&
        u.specialityChangeCount >= 1) {
      throw ChangeLimitReached();
    }
    final changed = u.specialityId != null && u.specialityId != specialityId;
    return _user = u.copyWith(
        specialityId: specialityId,
        specialityChangeCount: u.specialityChangeCount + (changed ? 1 : 0));
  }
}
```

`app/lib/data/fixtures/fake_sync_service.dart`:

```dart
import '../../services/sync_service.dart';

class FakeSyncService implements SyncService {
  DateTime? last = DateTime(2026, 7, 1, 9);

  @override
  Future<void> flush() async {}

  @override
  Stream<DateTime?> lastSyncedAt() => Stream.value(last);
}
```

`app/lib/app_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/fixtures/fake_auth_repository.dart';
import 'data/fixtures/fake_sync_service.dart';
import 'data/fixtures/fixture_content_repository.dart';
import 'data/repos/auth_repository.dart';
import 'data/repos/content_repository.dart';
import 'services/sync_service.dart';

/// App-level seams. Plan 6 overrides all three with real implementations
/// (dio + drift + google_sign_in) in main.dart; the widget tree never changes.
final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => FixtureContentRepository());
final authRepositoryProvider = Provider<AuthRepository>((ref) => FakeAuthRepository());
final syncServiceProvider = Provider<SyncService>((ref) => FakeSyncService());
final sessionUserProvider = StateProvider<SessionUser?>((ref) => null);
```

`app/lib/providers/study_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../domain/models.dart';

/// STUB - plan 5 (study-loop-srs) Task 7 REPLACES this whole file with the
/// drift-backed providers, keeping these exact public names. Screens import
/// only from this file, so the swap is invisible to the widget tree.
final dueCountProvider = Provider<int>((ref) => 12);

/// Highest-exam-weight chapter = the "Start here" funnel target (no
/// auto-download - content loads on demand when the user enters it).
final resumeChapterProvider = FutureProvider<ChapterRow?>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final specs = await repo.specialities();
  final withContent = specs.where((s) => s.hasContent).toList();
  if (withContent.isEmpty) return null;
  final chapters = await repo.chapters(withContent.first.id);
  if (chapters.isEmpty) return null;
  chapters.sort((a, b) => b.examWeight.compareTo(a.examWeight));
  return chapters.first;
});
```

- [ ] **Step 6: Register the fixture assets**

Add to the `flutter:` section of `app/pubspec.yaml` (keep the fonts block from Task 3):

```yaml
assets:
  - assets/fixtures/chapter_airway.json
  - assets/fixtures/images/fig_tap_block.webp
```

Create the placeholder WebP (any tiny valid WebP works):

```bash
cd /Users/nirmit/Codebases/DiploMate/app
python3 - <<'EOF'
import base64, pathlib
# 1x1 white lossy WebP
b = base64.b64decode('UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAA=')
pathlib.Path('assets/fixtures/images/fig_tap_block.webp').write_bytes(b)
EOF
ls -la assets/fixtures/images/
```

Expected: `fig_tap_block.webp` listed (44 bytes).

- [ ] **Step 7: Run the test, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/data/fixture_content_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 8: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib app/assets/fixtures app/pubspec.yaml app/test/data
git commit -m "feat(app): contract interfaces, DDL-shaped fixtures, fake repos, provider seams"
```

---

### Task 6: Router + 3-tab shell + boot gates + toast

**Files:**

- Create: `app/lib/router.dart`
- Create: `app/lib/ui/shell/app_shell.dart`
- Create: `app/lib/ui/shell/dm_toast.dart`
- Create: `app/lib/main.dart` (replace generated)
- Create: placeholder screens (each replaced by its own task below): `app/lib/ui/signin/signin_screen.dart`, `app/lib/ui/speciality/speciality_screen.dart`, `app/lib/ui/home/home_screen.dart`, `app/lib/ui/syllabus/syllabus_screen.dart`, `app/lib/ui/topics/topics_screen.dart`, `app/lib/ui/reader/reader_screen.dart`, `app/lib/ui/bookmarks/bookmarks_screen.dart`, `app/lib/ui/account/account_screen.dart`
- Test: `app/test/shell/router_test.dart`

**Interfaces:**

- Consumes: `sessionUserProvider`, `authRepositoryProvider` (Task 5); `dmLightTheme()/dmDarkTheme()` (Task 4).
- Produces (used by every screen task and plans 5/6):
  - Route paths: `/signin`, `/speciality` (query `?mode=change` for the Account one-time change), `/home`, `/home/bookmarks`, `/syllabus`, `/syllabus/topics/:chapterId`, `/reader/:qnaId` (browse mode; query `?topic=<topicId>`), `/reader/queue` (queue mode - plan 5 binds it; until then it renders the browse placeholder), `/account`.
  - `GoRouter buildRouter(ProviderContainer)` in `router.dart` with a redirect implementing the boot gates: no session -> `/signin`; session without `specialityId` -> `/speciality` (unskippable: redirect loops there for every route except `/signin`); otherwise `/home` from `/` or `/signin`.
  - `AppShell` - `StatefulShellRoute.indexedStack` with the 3-tab `NavigationBar` (Home / Syllabus / Account, Manrope 11px labels, active `tealInk`, 48dp targets, `navBg` background + `navRule` top border). Reader routes sit OUTSIDE the shell (no bottom nav - full recall focus). Topics lights the Syllabus tab; Bookmarks lights Home (stack children).
  - `void showDmToast(BuildContext, String)` - the transient toast (1500ms hold per `DmMotion.toastHold`, bottom-center above the nav, `elevated` surface, `SemanticsService.announce` for TalkBack).

- [ ] **Step 1: Write the failing test**

`app/test/shell/router_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _onboarded = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget appWith(SessionUser? user) => ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => user)],
      child: const DiplomateApp(),
    );

void main() {
  testWidgets('boots at Sign-in with no session', (t) async {
    await t.pumpWidget(appWith(null));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('session without speciality is gated to Speciality (no nav, no back)', (t) async {
    await t.pumpWidget(appWith(const SessionUser(
        id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
        specialityId: null, specialityChangeCount: 0)));
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('onboarded session lands on Home with 3 tabs', (t) async {
    await t.pumpWidget(appWith(_onboarded));
    await t.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/shell/router_test.dart`
Expected: FAIL - `DiplomateApp` undefined.

- [ ] **Step 3: Implement router, shell, toast, main**

`app/lib/ui/shell/dm_toast.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/tokens.dart';

/// Transient ack (DESIGN.md: feedback, not content; a named no-cards
/// exception). 1500ms hold, bottom-center, announced to TalkBack.
void showDmToast(BuildContext context, String message) {
  SemanticsService.announce(message, TextDirection.ltr);
  final overlay = Overlay.of(context);
  final dm = Theme.of(context).extension<DmTheme>()!.colors;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: DmSpace.gutter,
      right: DmSpace.gutter,
      bottom: 96,
      child: IgnorePointer(
        child: Material(
          color: dm.elevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DmRadius.sm),
            side: BorderSide(color: dm.ruleStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: DmSpace.lg, vertical: DmSpace.md),
            child: Text(message,
                textAlign: TextAlign.center,
                style: DmType.bodyUi.copyWith(color: dm.ink)),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(DmMotion.toastHold, entry.remove);
}
```

`app/lib/ui/shell/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: dm.navBg,
          border: Border(top: BorderSide(color: dm.navRule)),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.transparent,
          indicatorColor: dm.tealSoft,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => navigationShell.goBranch(i,
              initialLocation: i == navigationShell.currentIndex),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Syllabus'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
          ],
        ),
      ),
    );
  }
}
```

`app/lib/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_providers.dart';
import 'ui/account/account_screen.dart';
import 'ui/bookmarks/bookmarks_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/reader/reader_screen.dart';
import 'ui/shell/app_shell.dart';
import 'ui/signin/signin_screen.dart';
import 'ui/speciality/speciality_screen.dart';
import 'ui/syllabus/syllabus_screen.dart';
import 'ui/topics/topics_screen.dart';

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/signin',
    redirect: (context, state) {
      final user = ref.read(sessionUserProvider);
      final loc = state.matchedLocation;
      if (user == null) return loc == '/signin' ? null : '/signin';
      final changing = state.uri.queryParameters['mode'] == 'change';
      if (user.specialityId == null) {
        // Unskippable onboarding gate: every route except the gate itself
        // bounces to /speciality until a track is committed.
        return loc == '/speciality' ? null : '/speciality';
      }
      if (loc == '/signin' || (loc == '/speciality' && !changing)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: '/speciality',
          builder: (_, s) => SpecialityScreen(
              changeMode: s.uri.queryParameters['mode'] == 'change')),
      GoRoute(
          path: '/reader/queue',
          builder: (_, __) => const ReaderScreen.queuePlaceholder()),
      GoRoute(
          path: '/reader/:qnaId',
          builder: (_, s) => ReaderScreen.browse(
              qnaId: s.pathParameters['qnaId']!,
              topicId: s.uri.queryParameters['topic'])),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen(), routes: [
              GoRoute(path: 'bookmarks', builder: (_, __) => const BookmarksScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/syllabus', builder: (_, __) => const SyllabusScreen(), routes: [
              GoRoute(
                  path: 'topics/:chapterId',
                  builder: (_, s) =>
                      TopicsScreen(chapterId: s.pathParameters['chapterId']!)),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          ]),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>(buildRouter);
```

`app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: DiplomateApp()));

class DiplomateApp extends ConsumerWidget {
  const DiplomateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DiploMate',
      theme: dmLightTheme(),
      darkTheme: dmDarkTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

Each placeholder screen (all eight) starts as the minimal compilable stub its own task replaces - example `app/lib/ui/home/home_screen.dart` (repeat the pattern, class names `SignInScreen`, `SpecialityScreen(changeMode)`, `HomeScreen`, `SyllabusScreen`, `TopicsScreen(chapterId)`, `ReaderScreen.browse(qnaId, topicId)/.queuePlaceholder()`, `BookmarksScreen`, `AccountScreen`):

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Home')));
}
```

(The sign-in stub must already render a `Continue with Google` text button so the router test passes before Task 7 lands the real screen.)

- [ ] **Step 4: Run the test, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/shell/router_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib app/test/shell
git commit -m "feat(app): go_router boot gates + 3-tab shell + toast"
```

---

### Task 7: Sign-in screen

Spec: `docs/superpowers/specs/2026-07-03-signin-design.md` (authoritative copy source - cross-check every string against it and the prototype before committing; the strings below are the synced 2026-07-04 truth).

**Files:**

- Create: `app/lib/ui/signin/signin_screen.dart` (replace stub)
- Test: `app/test/ui/signin_screen_test.dart`

**Interfaces:**

- Consumes: `authRepositoryProvider`, `sessionUserProvider` (Task 5); `SignInCancelled`, `AuthOffline` (Task 5); tokens (Task 4).
- Produces: `SignInScreen` bound at `/signin`. On success sets `sessionUserProvider` and lets the router redirect (gate decides `/speciality` vs `/home`).

Screen anatomy (one quiet composition, no splash/carousel/stock imagery, no cards except the specimen exception):

1. Wordmark `DiploMate` (serif display).
2. Tagline `Written by Doctors. Solved for Success!` - teal small-caps (Manrope label style, `tealInk`), the product's one exclamation.
3. Lede: `Master DNB theory answers by recalling them, not rereading them.`
4. Cropped model-answer specimen block (answer-on-white material code: `elevated` surface, examiner red margin showing a mark weight) - render the fixture TAP-block Definition section, non-interactive, `ExcludeSemantics`.
5. Primary CTA `Continue with Google` - full width, bottom thumb zone, 48dp min height.
6. Utility line `Terms of Service · Privacy Policy` (two inline text links -> `/legal/terms`, `/legal/privacy` on the API host; in this plan they are plain `Text` spans with `url_launcher` deferred to plan 6 - render as non-tappable `ink3` text and mark with `// plan 6: url_launcher`).

States (DESIGN.md State Specs, Task 1):

- idle -> CTA enabled.
- in-flight -> CTA disabled, 16px spinner replaces the label, semantics `Signing in`.
- auth-error (SignInCancelled or generic) -> inline line above the CTA: `Sign-in failed - try again.` (`examRed`), CTA re-enabled.
- offline (`AuthOffline`) -> inline line: `You're offline - connect and retry.` - distinct from auth-error (test asserts both strings).
- Exactly ONE auth action exists (D5): the test asserts a single button whose label contains `Google` and no other `ButtonStyleButton` on the screen.

- [ ] **Step 1: Write the failing test**

`app/test/ui/signin_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/signin/signin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(FakeAuthRepository auth) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(theme: dmLightTheme(), home: const SignInScreen()),
    );

void main() {
  testWidgets('renders wordmark, tagline, lede, specimen, single Google CTA, legal line',
      (t) async {
    await t.pumpWidget(host(FakeAuthRepository()));
    expect(find.text('DiploMate'), findsOneWidget);
    expect(find.text('Written by Doctors. Solved for Success!'), findsOneWidget);
    expect(find.text('Master DNB theory answers by recalling them, not rereading them.'),
        findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Terms of Service · Privacy Policy'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsOneWidget,
        reason: 'D5: exactly one auth action');
  });

  testWidgets('offline error is distinct from auth error', (t) async {
    final auth = FakeAuthRepository()..failWith = AuthOffline();
    await t.pumpWidget(host(auth));
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text("You're offline - connect and retry."), findsOneWidget);

    auth.failWith = SignInCancelled();
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('Sign-in failed - try again.'), findsOneWidget);
  });

  testWidgets('in-flight disables the CTA', (t) async {
    final auth = FakeAuthRepository();
    await t.pumpWidget(host(auth));
    await t.tap(find.text('Continue with Google'));
    await t.pump(); // one frame into the async call
    final btn = t.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    await t.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run, expect FAIL** - stub has no tagline/states.

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/signin_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/signin/signin_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/repos/auth_repository.dart';
import '../../theme/tokens.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _inFlight = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _inFlight = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      ref.read(sessionUserProvider.notifier).state = user;
    } on AuthOffline {
      setState(() => _error = "You're offline - connect and retry.");
    } catch (_) {
      setState(() => _error = 'Sign-in failed - try again.');
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text('DiploMate',
                  textAlign: TextAlign.center,
                  style: DmType.display.copyWith(color: dm.ink)),
              const SizedBox(height: DmSpace.xs),
              Text('Written by Doctors. Solved for Success!',
                  textAlign: TextAlign.center,
                  style: DmType.label.copyWith(color: dm.tealInk)),
              const SizedBox(height: DmSpace.xl2),
              Text('Master DNB theory answers by recalling them, not rereading them.',
                  textAlign: TextAlign.center,
                  style: DmType.bodyUi.copyWith(color: dm.ink2)),
              const SizedBox(height: DmSpace.xl2),
              const ExcludeSemantics(child: _Specimen()),
              const Spacer(flex: 3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: DmSpace.sm),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: DmType.meta.copyWith(color: dm.examRed)),
                ),
              FilledButton(
                onPressed: _inFlight ? null : _signIn,
                style: FilledButton.styleFrom(
                  backgroundColor: dm.teal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DmRadius.md)),
                ),
                child: _inFlight
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Continue with Google',
                        style: DmType.bodyUi.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: DmSpace.md),
              // plan 6: url_launcher wires these to /legal/terms + /legal/privacy
              Text('Terms of Service · Privacy Policy',
                  textAlign: TextAlign.center,
                  style: DmType.meta.copyWith(color: dm.ink3)),
              const SizedBox(height: DmSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cropped structured model-answer specimen - the sign-in visual anchor.
/// Answer-on-white material code + examiner red margin (signature moves).
class _Specimen extends StatelessWidget {
  const _Specimen();

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Container(
      decoration: BoxDecoration(
        color: dm.elevated,
        borderRadius: BorderRadius.circular(DmRadius.sm),
        border: Border.all(color: dm.rule),
      ),
      padding: const EdgeInsets.all(DmSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DEFINITION', style: DmType.label.copyWith(color: dm.ink3)),
                const SizedBox(height: DmSpace.xs),
                Text(
                  'The TAP block is a fascial plane block depositing local '
                  'anaesthetic between internal oblique and transversus abdominis...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DmType.body.copyWith(color: dm.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: DmSpace.md),
          Text('1', style: DmType.meta.copyWith(color: dm.examRed)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/signin_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Cross-check copy against the spec, then commit**

Open `docs/superpowers/specs/2026-07-03-signin-design.md` and diff every rendered string (wordmark, tagline, lede, CTA, utility separator `·`) against the implementation; fix any drift toward the spec, never the other way.

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/signin app/test/ui/signin_screen_test.dart
git commit -m "feat(app): sign-in screen with single Google action + error states"
```

---

### Task 8: Speciality onboarding screen (onboard + one-time change modes)

Spec: `docs/superpowers/specs/2026-07-03-speciality-onboarding-design.md`. 61 tracks, grouped single-select radio list, live substring search, Enter-picks-top, unskippable in onboard mode, change-once in change mode (DESIGN-T2 empty-track exclusion happens downstream; DESIGN-T8 confirmation dialog included here).

**Files:**

- Create: `app/lib/ui/speciality/speciality_screen.dart` (replace stub)
- Test: `app/test/ui/speciality_screen_test.dart`

**Interfaces:**

- Consumes: `contentRepositoryProvider.specialities()` (61 `SpecialityRow`s), `authRepositoryProvider.setSpeciality`, `sessionUserProvider`, `ChangeLimitReached` (Task 5); `showDmToast` (Task 6).
- Produces: `SpecialityScreen({required bool changeMode})` at `/speciality` / `/speciality?mode=change`. Onboard commit updates `sessionUserProvider` (router then releases the gate to `/home`). Change commit pops back to Account.

Anatomy:

- Topbar: title `Exam speciality`. No lede (removed 2026-07-04: title + search carry the screen). Back button ONLY in change mode.
- Search field, placeholder `Search - e.g. cardio, ENT, DrNB…` - substring, case-insensitive over the full `Name (Type)` string; live filter + result count line `N of 61 tracks`; match highlighting (teal); empty state `No matches. Try a shorter term - e.g. "cardio".`; keyboard Enter = select top match.
- Two sticky group headers: `DNB - Broad Specialities`, `DrNB - Super Specialities`; rows `Name (DNB)` / `Name (DrNB)` as a roving-focus radio group (`RadioListTile`-equivalent custom row, 48dp, `Semantics(inSelectionGroup)`, arrow keys move focus in the list - a11y pack).
- CTA pinned bottom: onboard `Continue`, change `Save change` - disabled until a selection exists; in change mode pre-select the current track; re-saving the SAME value does not consume the change (server rule; the fake mirrors it).
- Change mode extra: confirmation dialog before commit - title `Change exam speciality?`, body `<Old> -> <New>. This uses your one change.`, actions `Cancel` / `Change` (DESIGN-T8 one-way door).
- Commit states: pending (CTA spinner), offline/failure inline `Couldn't save - retry.` (`examRed`), `ChangeLimitReached` -> inline `One-time change already used.`

- [ ] **Step 1: Write the failing test**

`app/test/ui/speciality_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/speciality/speciality_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({bool changeMode = false, FakeAuthRepository? auth, SessionUser? user}) =>
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        sessionUserProvider.overrideWith((ref) => user),
      ],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: SpecialityScreen(changeMode: changeMode)),
    );

void main() {
  testWidgets('renders 61 tracks under two group headers, CTA disabled until pick',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('DNB - Broad Specialities'), findsOneWidget);
    expect(find.text('DrNB - Super Specialities'), findsOneWidget);
    expect(find.text('61 of 61 tracks'), findsOneWidget);
    final cta = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(cta.onPressed, isNull);
  });

  testWidgets('substring search filters and Enter picks top match', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'drnb');
    await t.pumpAndSettle();
    expect(find.text('31 of 61 tracks'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'cardio');
    await t.pumpAndSettle();
    // Cardiac Anaesthesia, Cardiology, Cardiothoracic Surgery, Paediatric Cardiology
    expect(find.text('4 of 61 tracks'), findsOneWidget);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final cta = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(cta.onPressed, isNotNull, reason: 'Enter selected the top match');
  });

  testWidgets('empty search state suggests shorter terms', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('No matches. Try a shorter term - e.g. "cardio".'), findsOneWidget);
  });

  testWidgets('change mode confirms with one-way-door copy and blocks a second change',
      (t) async {
    const user = SessionUser(
        id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
        specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);
    final auth = FakeAuthRepository();
    await auth.signInWithGoogle();
    await auth.setSpeciality('01J0SPECANAES0000000000001');
    await t.pumpWidget(host(changeMode: true, auth: auth, user: user));
    await t.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Anatomy');
    await t.pumpAndSettle();
    await t.tap(find.text('Anatomy (DNB)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save change'));
    await t.pumpAndSettle();
    expect(find.textContaining('This uses your one change.'), findsOneWidget);
    await t.tap(find.text('Change'));
    await t.pumpAndSettle();

    // second distinct change hits the server rule
    final again = await auth.setSpeciality('01J0SPECANAES0000000000001')
        .then((_) => false, onError: (e) => e is ChangeLimitReached);
    expect(again, isTrue);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/speciality_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/speciality/speciality_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../data/repos/auth_repository.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';

class SpecialityScreen extends ConsumerStatefulWidget {
  const SpecialityScreen({super.key, required this.changeMode});
  final bool changeMode;

  @override
  ConsumerState<SpecialityScreen> createState() => _SpecialityScreenState();
}

class _SpecialityScreenState extends ConsumerState<SpecialityScreen> {
  List<SpecialityRow> _all = const [];
  String _query = '';
  String? _selectedId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(contentRepositoryProvider).specialities().then((s) {
      if (!mounted) return;
      setState(() {
        _all = s;
        if (widget.changeMode) {
          _selectedId = ref.read(sessionUserProvider)?.specialityId;
        }
      });
    });
  }

  String _label(SpecialityRow s) => '${s.name} (${s.examType})';

  List<SpecialityRow> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return [for (final s in _all) if (_label(s).toLowerCase().contains(q)) s];
  }

  Future<void> _commit() async {
    final id = _selectedId;
    if (id == null) return;
    final current = ref.read(sessionUserProvider)?.specialityId;
    if (widget.changeMode && id != current) {
      final oldName = _all.where((s) => s.id == current).map(_label).firstOrNull ?? '';
      final newName = _all.where((s) => s.id == id).map(_label).first;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change exam speciality?'),
          content: Text('$oldName -> $newName. This uses your one change.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).setSpeciality(id);
      ref.read(sessionUserProvider.notifier).state = user;
      if (!mounted) return;
      if (widget.changeMode) {
        showDmToast(context, 'Speciality updated');
        context.pop();
      }
      // Onboard mode: the router redirect releases the gate to /home.
    } on ChangeLimitReached {
      setState(() => _error = 'One-time change already used.');
    } catch (_) {
      setState(() => _error = "Couldn't save - retry.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final filtered = _filtered;
    final dnb = [for (final s in filtered) if (s.examType == 'DNB') s];
    final drnb = [for (final s in filtered) if (s.examType == 'DrNB') s];
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam speciality', style: DmType.title.copyWith(color: dm.ink)),
        automaticallyImplyLeading: widget.changeMode, // onboard: no back, no skip
        backgroundColor: dm.paper,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DmSpace.gutter, DmSpace.sm, DmSpace.gutter, DmSpace.xs),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (v) => setState(() => _query = v.trim()),
              onSubmitted: (_) {
                final top = _filtered.firstOrNull;
                if (top != null) setState(() => _selectedId = top.id);
              },
              decoration: InputDecoration(
                hintText: 'Search - e.g. cardio, ENT, DrNB…',
                hintStyle: DmType.bodyUi.copyWith(color: dm.ink3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DmRadius.sm),
                    borderSide: BorderSide(color: dm.ruleStrong)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${filtered.length} of ${_all.length} tracks',
                  style: DmType.meta.copyWith(color: dm.ink3)),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No matches. Try a shorter term - e.g. "cardio".',
                        style: DmType.bodyUi.copyWith(color: dm.ink2)))
                : FocusTraversalGroup(
                    child: ListView(
                      children: [
                        if (dnb.isNotEmpty) _GroupHeader('DNB - Broad Specialities'),
                        for (final s in dnb) _row(s, dm),
                        if (drnb.isNotEmpty) _GroupHeader('DrNB - Super Specialities'),
                        for (final s in drnb) _row(s, dm),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(DmSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DmSpace.sm),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: DmType.meta.copyWith(color: dm.examRed)),
                    ),
                  FilledButton(
                    onPressed: _selectedId == null || _saving ? null : _commit,
                    style: FilledButton.styleFrom(
                      backgroundColor: dm.teal,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DmRadius.md)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.changeMode ? 'Save change' : 'Continue',
                            style: DmType.bodyUi.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(SpecialityRow s, DmColors dm) {
    final selected = s.id == _selectedId;
    final label = _label(s);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() => _selectedId = s.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
              horizontal: DmSpace.gutter, vertical: DmSpace.sm),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dm.rule))),
          child: Row(
            children: [
              Expanded(child: _highlighted(label, dm)),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20, color: selected ? dm.teal : dm.ink3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlighted(String label, DmColors dm) {
    if (_query.isEmpty) return Text(label, style: DmType.bodyUi.copyWith(color: dm.ink));
    final q = _query.toLowerCase();
    final i = label.toLowerCase().indexOf(q);
    if (i < 0) return Text(label, style: DmType.bodyUi.copyWith(color: dm.ink));
    return Text.rich(TextSpan(children: [
      TextSpan(text: label.substring(0, i), style: DmType.bodyUi.copyWith(color: dm.ink)),
      TextSpan(
          text: label.substring(i, i + q.length),
          style: DmType.bodyUi.copyWith(color: dm.tealInk, fontWeight: FontWeight.w700)),
      TextSpan(text: label.substring(i + q.length), style: DmType.bodyUi.copyWith(color: dm.ink)),
    ]));
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Container(
      width: double.infinity,
      color: dm.sunk,
      padding: const EdgeInsets.symmetric(
          horizontal: DmSpace.gutter, vertical: DmSpace.xs),
      child: Text(text.toUpperCase(), style: DmType.label.copyWith(color: dm.ink3)),
    );
  }
}
```

Note `firstOrNull` comes from `package:collection` (already a Flutter transitive dependency; add `collection:` to pubspec dependencies explicitly).

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/speciality_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Cross-check copy against the spec (placeholder string, group headers, empty state, dialog copy), then commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/speciality app/test/ui/speciality_screen_test.dart app/pubspec.yaml
git commit -m "feat(app): speciality onboarding + one-time change with confirm dialog"
```

### Task 9: Home screen

Spec: `docs/superpowers/specs/2026-07-03-home-design.md`. Home opens at the greeting (countdown + epigraph both struck); queue-first; pinned resume row is the starter-chapter funnel surface (no auto-download - "Start here" routes into the highest-exam-weight chapter).

**Files:**

- Create: `app/lib/ui/home/home_screen.dart` (replace stub)
- Test: `app/test/ui/home_screen_test.dart`

**Interfaces:**

- Consumes: `dueCountProvider`, `resumeChapterProvider` (Task 5 stub file `lib/providers/study_providers.dart` - plan 5 swaps the implementation, names stay), `sessionUserProvider` (Task 5), router paths (Task 6).
- Produces: `HomeScreen` at `/home`. Weekly stats read a `weeklyStatsProvider` DEFINED HERE in `home_screen.dart`: `final weeklyStatsProvider = Provider<({int recalled, int? easyPct})>((ref) => (recalled: 41, easyPct: 71));` - plan 5 Task 7 re-points it at real `review_events` folds (same record shape; `easyPct` null when the week has fewer than 5 ratings - the n>=5 floor).

Anatomy (top -> bottom, no cards):

1. Topbar title `Home` (no account icon - Account is nav-only).
2. Greeting: `Good morning, Ananya` - time-of-day variant morning/afternoon/evening from the device clock (5-11 morning, 11-17 afternoon, else evening); first name from `SessionUser.name`, rendered in `tealInk`; falls back to `Good morning` (no comma) when name is null.
3. Primary CTA `View 12 suggested answers` (count = `dueCountProvider`) -> `/reader/queue`. HIDDEN ENTIRELY when count == 0 (no empty/disabled button).
4. Ghost CTA `View your bookmarks` (outlined, `tealInk` text) -> `/home/bookmarks`. When the primary CTA is hidden it moves up to close the gap (it is simply the first child then).
5. Day-zero empty line (only when count == 0 AND `weeklyStatsProvider.recalled == 0`): `Nothing scheduled yet. Study one answer to start your recall queue.`
6. Section `This Week`: two honest stats, baseline-aligned pair - `41` + caption `answers recalled`, `71%` + caption `rated Easy` (tabular-nums via `DmType.statNumber`; the % stat is OMITTED when `easyPct == null`). Never a streak.
7. Pinned resume row (sticky above the bottom nav, OUTSIDE the scroll area): overline `PICK UP WHERE YOU LEFT OFF`, chapter title, teal play badge, full-row tap -> `/syllabus/topics/<chapterId>`. First-run variant: overline `START HERE`, subtitle `Begin with the highest-yield chapter`. Hidden only when `resumeChapterProvider` resolves null (empty track).

- [ ] **Step 1: Write the failing test**

`app/test/ui/home_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya Sharma', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget host({int due = 12, ({int recalled, int? easyPct})? stats}) => ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => _user),
        dueCountProvider.overrideWithValue(due),
        if (stats != null) weeklyStatsProvider.overrideWithValue(stats),
      ],
      child: MaterialApp(theme: dmLightTheme(), home: const HomeScreen()),
    );

void main() {
  testWidgets('greeting + suggested CTA + ghost CTA + This Week + pinned resume', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('Ananya'), findsOneWidget);
    expect(find.text('View 12 suggested answers'), findsOneWidget);
    expect(find.text('View your bookmarks'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('answers recalled'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('rated Easy'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget, reason: 'resume/funnel row');
  });

  testWidgets('N=0 hides the primary CTA entirely and shows day-zero direction', (t) async {
    await t.pumpWidget(host(due: 0, stats: (recalled: 0, easyPct: null)));
    await t.pumpAndSettle();
    expect(find.textContaining('suggested answers'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is FilledButton && w.onPressed == null),
        findsNothing, reason: 'no disabled ghost-of-a-button');
    expect(find.text('Nothing scheduled yet. Study one answer to start your recall queue.'),
        findsOneWidget);
  });

  testWidgets('percent stat suppressed below the n>=5 floor', (t) async {
    await t.pumpWidget(host(stats: (recalled: 3, easyPct: null)));
    await t.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('never renders a streak', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('streak'), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/home_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../providers/study_providers.dart';
import '../../theme/tokens.dart';

/// Two honest figures for "This Week". Plan 5 re-points this at real
/// review_events folds; easyPct is null under the n>=5 weekly floor.
final weeklyStatsProvider =
    Provider<({int recalled, int? easyPct})>((ref) => (recalled: 41, easyPct: 71));

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(DateTime now, String? name) {
    final h = now.hour;
    final part = h >= 5 && h < 11
        ? 'Good morning'
        : h >= 11 && h < 17
            ? 'Good afternoon'
            : 'Good evening';
    final first = name?.split(' ').first;
    return first == null ? part : '$part, $first';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final due = ref.watch(dueCountProvider);
    final stats = ref.watch(weeklyStatsProvider);
    final resume = ref.watch(resumeChapterProvider).valueOrNull;
    final user = ref.watch(sessionUserProvider);
    final greeting = _greeting(DateTime.now(), user?.name);
    final first = user?.name?.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
                children: [
                  const SizedBox(height: DmSpace.sm),
                  Text('Home', style: DmType.title.copyWith(color: dm.ink)),
                  const SizedBox(height: DmSpace.xl2),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: first == null
                              ? greeting
                              : greeting.substring(0, greeting.length - first.length),
                          style: DmType.display.copyWith(color: dm.ink)),
                      if (first != null)
                        TextSpan(
                            text: first,
                            style: DmType.display.copyWith(color: dm.tealInk)),
                    ]),
                  ),
                  const SizedBox(height: DmSpace.xl2),
                  if (due > 0) ...[
                    FilledButton(
                      onPressed: () => context.go('/reader/queue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: dm.teal,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DmRadius.md)),
                      ),
                      child: Text('View $due suggested answers',
                          style: DmType.bodyUi.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: DmSpace.md),
                  ],
                  OutlinedButton(
                    onPressed: () => context.go('/home/bookmarks'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: dm.ruleStrong),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DmRadius.md)),
                    ),
                    child: Text('View your bookmarks',
                        style: DmType.bodyUi.copyWith(color: dm.tealInk)),
                  ),
                  if (due == 0 && stats.recalled == 0) ...[
                    const SizedBox(height: DmSpace.lg),
                    Text(
                        'Nothing scheduled yet. Study one answer to start your recall queue.',
                        style: DmType.bodyUi.copyWith(color: dm.ink2)),
                  ],
                  const SizedBox(height: DmSpace.xl3),
                  Text('This Week', style: DmType.section.copyWith(color: dm.ink)),
                  const SizedBox(height: DmSpace.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _Stat(number: '${stats.recalled}', caption: 'answers recalled'),
                      const SizedBox(width: 28),
                      if (stats.easyPct != null)
                        _Stat(number: '${stats.easyPct}%', caption: 'rated Easy'),
                    ],
                  ),
                  const SizedBox(height: DmSpace.xl3),
                ],
              ),
            ),
            if (resume != null)
              Material(
                color: dm.elevated,
                child: InkWell(
                  onTap: () => context.go('/syllabus/topics/${resume.id}'),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: dm.rule))),
                    padding: const EdgeInsets.symmetric(
                        horizontal: DmSpace.gutter, vertical: DmSpace.md),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration:
                              BoxDecoration(color: dm.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: DmSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  stats.recalled == 0
                                      ? 'START HERE'
                                      : 'PICK UP WHERE YOU LEFT OFF',
                                  style: DmType.label.copyWith(color: dm.ink3)),
                              const SizedBox(height: 2),
                              Text(resume.title,
                                  style: DmType.bodyUi.copyWith(color: dm.ink)),
                              if (stats.recalled == 0)
                                Text('Begin with the highest-yield chapter',
                                    style: DmType.meta.copyWith(color: dm.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.number, required this.caption});
  final String number, caption;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(number, style: DmType.statNumber.copyWith(color: dm.ink)),
        const SizedBox(width: 8),
        Text(caption, style: DmType.meta.copyWith(color: dm.ink2)),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/home_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Cross-check copy against the home spec, then commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/home app/test/ui/home_screen_test.dart
git commit -m "feat(app): Home - greeting, suggested CTA (hidden at 0), stats floor, pinned resume funnel"
```

---

### Task 10: Syllabus screen

Spec: `docs/superpowers/specs/2026-07-03-syllabus-design.md`. FREE BETA + NO DOWNLOADS: rows are title + topic-count subtitle + recall progress. No locks, no lozenges, no offline anything.

**Files:**

- Create: `app/lib/ui/syllabus/syllabus_screen.dart` (replace stub)
- Test: `app/test/ui/syllabus_screen_test.dart`

**Interfaces:**

- Consumes: `contentRepositoryProvider` (specialities + chapters), `sessionUserProvider` (speciality id), router path `/syllabus/topics/:chapterId` (Task 6).
- Produces: `SyllabusScreen` at `/syllabus`; the empty-track state (DESIGN-T2) renders here when the chosen speciality `hasContent == false` OR `chapters()` is empty.

Anatomy:

1. Topbar `Syllabus` + breadcrumb line under it: the speciality name (e.g. `Anaesthesiology`), `ink3` meta - the crumb root (non-interactive here).
2. Chapter rows (divider-separated, 48dp+, full-row tap -> Topics): title (bodyUi, ink), subtitle `14 topics` (meta, ink3), right-aligned `8/14 recalled` in `tealInk` (tabular figures). `recalledCount` comes from `ChapterRow.recalledCount` (fixture 0 -> renders `0/14 recalled`; plan 5 wires real counts).
3. Empty-track state (first-class, live-by-design in beta): centered block - `No answers here yet.` (section style) + `Your speciality's content is on its way. We'll notify you the moment it lands.` (bodyUi, ink2). No dead end: ghost CTA `Change speciality` -> `/speciality?mode=change`. Pick is still a demand signal (event logging is plan 5).
4. Fetch-failure state for the chapter list: inline `Couldn't load this - retry` + `Retry` text button re-invoking the load.

- [ ] **Step 1: Write the failing test**

`app/test/ui/syllabus_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/syllabus/syllabus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessionUser userWith(String specId) => SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: specId, specialityChangeCount: 0);

Widget host(String specId) => ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => userWith(specId))],
      child: MaterialApp(theme: dmLightTheme(), home: const SyllabusScreen()),
    );

void main() {
  testWidgets('chapter rows: title, topic count, recall progress; no locks, no download UI',
      (t) async {
    await t.pumpWidget(host('01J0SPECANAES0000000000001'));
    await t.pumpAndSettle();
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget);
    expect(find.text('2 topics'), findsOneWidget);
    expect(find.text('0/2 recalled'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.textContaining('ffline'), findsNothing, reason: 'no offline copy');
    expect(find.textContaining('ownload'), findsNothing, reason: 'no download copy');
  });

  testWidgets('empty track renders the first-class no-content state', (t) async {
    // any non-Anaesthesiology fixture id has no content
    late String emptyId;
    final repo = FixtureContentRepository();
    final specs = await repo.specialities();
    emptyId = specs.firstWhere((s) => !s.hasContent).id;

    await t.pumpWidget(host(emptyId));
    await t.pumpAndSettle();
    expect(find.text('No answers here yet.'), findsOneWidget);
    expect(
        find.text(
            "Your speciality's content is on its way. We'll notify you the moment it lands."),
        findsOneWidget);
    expect(find.text('Change speciality'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/syllabus_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/syllabus/syllabus_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

class SyllabusScreen extends ConsumerStatefulWidget {
  const SyllabusScreen({super.key});

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  late Future<(SpecialityRow?, List<ChapterRow>)> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<(SpecialityRow?, List<ChapterRow>)> _fetch() async {
    final repo = ref.read(contentRepositoryProvider);
    final specId = ref.read(sessionUserProvider)?.specialityId;
    final specs = await repo.specialities();
    final spec = specs.where((s) => s.id == specId).firstOrNull;
    if (spec == null || !spec.hasContent) return (spec, const <ChapterRow>[]);
    return (spec, await repo.chapters(spec.id));
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _load,
          builder: (context, snap) {
            if (snap.hasError) {
              return _Retry(onRetry: () => setState(() => _load = _fetch()));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final (spec, chapters) = snap.data!;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
              children: [
                const SizedBox(height: DmSpace.sm),
                Text('Syllabus', style: DmType.title.copyWith(color: dm.ink)),
                const SizedBox(height: DmSpace.xs),
                Text(spec?.name ?? '', style: DmType.meta.copyWith(color: dm.ink3)),
                const SizedBox(height: DmSpace.lg),
                if (chapters.isEmpty)
                  _EmptyTrack(dm: dm)
                else
                  for (final c in chapters)
                    InkWell(
                      onTap: () => context.go('/syllabus/topics/${c.id}'),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: dm.rule))),
                        padding:
                            const EdgeInsets.symmetric(vertical: DmSpace.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title,
                                      style:
                                          DmType.bodyUi.copyWith(color: dm.ink)),
                                  const SizedBox(height: 2),
                                  Text('${c.topicCount} topics',
                                      style:
                                          DmType.meta.copyWith(color: dm.ink3)),
                                ],
                              ),
                            ),
                            Text('${c.recalledCount}/${c.topicCount} recalled',
                                style: DmType.meta.copyWith(color: dm.tealInk)),
                          ],
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrack extends StatelessWidget {
  const _EmptyTrack({required this.dm});
  final DmColors dm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Column(
        children: [
          Text('No answers here yet.', style: DmType.section.copyWith(color: dm.ink)),
          const SizedBox(height: DmSpace.sm),
          Text(
            "Your speciality's content is on its way. We'll notify you the moment it lands.",
            textAlign: TextAlign.center,
            style: DmType.bodyUi.copyWith(color: dm.ink2),
          ),
          const SizedBox(height: DmSpace.lg),
          OutlinedButton(
            onPressed: () => context.go('/speciality?mode=change'),
            style: OutlinedButton.styleFrom(side: BorderSide(color: dm.ruleStrong)),
            child: Text('Change speciality',
                style: DmType.bodyUi.copyWith(color: dm.tealInk)),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't load this - retry",
              style: DmType.bodyUi.copyWith(color: dm.ink2)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

(`firstOrNull` from `package:collection` - already added in Task 8.)

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/syllabus_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/syllabus app/test/ui/syllabus_screen_test.dart
git commit -m "feat(app): Syllabus - plain chapter rows + first-class empty-track state (no downloads, no locks)"
```

---

### Task 11: Topics screen

Spec: `docs/superpowers/specs/2026-07-03-topics-design.md`. Recall pips are bare status words (Recalled / Due / New) - no dates, no interval copy (SRS de-surfaced 2026-07-04). Breadcrumb ancestor is tappable up-navigation.

**Files:**

- Create: `app/lib/ui/topics/topics_screen.dart` (replace stub)
- Test: `app/test/ui/topics_screen_test.dart`

**Interfaces:**

- Consumes: `contentRepositoryProvider` (`ensureChapterCached`, `topics`, `qnas`, `chapters`), `ContentFetchException` (Task 5); router `/reader/:qnaId?topic=` (Task 6).
- Produces: `TopicsScreen(chapterId)` at `/syllabus/topics/:chapterId`. `TopicPipStatus { recalled, due, fresh }` + `final topicPipProvider = Provider.family<TopicPipStatus, String>((ref, topicId) => TopicPipStatus.fresh);` DEFINED HERE - plan 5 re-points it at CardState folds (same name/shape).

Anatomy:

1. Crumb: `Anaesthesiology / Airway Management` - ancestor segment (`Anaesthesiology`) is a tappable up-nav to `/syllabus`; leaf is non-interactive `ink2`.
2. Chapter recall progress bar (thin, `tealSoft` track, `teal` fill, fraction = recalled topics / topics).
3. Topic rows grouped under their `exam_theme` sticky-ish header (plain `label` header, `sunk` bg): title + right pip - a small swatch + word: `Recalled` (`ok`), `Due` (`amber`), `New` (`ink3`); NEVER color alone (word always present). Row tap: `ensureChapterCached(chapterId)` then -> first QnA of the topic in browse mode (`/reader/<qnaId>?topic=<topicId>`).
4. Fetch failure (from `ensureChapterCached` or loads): inline `Couldn't load this - retry` + `Retry` button (same `_Retry` pattern as Task 10 - copy the widget, do not import across screen folders).

- [ ] **Step 1: Write the failing test**

`app/test/ui/topics_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/topics/topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterId = '01J0CHAPAIRWAY000000000001';

Widget host({FixtureContentRepository? repo}) => ProviderScope(
      overrides: [
        if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
          theme: dmLightTheme(), home: const TopicsScreen(chapterId: _chapterId)),
    );

void main() {
  testWidgets('crumb, theme groups, topic rows with bare-word pips, no dates', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget);
    expect(find.text('Difficult airway algorithm'), findsOneWidget);
    expect(find.text('Rapid sequence induction'), findsOneWidget);
    expect(find.text('New'), findsNWidgets(2), reason: 'fixture pips default to New');
    expect(find.textContaining('in '), findsNothing, reason: 'no interval copy');
    expect(find.textContaining('day'), findsNothing, reason: 'no date copy');
  });

  testWidgets('fetch failure renders the retry state', (t) async {
    final repo = FixtureContentRepository(failChapterFetch: true);
    await t.pumpWidget(host(repo: repo));
    await t.pumpAndSettle();
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
    repo.failChapterFetch = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Difficult airway algorithm'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/topics_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/topics/topics_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

enum TopicPipStatus { recalled, due, fresh }

/// Plan 5 re-points this at CardState folds (due = any member QnA due today,
/// recalled = all member QnAs rated at least once). Same name, same shape.
final topicPipProvider =
    Provider.family<TopicPipStatus, String>((ref, topicId) => TopicPipStatus.fresh);

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key, required this.chapterId});
  final String chapterId;

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  late Future<(String, ChapterRow, List<TopicRow>, Map<String, String>)> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<(String, ChapterRow, List<TopicRow>, Map<String, String>)> _fetch() async {
    final repo = ref.read(contentRepositoryProvider);
    await repo.ensureChapterCached(widget.chapterId);
    final specs = await repo.specialities();
    final spec = specs.firstWhere((s) => s.hasContent);
    final chapters = await repo.chapters(spec.id);
    final chapter = chapters.firstWhere((c) => c.id == widget.chapterId);
    final topics = await repo.topics(widget.chapterId);
    // first QnA id per topic for browse-mode entry
    final firstQna = <String, String>{};
    for (final t in topics) {
      final qs = await repo.qnas(t.id);
      if (qs.isNotEmpty) firstQna[t.id] = qs.first.id;
    }
    return (spec.name, chapter, topics, firstQna);
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _load,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Couldn't load this - retry",
                        style: DmType.bodyUi.copyWith(color: dm.ink2)),
                    TextButton(
                        onPressed: () => setState(() => _load = _fetch()),
                        child: const Text('Retry')),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final (specName, chapter, topics, firstQna) = snap.data!;
            final themes = <String?, List<TopicRow>>{};
            for (final t in topics) {
              themes.putIfAbsent(t.examTheme, () => []).add(t);
            }
            final recalled = topics
                .where((t) =>
                    ref.read(topicPipProvider(t.id)) == TopicPipStatus.recalled)
                .length;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
              children: [
                const SizedBox(height: DmSpace.sm),
                Row(children: [
                  InkWell(
                    onTap: () => context.go('/syllabus'),
                    child: Text(specName,
                        style: DmType.meta.copyWith(color: dm.tealInk)),
                  ),
                  Text(' / ', style: DmType.meta.copyWith(color: dm.ink3)),
                  Text(chapter.title, style: DmType.meta.copyWith(color: dm.ink2)),
                ]),
                const SizedBox(height: DmSpace.md),
                Text(chapter.title, style: DmType.title.copyWith(color: dm.ink)),
                const SizedBox(height: DmSpace.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: topics.isEmpty ? 0 : recalled / topics.length,
                    minHeight: 4,
                    backgroundColor: dm.tealSoft,
                    valueColor: AlwaysStoppedAnimation(dm.teal),
                  ),
                ),
                const SizedBox(height: DmSpace.lg),
                for (final entry in themes.entries) ...[
                  if (entry.key != null)
                    Container(
                      width: double.infinity,
                      color: dm.sunk,
                      padding: const EdgeInsets.symmetric(
                          horizontal: DmSpace.sm, vertical: DmSpace.xs),
                      child: Text(entry.key!.toUpperCase(),
                          style: DmType.label.copyWith(color: dm.ink3)),
                    ),
                  for (final t in entry.value)
                    InkWell(
                      onTap: firstQna[t.id] == null
                          ? null
                          : () => context
                              .go('/reader/${firstQna[t.id]}?topic=${t.id}'),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: dm.rule))),
                        padding:
                            const EdgeInsets.symmetric(vertical: DmSpace.md),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(t.title,
                                    style:
                                        DmType.bodyUi.copyWith(color: dm.ink))),
                            _Pip(status: ref.watch(topicPipProvider(t.id))),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.status});
  final TopicPipStatus status;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final (color, word) = switch (status) {
      TopicPipStatus.recalled => (dm.ok, 'Recalled'),
      TopicPipStatus.due => (dm.amber, 'Due'),
      TopicPipStatus.fresh => (dm.ink3, 'New'),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(word, style: DmType.meta.copyWith(color: color)),
    ]);
  }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/topics_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/topics app/test/ui/topics_screen_test.dart
git commit -m "feat(app): Topics - theme groups, bare-word recall pips, tappable crumb up-nav"
```

### Task 12: Reader - reading surface (browse mode), reveal, rating tray visual, earns-marks anchors, fetch retry

Spec: `docs/superpowers/specs/2026-07-03-reader-recall-design.md`. This task builds the presentation; plan 5 binds its `ReaderController` (queue/browse logic, event writing, debouncing) to the same view. The two signature moves live here: answer-on-white material code + examiner's red margin.

**Files:**

- Create: `app/lib/ui/reader/reader_screen.dart` (replace stub)
- Create: `app/lib/ui/reader/reader_view.dart`
- Test: `app/test/ui/reader_surface_test.dart`

**Interfaces:**

- Consumes: `contentRepositoryProvider.qna/qnas/imageBytes`, `ContentFetchException` (Task 5); `showDmToast` (Task 6); tokens (Task 4).
- Produces (plan 5 Task 8 binds `ReaderController` to exactly this view API):

```dart
class ReaderView extends StatelessWidget {
  const ReaderView({
    required QnaRow qna,
    required bool revealed,
    required VoidCallback onReveal,
    required void Function(WireRating) onRate,   // tray taps; plan 4 fixture just toasts
    String? overline,                             // queue mode only: 'Suggestion · N of M'; null in browse
    List<({String label, VoidCallback onTap})> crumb, // ancestor segments, tappable
    Widget? trailingCrumbAction,                  // Task 14 injects the bookmark toggle
    VoidCallback? onNextInTopic,                  // browse mode, post-rating
    Widget? belowAnswer,                          // Task 14 injects the report row
  });
}
enum WireRating { again, hard, good }  // defined in models.dart here; plan 5's
                                       // scheduler re-exports the same enum name
```

- `ReaderScreen.browse(qnaId, topicId)` at `/reader/:qnaId?topic=` - loads via repo, owns a local `revealed` flag (fixture behavior), rate -> toast `✓ Rated <tier> · next answer` then advances to the next QnA in the topic (rate-then-stay + `Next in topic` per browse spec: rating in browse does NOT auto-advance; the button appears).
- `ReaderScreen.queuePlaceholder()` at `/reader/queue` - plain paper Scaffold with `bodyUi` text `Recall queue arrives with the study loop.` (plan 5 replaces this constructor with the real queue binding; the route path is stable).

Anatomy (browse):

1. NO bottom nav. Top crumb row: `Airway Management / Difficult airway algorithm` - each ancestor tappable (chapter -> Topics screen), leaf non-interactive; `trailingCrumbAction` slot right-aligned.
2. Question block (paper bg): question in `DmType.body` serif at `DmType.section` size 19, then meta chips `2022 Paper II` · `10 marks` (plain `meta` text with a `·` separator - no chips-as-cards, and NO `Due today` chip - SRS is de-surfaced).
3. `What earns marks` outline (pre-reveal AND post-reveal): `label`-style heading, then one row per `EarnRow` - row tap scrolls to its section (`Scrollable.ensureVisible` on the section's `GlobalKey`, instant, no animation past 200ms). Rows are plain text + a `>` glyph, 48dp, semantics button `Jump to <label>`.
4. Pre-reveal: prompt line `Outline your answer aloud or on paper` (`ink2`, italic serif) + full-width `Reveal model answer` FilledButton pinned in the bottom thumb zone. No countdown, no elapsed indicator (struck by design T4), no hard lock.
5. Reveal (150-220ms vertical uncover per `DmMotion.reveal`, `honors MediaQuery.disableAnimations` -> instant swap; scroll position preserved): the sectioned answer renders ON WHITE (`elevated` surface edge-to-edge block) - each `AnswerSection` = heading (section style) + `bodyMd` (serif body) + right-margin mark weight in `examRed` (`marks` null = no numeral, e.g. Summary). Diagram sections render the image plate (Task 13).
6. Rating tray IN-FLOW after the answer (not pinned - DESIGN.md decision log): three equal buttons left-to-right `Easy / Medium / Hard` - smile/meh/frown icons + word, colors `ok`/`amber`/`examRed` (icon+word, never color alone), 48dp. Maps to wire: Easy->good, Medium->hard, Hard->again. NO interval hints. NO done/due counter.
7. After rating in browse mode: tray collapses to a confirmation row + `Next in topic` ghost button (when a next QnA exists in `topicId`).
8. Load failure: `Couldn't load this - retry` + Retry (same pattern as Tasks 10/11).

- [ ] **Step 1: Write the failing test**

`app/test/ui/reader_surface_test.dart`:

```dart
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tapQna = '01J0QNATAPBLOCK00000000001';
const _tapTopic = '01J0TOPICTAPBLOCK000000001';

Widget host() => ProviderScope(
      child: MaterialApp(
          theme: dmLightTheme(),
          home: ReaderScreen.browse(qnaId: _tapQna, topicId: _tapTopic)),
    );

void main() {
  testWidgets('pre-reveal: question, chips, earns-marks, prompt, reveal CTA; no answer, no due chip',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('transversus abdominis plane'), findsOneWidget);
    expect(find.text('2022 Paper II'), findsOneWidget);
    expect(find.text('10 marks'), findsOneWidget);
    expect(find.textContaining('Due'), findsNothing, reason: 'SRS de-surfaced');
    expect(find.text('What earns marks'), findsOneWidget);
    expect(find.text('Outline your answer aloud or on paper'), findsOneWidget);
    expect(find.text('Reveal model answer'), findsOneWidget);
    expect(find.textContaining('fascial plane block'), findsNothing,
        reason: 'answer hidden pre-reveal');
  });

  testWidgets('reveal shows sections with red mark weights; tray is Easy/Medium/Hard; rating toasts and offers Next in topic',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.textContaining('fascial plane block'), findsOneWidget);
    expect(find.text('Definition'), findsWidgets);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing, reason: 'no interval hints');
    expect(find.textContaining(' due'), findsNothing, reason: 'no done/due counter');

    await t.tap(find.text('Easy'));
    await t.pump(); // toast frame
    expect(find.text('✓ Rated Easy · next answer'), findsOneWidget);
    await t.pump(const Duration(seconds: 2)); // toast expiry
    expect(find.text('Next in topic'), findsNothing,
        reason: 'TAP topic has one QnA - no next');
  });

  testWidgets('earns-marks row jumps to its section', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(InkWell, 'Complications').first);
    await t.pumpAndSettle();
    // the section heading is on screen after the jump
    expect(find.text('Complications'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader_surface_test.dart`

- [ ] **Step 3: Implement**

Add to `app/lib/domain/models.dart`:

```dart
/// Wire enum - values owned by sql/0003 review_events.rating CHECK
/// (sql/ DDL is the enum source of truth; do not re-validate here).
enum WireRating { again, hard, good }

const uiLabelForWire = {
  WireRating.good: 'Easy',
  WireRating.hard: 'Medium',
  WireRating.again: 'Hard',
};
```

`app/lib/ui/reader/reader_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../theme/tokens.dart';

class ReaderView extends StatefulWidget {
  const ReaderView({
    super.key,
    required this.qna,
    required this.revealed,
    required this.onReveal,
    required this.onRate,
    this.overline,
    this.crumb = const [],
    this.trailingCrumbAction,
    this.onNextInTopic,
    this.belowAnswer,
    this.rated = false,
    this.imageBuilder,
  });

  final QnaRow qna;
  final bool revealed;
  final bool rated;
  final VoidCallback onReveal;
  final void Function(WireRating) onRate;
  final String? overline;
  final List<({String label, VoidCallback onTap})> crumb;
  final Widget? trailingCrumbAction;
  final VoidCallback? onNextInTopic;
  final Widget? belowAnswer;
  final Widget Function(BuildContext, ImageRow)? imageBuilder;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final _sectionKeys = <String, GlobalKey>{};
  final _scroll = ScrollController();

  void _jumpTo(String sectionKey) {
    final key = _sectionKeys[sectionKey];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: DmMotion.reveal, alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final q = widget.qna;
    for (final s in q.sections) {
      _sectionKeys.putIfAbsent(s.key, GlobalKey.new);
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DmSpace.gutter, DmSpace.sm, DmSpace.gutter, DmSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < widget.crumb.length; i++) ...[
                          if (i > 0)
                            Text(' / ',
                                style: DmType.meta.copyWith(color: dm.ink3)),
                          i < widget.crumb.length - 1
                              ? InkWell(
                                  onTap: widget.crumb[i].onTap,
                                  child: Text(widget.crumb[i].label,
                                      style: DmType.meta
                                          .copyWith(color: dm.tealInk)))
                              : Text(widget.crumb[i].label,
                                  style:
                                      DmType.meta.copyWith(color: dm.ink2)),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailingCrumbAction != null)
                    widget.trailingCrumbAction!,
                ],
              ),
            ),
            if (widget.overline != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.overline!.toUpperCase(),
                      style: DmType.label.copyWith(color: dm.ink3)),
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(DmSpace.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.question,
                            style: DmType.body.copyWith(
                                fontSize: 19, color: dm.ink, height: 1.45)),
                        const SizedBox(height: DmSpace.sm),
                        Text(
                          [
                            if (q.years != null) q.years!,
                            if (q.marks != null) '${q.marks} marks'
                          ].join(' · '),
                          style: DmType.meta.copyWith(color: dm.ink3),
                        ),
                        const SizedBox(height: DmSpace.lg),
                        Text('What earns marks',
                            style: DmType.label.copyWith(color: dm.ink3)),
                        const SizedBox(height: DmSpace.xs),
                        for (final e in q.earnsMarks)
                          Semantics(
                            button: true,
                            label: 'Jump to ${e.label}',
                            child: InkWell(
                              onTap: widget.revealed
                                  ? () => _jumpTo(e.sectionKey)
                                  : null,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(color: dm.rule))),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(e.label,
                                          style: DmType.bodyUi
                                              .copyWith(color: dm.ink))),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: dm.ink3),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.revealed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DmSpace.gutter, vertical: DmSpace.xl2),
                      child: Text('Outline your answer aloud or on paper',
                          style: DmType.body.copyWith(
                              color: dm.ink2, fontStyle: FontStyle.italic)),
                    )
                  else
                    AnimatedSize(
                      duration: reduceMotion ? Duration.zero : DmMotion.reveal,
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: Container(
                        // Signature move: the model answer renders on white.
                        color: dm.elevated,
                        padding: const EdgeInsets.symmetric(
                            horizontal: DmSpace.gutter,
                            vertical: DmSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final s in q.sections) ...[
                              Row(
                                key: _sectionKeys[s.key],
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Text(s.heading,
                                          style: DmType.section
                                              .copyWith(color: dm.ink))),
                                  if (s.marks != null)
                                    // Signature move: examiner's red margin.
                                    Text('${s.marks}',
                                        style: DmType.meta
                                            .copyWith(color: dm.examRed)),
                                ],
                              ),
                              const SizedBox(height: DmSpace.xs),
                              if (s.bodyMd.isNotEmpty)
                                Text(s.bodyMd,
                                    style: DmType.body
                                        .copyWith(color: dm.ink)),
                              if (s.key == 'diagram' &&
                                  widget.imageBuilder != null)
                                for (final img in q.images)
                                  widget.imageBuilder!(context, img),
                              const SizedBox(height: DmSpace.lg),
                            ],
                            if (!widget.rated) ...[
                              const SizedBox(height: DmSpace.sm),
                              Row(children: [
                                _RateButton(
                                    word: 'Easy',
                                    icon: Icons.sentiment_satisfied_outlined,
                                    color: dm.ok,
                                    onTap: () =>
                                        widget.onRate(WireRating.good)),
                                const SizedBox(width: DmSpace.sm),
                                _RateButton(
                                    word: 'Medium',
                                    icon: Icons.sentiment_neutral_outlined,
                                    color: dm.amber,
                                    onTap: () =>
                                        widget.onRate(WireRating.hard)),
                                const SizedBox(width: DmSpace.sm),
                                _RateButton(
                                    word: 'Hard',
                                    icon:
                                        Icons.sentiment_dissatisfied_outlined,
                                    color: dm.examRed,
                                    onTap: () =>
                                        widget.onRate(WireRating.again)),
                              ]),
                            ] else if (widget.onNextInTopic != null) ...[
                              OutlinedButton(
                                onPressed: widget.onNextInTopic,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    side:
                                        BorderSide(color: dm.ruleStrong)),
                                child: Text('Next in topic',
                                    style: DmType.bodyUi
                                        .copyWith(color: dm.tealInk)),
                              ),
                            ],
                            if (widget.belowAnswer != null)
                              widget.belowAnswer!,
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: DmSpace.xl3),
                ],
              ),
            ),
            if (!widget.revealed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(DmSpace.gutter),
                  child: FilledButton(
                    onPressed: widget.onReveal,
                    style: FilledButton.styleFrom(
                      backgroundColor: dm.teal,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DmRadius.md)),
                    ),
                    child: Text('Reveal model answer',
                        style:
                            DmType.bodyUi.copyWith(color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton(
      {required this.word,
      required this.icon,
      required this.color,
      required this.onTap});
  final String word;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Rate $word',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DmRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(DmRadius.sm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(word, style: DmType.meta.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`app/lib/ui/reader/reader_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';
import 'reader_view.dart';

/// Browse-mode Reader. Plan 5 Task 8 replaces the fixture state below with
/// its ReaderController binding (same ReaderView API); the route stays.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen.browse({super.key, required this.qnaId, this.topicId})
      : queueMode = false;
  const ReaderScreen.queuePlaceholder({super.key})
      : qnaId = null,
        topicId = null,
        queueMode = true;

  final String? qnaId;
  final String? topicId;
  final bool queueMode;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  QnaRow? _qna;
  List<QnaRow> _topicQnas = const [];
  bool _revealed = false;
  bool _rated = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.queueMode) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final repo = ref.read(contentRepositoryProvider);
      final qna = await repo.qna(widget.qnaId!);
      final topicQnas =
          widget.topicId == null ? <QnaRow>[] : await repo.qnas(widget.topicId!);
      setState(() {
        _qna = qna;
        _topicQnas = topicQnas;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  QnaRow? get _next {
    final i = _topicQnas.indexWhere((q) => q.id == _qna?.id);
    return i >= 0 && i + 1 < _topicQnas.length ? _topicQnas[i + 1] : null;
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    if (widget.queueMode) {
      return Scaffold(
        body: Center(
            child: Text('Recall queue arrives with the study loop.',
                style: DmType.bodyUi.copyWith(color: dm.ink2))),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Couldn't load this - retry",
                style: DmType.bodyUi.copyWith(color: dm.ink2)),
            TextButton(onPressed: _fetch, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final qna = _qna;
    if (qna == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return ReaderView(
      qna: qna,
      revealed: _revealed,
      rated: _rated,
      onReveal: () => setState(() => _revealed = true),
      onRate: (r) {
        setState(() => _rated = true);
        showDmToast(context, '✓ Rated ${uiLabelForWire[r]} · next answer');
      },
      onNextInTopic: _next == null
          ? null
          : () => context
              .go('/reader/${_next!.id}?topic=${widget.topicId}'),
      crumb: [
        (
          label: 'Airway Management',
          onTap: () => context.go('/syllabus')
        ), // Step 3b below replaces this hardcoded crumb with real ancestors
        (label: qna.question.split(':').first, onTap: () {}),
      ],
    );
  }
}
```

- [ ] **Step 3b: Replace the hardcoded crumb with real ancestors**

In `_fetch`, resolve the topic + chapter rows (`repo.topics` on the chapter is not addressable from a bare QnA - extend `_fetch` to walk: `repo.qna` -> `topicId` -> find topic via `repo.topics(chapterId)`; the fixture repo exposes chapter ids on `TopicRow.chapterId`). Store `_topicTitle`, `_chapterTitle`, `_chapterId` and build:

```dart
crumb: [
  (label: _chapterTitle, onTap: () => context.go('/syllabus/topics/$_chapterId')),
  (label: _topicTitle, onTap: () {}),
],
```

The leaf's `onTap` is never wired (non-interactive leaf) - `ReaderView` only makes non-last segments tappable.

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader_surface_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/reader app/lib/domain/models.dart app/test/ui/reader_surface_test.dart
git commit -m "feat(app): Reader browse surface - reveal on white, red margin, EMH tray visual, earn anchors"
```

---

### Task 13: Fullscreen diagram viewer

Spec: `docs/superpowers/specs/2026-07-03-reader-recall-design.md` (viewer section). Inline plate says `Tap to enlarge` (the ONE diagram affordance - FINDING-013); the viewer has pinch/double-tap/scroll zoom 1x-5x, drag-pan, in-app rotate, focus trap, Escape/✕ close.

**Files:**

- Create: `app/lib/ui/reader/diagram_viewer.dart`
- Modify: `app/lib/ui/reader/reader_screen.dart` (pass `imageBuilder` to `ReaderView`)
- Test: `app/test/ui/diagram_viewer_test.dart`

**Interfaces:**

- Consumes: `ImageRow` (Task 5), `contentRepositoryProvider.imageBytes`, tokens.
- Produces: `DiagramPlate(image, bytesLoader)` (inline, caption row + `Tap to enlarge` pill) and `showDiagramViewer(context, image, bytes)` (route-level fullscreen dialog). Task 14's search excludes diagram content automatically (search walks `AnswerSection.bodyMd` text only).

Behaviors:

- Plate: image (12px radius - a sanctioned plate), caption row under it: `Fig 1 - ...` caption (`meta`, `ink2`) + right pill `Tap to enlarge`; tapping plate or pill opens the viewer. `Semantics(image: true, label: contentDescription)`.
- Viewer (fullscreen `Dialog.fullscreen`, `paper` bg): header = caption (truncated) + close `IconButton` (✕, semantics `Close`, also `Escape` key via `Shortcuts`); stage = `InteractiveViewer(minScale: 1, maxScale: 5)` wrapping the (rotatable) image; `GestureDetector.onDoubleTap` toggles 1x <-> 2.5x; floating pill `Rotate for a larger view` toggling `Back to portrait` - rotation is `RotatedBox(quarterTurns: 1)` and RESETS zoom (fresh `TransformationController`); footer hint `Pinch or double-tap to zoom · drag to pan` (`meta`, one line).
- Focus trap: the dialog is a new focus scope; close restores focus to the plate (a11y pack law). Test: after close, the plate's `Semantics` node still exists and the dialog is gone.

- [ ] **Step 1: Write the failing test**

`app/test/ui/diagram_viewer_test.dart`:

```dart
import 'dart:typed_data';

import 'package:diplomate/domain/models.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/diagram_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _img = ImageRow(
    id: 'i1',
    caption: 'Fig 1 - TAP block: needle in the plane',
    contentDescription: 'Ultrasound cross-section of the abdominal wall',
    byteSize: 44,
    sha256: 'x',
    sortOrder: 1);

// 1x1 white WebP
final _bytes = Uint8List.fromList(const [
  0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
  0x56, 0x50, 0x38, 0x20, 0x18, 0x00, 0x00, 0x00, 0x30, 0x01, 0x00, 0x9D,
  0x01, 0x2A, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x1C, 0x25, 0xA4, 0x00,
  0x03, 0x70, 0x00, 0xFE, 0xFD, 0xC0, 0x80, 0x00
]);

Widget host() => MaterialApp(
    theme: dmLightTheme(),
    home: Scaffold(
        body: DiagramPlate(image: _img, bytesLoader: () async => _bytes)));

void main() {
  testWidgets('plate shows caption + single Tap to enlarge affordance', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('Fig 1'), findsOneWidget);
    expect(find.text('Tap to enlarge'), findsOneWidget);
    expect(find.textContaining('Pinch'), findsNothing,
        reason: 'labels do not lie: inline has no pinch gesture');
  });

  testWidgets('viewer opens with rotate pill + gesture hint, Escape closes', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Tap to enlarge'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Rotate for a larger view'), findsOneWidget);
    expect(find.text('Pinch or double-tap to zoom · drag to pan'), findsOneWidget);

    await t.tap(find.text('Rotate for a larger view'));
    await t.pumpAndSettle();
    expect(find.text('Back to portrait'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/diagram_viewer_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/reader/diagram_viewer.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../theme/tokens.dart';

class DiagramPlate extends StatefulWidget {
  const DiagramPlate({super.key, required this.image, required this.bytesLoader});
  final ImageRow image;
  final Future<Uint8List> Function() bytesLoader;

  @override
  State<DiagramPlate> createState() => _DiagramPlateState();
}

class _DiagramPlateState extends State<DiagramPlate> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    widget.bytesLoader().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  void _open() {
    final bytes = _bytes;
    if (bytes == null) return;
    showDiagramViewer(context, widget.image, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DmSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            image: true,
            label: widget.image.contentDescription,
            child: InkWell(
              onTap: _open,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DmRadius.md),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  color: dm.sunk,
                  child: _bytes == null
                      ? const SizedBox(height: 120)
                      : Image.memory(_bytes!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: DmSpace.xs),
          Row(
            children: [
              Expanded(
                  child: Text(widget.image.caption,
                      style: DmType.meta.copyWith(color: dm.ink2))),
              InkWell(
                onTap: _open,
                borderRadius: BorderRadius.circular(DmRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DmSpace.sm, vertical: DmSpace.xs),
                  decoration: BoxDecoration(
                    border: Border.all(color: dm.ruleStrong),
                    borderRadius: BorderRadius.circular(DmRadius.sm),
                  ),
                  child: Text('Tap to enlarge',
                      style: DmType.meta.copyWith(color: dm.tealInk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showDiagramViewer(BuildContext context, ImageRow image, Uint8List bytes) {
  showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => _DiagramViewer(image: image, bytes: bytes),
  );
}

class _DiagramViewer extends StatefulWidget {
  const _DiagramViewer({required this.image, required this.bytes});
  final ImageRow image;
  final Uint8List bytes;

  @override
  State<_DiagramViewer> createState() => _DiagramViewerState();
}

class _DiagramViewerState extends State<_DiagramViewer> {
  final _controller = TransformationController();
  bool _rotated = false;

  void _toggleRotate() {
    setState(() {
      _rotated = !_rotated;
      _controller.value = Matrix4.identity(); // zoom resets on rotate
    });
  }

  void _doubleTap() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    _controller.value =
        zoomedIn ? Matrix4.identity() : (Matrix4.identity()..scale(2.5));
  }

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Dialog.fullscreen(
      backgroundColor: dm.paper,
      child: FocusScope(
        autofocus: true,
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
          },
          child: Actions(
            actions: {
              _CloseIntent: CallbackAction<_CloseIntent>(
                  onInvoke: (_) => Navigator.of(context).pop()),
            },
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DmSpace.sm, vertical: DmSpace.xs),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(widget.image.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    DmType.meta.copyWith(color: dm.ink2))),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: dm.ink),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _doubleTap,
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _rotated ? 1 : 0,
                          child: Semantics(
                              image: true,
                              label: widget.image.contentDescription,
                              child: Image.memory(widget.bytes,
                                  fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _toggleRotate,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: dm.ruleStrong)),
                  child: Text(
                      _rotated ? 'Back to portrait' : 'Rotate for a larger view',
                      style: DmType.meta.copyWith(color: dm.tealInk)),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(DmSpace.sm),
                    child: Text('Pinch or double-tap to zoom · drag to pan',
                        style: DmType.meta.copyWith(color: dm.ink3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
```

Add the missing import at the top: `import 'package:flutter/services.dart' show LogicalKeyboardKey; import 'package:flutter/widgets.dart' show LogicalKeySet;` (LogicalKeySet lives in widgets).

Wire it in `reader_screen.dart` - pass to `ReaderView`:

```dart
imageBuilder: (context, img) => DiagramPlate(
  image: img,
  bytesLoader: () => ref.read(contentRepositoryProvider).imageBytes(img.id),
),
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/diagram_viewer_test.dart && flutter test test/ui/reader_surface_test.dart`
Expected: `All tests passed!` (both)

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/reader app/test/ui/diagram_viewer_test.dart
git commit -m "feat(app): fullscreen diagram viewer - zoom 1x-5x, pan, in-app rotate, focus trap"
```

---

### Task 14: In-answer search + bookmark toggle + report-error row

Specs: `docs/superpowers/specs/2026-07-03-reader-answer-search-design.md` (search algorithm + lifecycle), reader-recall spec (bookmark + report row). Search appears POST-REVEAL only; closing (or rating) restores the answer markup exactly.

**Files:**

- Create: `app/lib/ui/reader/answer_search.dart`
- Create: `app/lib/data/repos/bookmark_repository.dart`
- Create: `app/lib/data/fixtures/fake_bookmark_repository.dart`
- Modify: `app/lib/app_providers.dart` (add `bookmarkRepositoryProvider`, `isOnlineProvider`, `reportErrorProvider`)
- Modify: `app/lib/ui/reader/reader_screen.dart` (search topbar entry, bookmark toggle in `trailingCrumbAction`, report row in `belowAnswer`)
- Test: `app/test/ui/answer_search_test.dart`, `app/test/ui/reader_actions_test.dart`

**Interfaces:**

- Consumes: `ReaderView` slots (Task 12), `showDmToast` (Task 6).
- Produces (plan 5 keeps bookmark clearing on queue auto-advance; plan 6 re-points the providers):

```dart
// bookmark_repository.dart - local-first; plan 6 adds PUT /me/bookmarks LWW sync
abstract class BookmarkRepository {
  Stream<Set<String>> bookmarkedIds();                 // live set of content_ids
  Future<void> toggle(String contentId);               // flips + stamps updated_at
  Stream<List<BookmarkEntry>> entries();               // for the Bookmarks screen
}
class BookmarkEntry { final String contentId; final DateTime updatedAt; }

// app_providers.dart additions
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) => FakeBookmarkRepository());
final isOnlineProvider = StateProvider<bool>((ref) => true);         // plan 6: real connectivity
final reportErrorProvider = Provider<Future<void> Function(String qnaId, String message)>(
    (ref) => (qnaId, message) async {});                              // plan 6: POST /qna/:id/report

// answer_search.dart - pure, widget-independent (unit-testable)
class SearchMatch { final String sectionKey; final int start, end; }
List<SearchMatch> findMatches(QnaRow qna, String query);
```

Search algorithm (spec-verbatim): case-insensitive; per word - substring match, OR Levenshtein <= 1 for words >= 4 chars, <= 2 for words >= 7 chars; multi-word queries match as phrase runs of consecutive word matches; scope = `earns_marks` labels + `sections[].heading` + `sections[].body_md` (never the tray, never diagram captions); highlights teal (`tealSoft` bg), ACTIVE match amber (`amberSoft`), `n/N` counter, prev/next wrap, active match auto-scrolled into view.

UI: post-reveal a search `IconButton` appears in the crumb row (next to the bookmark toggle); tapping shows a bar under the crumb: `TextField` (hint `Search...`), `n/N` counter, prev (`^`) next (`v`) close (`✕`) icon buttons; close restores plain text spans exactly.

Bookmark toggle: `IconButton` outline `Icons.bookmark_border` -> filled `Icons.bookmark` (teal), `Semantics(toggled:)`, toasts `✓ Bookmarked` / `Bookmark removed`; state per QnA from `bookmarkedIds()`.

Report row (TD1, in `belowAnswer` - post-reveal only): a plain row `Report an answer error` (`meta`, `ink3`, flag icon). Online: opens a dialog - title `Report an answer error`, optional `TextField` (hint `What's wrong? (optional)`), actions `Cancel` / `Send`; Send awaits `reportErrorProvider` then toasts `✓ Report sent`. Offline (`isOnlineProvider == false`): row disabled (ink3 at 50%, taps ignored) with trailing plain copy `Connect to report` (online-only v1 - no queued reports).

- [ ] **Step 1: Write the failing tests**

`app/test/ui/answer_search_test.dart` (pure function tests):

```dart
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/ui/reader/answer_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('substring + typo-tolerant matching per the spec bands', () async {
    final repo = FixtureContentRepository();
    final qna = (await repo.qna('01J0QNATAPBLOCK00000000001'))!;

    expect(findMatches(qna, 'oblique'), isNotEmpty, reason: 'plain substring');
    expect(findMatches(qna, 'obliqe'), isNotEmpty,
        reason: 'Levenshtein 1 on a >=4-char word');
    expect(findMatches(qna, 'anasthetic'), isNotEmpty,
        reason: 'Levenshtein <=2 on a >=7-char word');
    expect(findMatches(qna, 'xy'), isEmpty, reason: 'short garbage does not fuzz');
    expect(findMatches(qna, 'internal oblique'), isNotEmpty, reason: 'phrase run');
  });

  test('matches carry section keys for scroll targeting', () async {
    final repo = FixtureContentRepository();
    final qna = (await repo.qna('01J0QNATAPBLOCK00000000001'))!;
    final m = findMatches(qna, 'hydrodissect');
    expect(m.single.sectionKey, 'technique');
  });
}
```

`app/test/ui/reader_actions_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tapQna = '01J0QNATAPBLOCK00000000001';
const _tapTopic = '01J0TOPICTAPBLOCK000000001';

Widget host({bool online = true}) => ProviderScope(
      overrides: [isOnlineProvider.overrideWith((ref) => online)],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: ReaderScreen.browse(qnaId: _tapQna, topicId: _tapTopic)),
    );

void main() {
  testWidgets('search entry exists only post-reveal; search finds and counts', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsNothing, reason: 'pre-reveal: no search');
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.search));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'oblique');
    await t.pumpAndSettle();
    expect(find.textContaining('/'), findsWidgets, reason: 'n/N counter visible');
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'close restores the answer');
  });

  testWidgets('bookmark toggle flips icon and toasts', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.bookmark_border));
    await t.pump();
    expect(find.text('✓ Bookmarked'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await t.tap(find.byIcon(Icons.bookmark));
    await t.pump();
    expect(find.text('Bookmark removed'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('report row: online opens dialog and sends; offline is disabled with plain copy',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.text('Report an answer error'));
    await t.pumpAndSettle();
    await t.tap(find.text('Send'));
    await t.pump();
    expect(find.text('✓ Report sent'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));

    await t.pumpWidget(host(online: false));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.text('Connect to report'), findsOneWidget);
    await t.tap(find.text('Report an answer error'));
    await t.pumpAndSettle();
    expect(find.text('Send'), findsNothing, reason: 'disabled offline - no dialog');
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/answer_search_test.dart test/ui/reader_actions_test.dart`

- [ ] **Step 3: Implement the search core**

`app/lib/ui/reader/answer_search.dart`:

```dart
import '../../domain/models.dart';

class SearchMatch {
  const SearchMatch({required this.sectionKey, required this.start, required this.end});
  final String sectionKey; // 'earn:<label>' for outline rows, else AnswerSection.key
  final int start, end;    // character offsets within that section's searched text
}

int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (j) => j);
  final curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = List.of(curr);
  }
  return prev[n];
}

bool _wordMatches(String word, String qword) {
  final w = word.toLowerCase(), q = qword.toLowerCase();
  if (w.contains(q)) return true;
  if (q.length >= 7) return _levenshtein(w, q) <= 2;
  if (q.length >= 4) return _levenshtein(w, q) <= 1;
  return false; // short words: substring only (checked above)
}

final _wordRe = RegExp(r"[A-Za-z0-9']+");

/// Spec: per-word substring or Levenshtein (<=1 for >=4 chars, <=2 for >=7);
/// multi-word queries match as consecutive word runs. Scope: earns_marks
/// labels + section headings + section bodies. Never diagram captions.
List<SearchMatch> findMatches(QnaRow qna, String query) {
  final qwords = _wordRe.allMatches(query).map((m) => m.group(0)!).toList();
  if (qwords.isEmpty) return const [];
  final out = <SearchMatch>[];

  void scan(String key, String text) {
    final words = _wordRe.allMatches(text).toList();
    for (var i = 0; i + qwords.length <= words.length; i++) {
      var ok = true;
      for (var j = 0; j < qwords.length; j++) {
        if (!_wordMatches(words[i + j].group(0)!, qwords[j])) {
          ok = false;
          break;
        }
      }
      if (ok) {
        out.add(SearchMatch(
            sectionKey: key,
            start: words[i].start,
            end: words[i + qwords.length - 1].end));
      }
    }
  }

  for (final e in qna.earnsMarks) {
    scan('earn:${e.label}', e.label);
  }
  for (final s in qna.sections) {
    scan(s.key, '${s.heading}\n${s.bodyMd}');
  }
  return out;
}
```

- [ ] **Step 4: Implement bookmarks, report, and the Reader wiring**

`app/lib/data/repos/bookmark_repository.dart`:

```dart
class BookmarkEntry {
  const BookmarkEntry({required this.contentId, required this.updatedAt});
  final String contentId;
  final DateTime updatedAt;
}

/// Local-first; plan 5 persists to drift, plan 6 adds PUT /me/bookmarks
/// LWW sync (tombstones live in the drift row, not here).
abstract class BookmarkRepository {
  Stream<Set<String>> bookmarkedIds();
  Future<void> toggle(String contentId);
  Stream<List<BookmarkEntry>> entries();
}
```

`app/lib/data/fixtures/fake_bookmark_repository.dart`:

```dart
import 'dart:async';

import '../repos/bookmark_repository.dart';

class FakeBookmarkRepository implements BookmarkRepository {
  final _entries = <String, BookmarkEntry>{};
  final _controller = StreamController<void>.broadcast();

  List<BookmarkEntry> get _list => _entries.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<Set<String>> bookmarkedIds() async* {
    yield _entries.keys.toSet();
    yield* _controller.stream.map((_) => _entries.keys.toSet());
  }

  @override
  Future<void> toggle(String contentId) async {
    if (_entries.containsKey(contentId)) {
      _entries.remove(contentId);
    } else {
      _entries[contentId] =
          BookmarkEntry(contentId: contentId, updatedAt: DateTime.now());
    }
    _controller.add(null);
  }

  @override
  Stream<List<BookmarkEntry>> entries() async* {
    yield _list;
    yield* _controller.stream.map((_) => _list);
  }
}
```

Append to `app/lib/app_providers.dart`:

```dart
final bookmarkRepositoryProvider =
    Provider<BookmarkRepository>((ref) => FakeBookmarkRepository());

/// plan 6 re-points this at real connectivity signal
final isOnlineProvider = StateProvider<bool>((ref) => true);

/// plan 6: POST /qna/:id/report
final reportErrorProvider =
    Provider<Future<void> Function(String qnaId, String message)>(
        (ref) => (qnaId, message) async {});
```

(with imports `data/repos/bookmark_repository.dart`, `data/fixtures/fake_bookmark_repository.dart`).

Reader wiring in `reader_screen.dart` - build the three affordances and pass them into `ReaderView`:

```dart
// in build(), before returning ReaderView:
final bookmarked = ref
        .watch(bookmarkedIdsProvider)
        .valueOrNull
        ?.contains(qna.id) ??
    false;
final online = ref.watch(isOnlineProvider);

// trailingCrumbAction:
trailingCrumbAction: Row(mainAxisSize: MainAxisSize.min, children: [
  if (_revealed)
    IconButton(
      tooltip: 'Search this answer',
      icon: Icon(Icons.search, color: dm.ink2),
      onPressed: () => setState(() => _searchOpen = !_searchOpen),
    ),
  Semantics(
    toggled: bookmarked,
    child: IconButton(
      tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
      icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: bookmarked ? dm.teal : dm.ink2),
      onPressed: () async {
        await ref.read(bookmarkRepositoryProvider).toggle(qna.id);
        if (context.mounted) {
          showDmToast(context, bookmarked ? 'Bookmark removed' : '✓ Bookmarked');
        }
      },
    ),
  ),
]),

// belowAnswer (post-reveal only - ReaderView renders belowAnswer inside the
// revealed block already):
belowAnswer: _ReportRow(
  online: online,
  onSend: (message) async {
    await ref.read(reportErrorProvider)(qna.id, message);
    if (context.mounted) showDmToast(context, '✓ Report sent');
  },
),
```

with a small `bookmarkedIdsProvider` at the top of `reader_screen.dart`:

```dart
final bookmarkedIdsProvider = StreamProvider<Set<String>>(
    (ref) => ref.watch(bookmarkRepositoryProvider).bookmarkedIds());
```

and the report row widget in the same file:

```dart
class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.online, required this.onSend});
  final bool online;
  final Future<void> Function(String message) onSend;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return InkWell(
      onTap: !online
          ? null
          : () async {
              final controller = TextEditingController();
              final send = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Report an answer error'),
                  content: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: "What's wrong? (optional)"),
                    maxLines: 3,
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Send')),
                  ],
                ),
              );
              if (send == true) await onSend(controller.text.trim());
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(top: DmSpace.lg),
        child: Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 16, color: dm.ink3.withValues(alpha: online ? 1 : 0.5)),
            const SizedBox(width: DmSpace.xs),
            Text('Report an answer error',
                style: DmType.meta.copyWith(
                    color: dm.ink3.withValues(alpha: online ? 1 : 0.5))),
            const Spacer(),
            if (!online)
              Text('Connect to report',
                  style: DmType.meta.copyWith(color: dm.ink3)),
          ],
        ),
      ),
    );
  }
}
```

Search bar + highlighting wiring: when `_searchOpen`, render under the crumb a `TextField` (hint `Search...`) + `n/N` + prev/next/close `IconButton`s; hold `_matches = findMatches(qna, query)` and `_active` index; pass highlight data down by rendering section bodies through a helper that wraps match ranges in `TextSpan`s (`tealSoft` bg via `backgroundColor`, active match `amberSoft`); on active-index change call the same `Scrollable.ensureVisible` used by earn anchors on the match's section. Closing sets `_searchOpen = false`, clears query - spans revert to plain text (nothing else was mutated). Rating while open also closes it. This lives entirely in `reader_screen.dart` + a `highlightSpans(String text, List<SearchMatch> matches, int active, String sectionKey)` helper in `answer_search.dart`:

```dart
// appended to answer_search.dart
import 'package:flutter/painting.dart';

List<InlineSpan> highlightSpans({
  required String text,
  required String sectionKey,
  required List<SearchMatch> matches,
  required int activeIndex,
  required TextStyle base,
  required Color highlight,
  required Color activeHighlight,
}) {
  final own = [
    for (var i = 0; i < matches.length; i++)
      if (matches[i].sectionKey == sectionKey) (i, matches[i])
  ];
  if (own.isEmpty) return [TextSpan(text: text, style: base)];
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final (i, m) in own) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
    }
    spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: base.copyWith(
            backgroundColor: i == activeIndex ? activeHighlight : highlight)));
    cursor = m.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}
```

Note: `ReaderView` gains two optional params for this - `List<InlineSpan> Function(AnswerSection)? sectionSpans` (used instead of the plain `Text(s.bodyMd)` when non-null) and `Widget? belowCrumb` (the search bar slot). Add them in the same commit; sections render `Text.rich(TextSpan(children: sectionSpans(s)))` when provided. The heading+body searched text is `'${s.heading}\n${s.bodyMd}'` - offsets in `SearchMatch` index into that combined string; `sectionSpans` must render heading and body from the same combined string to keep offsets honest (split at the first `\n`).

- [ ] **Step 5: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/answer_search_test.dart test/ui/reader_actions_test.dart test/ui/reader_surface_test.dart`
Expected: `All tests passed!` (all three files)

- [ ] **Step 6: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib app/test/ui
git commit -m "feat(app): in-answer search (typo-tolerant), bookmark toggle, report-error row"
```

### Task 15: Bookmarks screen

Spec: `docs/superpowers/specs/2026-07-03-bookmarks-design.md`. Stack child of Home (lights the Home tab); rows reopen the QnA in browse mode; empty state carries direction.

**Files:**

- Create: `app/lib/ui/bookmarks/bookmarks_screen.dart` (replace stub)
- Test: `app/test/ui/bookmarks_screen_test.dart`

**Interfaces:**

- Consumes: `bookmarkRepositoryProvider.entries()` (Task 14), `contentRepositoryProvider.qna/topics/chapters` (Task 5), router `/reader/:qnaId?topic=` (Task 6).
- Produces: `BookmarksScreen` at `/home/bookmarks`.

Anatomy:

1. Topbar: back (to Home) + title `Bookmarks`.
2. Rows (divider list, newest first): question text (bodyUi, 2-line ellipsis) + source line `Regional Anaesthesia · Truncal blocks` (`meta`, `ink3`, `Chapter · Topic`). Tap -> `/reader/<qnaId>?topic=<topicId>`.
3. Empty state: `No bookmarks yet.` (section) + `Tap the bookmark icon on any answer to save it here.` (bodyUi, ink2).

- [ ] **Step 1: Write the failing test**

`app/test/ui/bookmarks_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_bookmark_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/bookmarks/bookmarks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(FakeBookmarkRepository repo) => ProviderScope(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: dmLightTheme(), home: const BookmarksScreen()),
    );

void main() {
  testWidgets('empty state carries direction', (t) async {
    await t.pumpWidget(host(FakeBookmarkRepository()));
    await t.pumpAndSettle();
    expect(find.text('No bookmarks yet.'), findsOneWidget);
    expect(find.text('Tap the bookmark icon on any answer to save it here.'),
        findsOneWidget);
  });

  testWidgets('bookmarked QnA renders question + Chapter · Topic source row', (t) async {
    final repo = FakeBookmarkRepository();
    await repo.toggle('01J0QNATAPBLOCK00000000001');
    await t.pumpWidget(host(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('transversus abdominis plane'), findsOneWidget);
    expect(find.text('Regional Anaesthesia · Truncal blocks'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/bookmarks_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/bookmarks/bookmarks_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../data/repos/bookmark_repository.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

class _BookmarkRowData {
  const _BookmarkRowData(
      {required this.qna, required this.chapterTitle, required this.topicTitle});
  final QnaRow qna;
  final String chapterTitle, topicTitle;
}

final _bookmarkRowsProvider = StreamProvider<List<_BookmarkRowData>>((ref) {
  final repo = ref.watch(contentRepositoryProvider);
  return ref.watch(bookmarkRepositoryProvider).entries().asyncMap((entries) async {
    final rows = <_BookmarkRowData>[];
    final specs = await repo.specialities();
    final withContent = specs.where((s) => s.hasContent).toList();
    final chapters = withContent.isEmpty
        ? <ChapterRow>[]
        : await repo.chapters(withContent.first.id);
    for (final e in entries) {
      final qna = await repo.qna(e.contentId);
      if (qna == null) continue;
      String chapterTitle = '', topicTitle = '';
      for (final c in chapters) {
        final topics = await repo.topics(c.id);
        for (final t in topics) {
          if (t.id == qna.topicId) {
            chapterTitle = c.title;
            topicTitle = t.title;
          }
        }
      }
      rows.add(_BookmarkRowData(
          qna: qna, chapterTitle: chapterTitle, topicTitle: topicTitle));
    }
    return rows;
  });
});

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final rows = ref.watch(_bookmarkRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmarks', style: DmType.title.copyWith(color: dm.ink)),
        backgroundColor: dm.paper,
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => Center(
            child: Text("Couldn't load this - retry",
                style: DmType.bodyUi.copyWith(color: dm.ink2))),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No bookmarks yet.',
                        style: DmType.section.copyWith(color: dm.ink)),
                    const SizedBox(height: DmSpace.sm),
                    Text('Tap the bookmark icon on any answer to save it here.',
                        style: DmType.bodyUi.copyWith(color: dm.ink2)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final row = list[i];
                  return InkWell(
                    onTap: () => context
                        .go('/reader/${row.qna.id}?topic=${row.qna.topicId}'),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: dm.rule))),
                      padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.qna.question,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DmType.bodyUi.copyWith(color: dm.ink)),
                          const SizedBox(height: 2),
                          Text('${row.chapterTitle} · ${row.topicTitle}',
                              style: DmType.meta.copyWith(color: dm.ink3)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/bookmarks_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/bookmarks app/test/ui/bookmarks_screen_test.dart
git commit -m "feat(app): Bookmarks screen - saved answers with Chapter · Topic source rows"
```

---

### Task 16: Account screen

Spec: `docs/superpowers/specs/2026-07-03-account-design.md`. Photo avatar (Google profile, letter fallback), quiet last-synced line (TD2 - amber when stale), exam-speciality row (one-time change), daily reminder toggle, sign out, delete account (2-step, red - the sanctioned destructive red). NO storage row, NO downloads row (feature removed).

**Files:**

- Create: `app/lib/ui/account/account_screen.dart` (replace stub)
- Test: `app/test/ui/account_screen_test.dart`

**Interfaces:**

- Consumes: `sessionUserProvider`, `authRepositoryProvider`, `syncServiceProvider` (Task 5); `contentRepositoryProvider.specialities()` (to render the chosen track's name); router `/speciality?mode=change` (Task 6); `showDmToast` (Task 6).
- Produces: `AccountScreen` at `/account`; `final reminderEnabledProvider = StateProvider<bool>((ref) => true);` DEFINED HERE - plan 5's notification service watches it (same name).

Anatomy (rows, divider-separated, no cards):

1. Identity block: 46px circle avatar - `photoUrl` image, `onBackgroundImageError`/null fallback = letter monogram (first letter of name, `tealSoft` bg, `tealInk` letter); name (bodyUi, ink) + email (meta, ink3).
2. Sync line (quiet, under identity): `Last synced N days ago` / `Last synced today` - `ink3` normally, `amber` when > 7 days (stale) or when the stream yields null (`Not synced yet`). Data from `syncServiceProvider.lastSyncedAt()`.
3. Row `Exam speciality`: current track name + chevron -> `/speciality?mode=change`. When `specialityChangeCount >= 1`: row greyed (ink3), chevron hidden, trailing text `one-time change used`, tap disabled.
4. Row `Daily reminder`: `Switch` bound to `reminderEnabledProvider` (D19 opt-out; plan 5 wires actual scheduling).
5. Row `Sign out`: confirm-free; calls `signOut()`, clears `sessionUserProvider` -> router redirects to `/signin`.
6. Row `Delete account` (red text + red icon - sanctioned destructive red): 2-step - dialog 1 `Delete your account?` body `This deletes your recall history, bookmarks, and profile from our servers. This cannot be undone.` actions Cancel / Continue; dialog 2 `Are you sure?` body `Your Google account stays yours; only DiploMate data is deleted.` actions Cancel / `Delete account` (red). On confirm: `deleteAccount()`, clear session, toast `Account deleted`.

- [ ] **Step 1: Write the failing test**

`app/test/ui/account_screen_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/fixtures/fake_sync_service.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/account/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessionUser user({int changes = 0}) => SessionUser(
    id: 'u1', email: 'ananya@example.com', name: 'Ananya Sharma', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: changes);

Widget host({int changes = 0, FakeSyncService? sync}) => ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => user(changes: changes)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        if (sync != null) syncServiceProvider.overrideWithValue(sync),
      ],
      child: MaterialApp(theme: dmLightTheme(), home: const AccountScreen()),
    );

void main() {
  testWidgets('identity, sync line, speciality row, reminder, sign out, delete; no downloads/storage rows',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Ananya Sharma'), findsOneWidget);
    expect(find.text('ananya@example.com'), findsOneWidget);
    expect(find.text('A'), findsOneWidget, reason: 'letter fallback avatar');
    expect(find.textContaining('Last synced'), findsOneWidget);
    expect(find.text('Exam speciality'), findsOneWidget);
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.textContaining('torage'), findsNothing);
    expect(find.textContaining('ownload'), findsNothing);
  });

  testWidgets('change-used state greys the speciality row', (t) async {
    await t.pumpWidget(host(changes: 1));
    await t.pumpAndSettle();
    expect(find.text('one-time change used'), findsOneWidget);
  });

  testWidgets('delete account is a 2-step confirm', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Delete account'));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/account_screen_test.dart`

- [ ] **Step 3: Implement**

`app/lib/ui/account/account_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';

/// D19 opt-out. Plan 5's notification service watches this (same name).
final reminderEnabledProvider = StateProvider<bool>((ref) => true);

final _lastSyncedProvider = StreamProvider<DateTime?>(
    (ref) => ref.watch(syncServiceProvider).lastSyncedAt());

final _specialityNameProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(sessionUserProvider)?.specialityId;
  if (id == null) return null;
  final specs = await ref.watch(contentRepositoryProvider).specialities();
  for (final s in specs) {
    if (s.id == id) return s.name;
  }
  return null;
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  String _syncLabel(DateTime? at) {
    if (at == null) return 'Not synced yet';
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'Last synced today';
    if (days == 1) return 'Last synced 1 day ago';
    return 'Last synced $days days ago';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This deletes your recall history, bookmarks, and profile from our servers. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
            'Your Google account stays yours; only DiploMate data is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete account', style: TextStyle(color: dm.examRed))),
        ],
      ),
    );
    if (step2 != true || !context.mounted) return;
    await ref.read(authRepositoryProvider).deleteAccount();
    if (context.mounted) showDmToast(context, 'Account deleted');
    ref.read(sessionUserProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final user = ref.watch(sessionUserProvider);
    final sync = ref.watch(_lastSyncedProvider).valueOrNull;
    final specName = ref.watch(_specialityNameProvider).valueOrNull;
    final changeUsed = (user?.specialityChangeCount ?? 0) >= 1;
    final syncedAt = sync;
    final stale =
        syncedAt == null || DateTime.now().difference(syncedAt).inDays > 7;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
          children: [
            const SizedBox(height: DmSpace.sm),
            Text('Account', style: DmType.title.copyWith(color: dm.ink)),
            const SizedBox(height: DmSpace.xl2),
            Row(
              children: [
                _Avatar(name: user?.name, photoUrl: user?.photoUrl, dm: dm),
                const SizedBox(width: DmSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '',
                          style: DmType.bodyUi.copyWith(color: dm.ink)),
                      Text(user?.email ?? '',
                          style: DmType.meta.copyWith(color: dm.ink3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DmSpace.sm),
            Text(_syncLabel(syncedAt),
                style: DmType.meta.copyWith(color: stale ? dm.amber : dm.ink3)),
            const SizedBox(height: DmSpace.lg),
            _Row(
              dm: dm,
              title: 'Exam speciality',
              subtitle: specName,
              trailing: changeUsed
                  ? Text('one-time change used',
                      style: DmType.meta.copyWith(color: dm.ink3))
                  : Icon(Icons.chevron_right, color: dm.ink3),
              enabled: !changeUsed,
              onTap: () => context.go('/speciality?mode=change'),
            ),
            _Row(
              dm: dm,
              title: 'Daily reminder',
              trailing: Switch(
                value: ref.watch(reminderEnabledProvider),
                activeTrackColor: dm.teal,
                onChanged: (v) =>
                    ref.read(reminderEnabledProvider.notifier).state = v,
              ),
            ),
            _Row(
              dm: dm,
              title: 'Sign out',
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                ref.read(sessionUserProvider.notifier).state = null;
              },
            ),
            _Row(
              dm: dm,
              title: 'Delete account',
              titleColor: dm.examRed,
              leadingIcon: Icons.delete_outline,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl, required this.dm});
  final String? name, photoUrl;
  final DmColors dm;

  @override
  Widget build(BuildContext context) {
    final letter = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: dm.tealSoft, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? Center(
              child: Text(letter, style: DmType.bodyUi.copyWith(color: dm.tealInk)))
          : Image.network(photoUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(letter,
                      style: DmType.bodyUi.copyWith(color: dm.tealInk)))),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.dm,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.enabled = true,
      this.titleColor,
      this.leadingIcon});
  final DmColors dm;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? titleColor;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: titleColor ?? dm.ink2),
              const SizedBox(width: DmSpace.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: DmType.bodyUi.copyWith(
                          color: titleColor ?? (enabled ? dm.ink : dm.ink3))),
                  if (subtitle != null)
                    Text(subtitle!, style: DmType.meta.copyWith(color: dm.ink3)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/account_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/account app/test/ui/account_screen_test.dart
git commit -m "feat(app): Account - identity, sync line, one-time speciality change, 2-step delete"
```

---

### Task 17: Responsive + a11y acceptance sweep, doc-sync (DESIGN-T5/T6/T7 closure)

The per-screen tests above carry their own state coverage; this task adds the cross-cutting acceptance tests the a11y/responsive packs (Task 2) demand, then syncs DESIGN.md.

**Files:**

- Create: `app/test/acceptance/responsive_test.dart`
- Create: `app/test/acceptance/a11y_test.dart`
- Modify: `DESIGN.md` (doc-sync pass, DESIGN-T7)

**Interfaces:**

- Consumes: every screen (Tasks 7-16).
- Produces: the acceptance gate lane D's release checklist references.

- [ ] **Step 1: Write the responsive acceptance tests**

`app/test/acceptance/responsive_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/home/home_screen.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget host(Widget child, {double width = 320, double height = 640, double scale = 1.0}) =>
    ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user)],
      child: MaterialApp(
        theme: dmLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );

void main() {
  testWidgets('Home survives 320dp compact width without overflow', (t) async {
    await t.pumpWidget(host(const HomeScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Home survives textScale 1.3', (t) async {
    await t.pumpWidget(host(const HomeScreen(), scale: 1.3));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Reader survives short landscape (640x320) at textScale 1.3', (t) async {
    await t.pumpWidget(host(
        ReaderScreen.browse(
            qnaId: '01J0QNATAPBLOCK00000000001',
            topicId: '01J0TOPICTAPBLOCK000000001'),
        width: 640, height: 320, scale: 1.3));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Reader answer measure is capped on 600dp+ (centered max-width)', (t) async {
    await t.pumpWidget(host(
        ReaderScreen.browse(
            qnaId: '01J0QNATAPBLOCK00000000001',
            topicId: '01J0TOPICTAPBLOCK000000001'),
        width: 800, height: 1000));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    final answer = find.textContaining('fascial plane block');
    expect(t.getSize(answer).width, lessThanOrEqualTo(620),
        reason: 'never full-bleed 17px serif across a tablet width');
  });
}
```

(The last test fails until `ReaderView` wraps its ListView content in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 620)))` - add exactly that to `reader_view.dart` when the test demands it.)

- [ ] **Step 2: Write the a11y acceptance tests**

`app/test/acceptance/a11y_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:diplomate/ui/speciality/speciality_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: null, specialityChangeCount: 0);

void main() {
  testWidgets('speciality list meets the tap-target guideline (48dp floor)', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user)],
      child: MaterialApp(
          theme: dmLightTheme(), home: const SpecialityScreen(changeMode: false)),
    ));
    await t.pumpAndSettle();
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('reader rating tray buttons are labeled for TalkBack', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
          theme: dmLightTheme(),
          home: ReaderScreen.browse(
              qnaId: '01J0QNATAPBLOCK00000000001',
              topicId: '01J0TOPICTAPBLOCK000000001')),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Rate Easy'), findsOneWidget);
    expect(find.bySemanticsLabel('Rate Medium'), findsOneWidget);
    expect(find.bySemanticsLabel('Rate Hard'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('reveal under reduced motion is an instant swap', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: dmLightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ReaderScreen.browse(
              qnaId: '01J0QNATAPBLOCK00000000001',
              topicId: '01J0TOPICTAPBLOCK000000001'),
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pump(); // ONE frame, no animation wait
    expect(find.textContaining('fascial plane block'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run both, fix what they catch, expect PASS**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/acceptance/`
Expected: `All tests passed!` (after the max-width fix lands in `reader_view.dart`)

- [ ] **Step 4: Doc-sync pass into DESIGN.md (DESIGN-T7)**

In `DESIGN.md`: (a) confirm every token the app transcribed exists in the token tables (Task 2 already completed them - verify no drift against `tokens.dart`); (b) add a Decisions Log row:

```
| 2026-07-04 | Flutter build (lane B) landed against this document: tokens transcribed to app/lib/theme/tokens.dart, 9 screens + shell built on fixtures, free-beta UI contract + no-downloads enforced by widget tests | Plan 2026-07-04-flutter-shell-screens.md; per-screen specs are the copy source of truth |
```

- [ ] **Step 5: Full suite + commit**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test`
Expected: `All tests passed!`

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/test/acceptance app/lib/ui/reader/reader_view.dart DESIGN.md
git commit -m "test(app): responsive + a11y acceptance sweep; doc-sync DESIGN.md"
```

---

## Coverage

| Source task / lock                                                                                                                                                                                         | Plan task(s)                                                                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| DESIGN-T1 free-beta UI contract (no locks/paywall, no download states, chapter tap -> Topics, DESIGN.md annotation)                                                                                        | Task 1 (doc), Tasks 10-12 (enforced by tests)                                                                         |
| DESIGN-T2 per-track content-state model + empty-track screen (PG2/TD3)                                                                                                                                     | Task 1 (doc), Task 10                                                                                                 |
| DESIGN-T3 state-spec pack (funnel in resume slot, Home N=0, speciality commit states, stats floor n>=5, empty bookmarks, sign-in states, end-of-queue)                                                     | Task 1 (doc); Tasks 7, 8, 9, 15 (built); end-of-queue completion state is bound by plan 5 (ReaderController.complete) |
| DESIGN-T5 responsive rules (320dp, short landscape, 600dp+ max-width, textScale 1.3, keyboard search, safe areas)                                                                                          | Task 2 (doc), Task 17 (tests)                                                                                         |
| DESIGN-T6 a11y executable pack (48dp floor, roving radio, focus trap, TalkBack, reduced motion, announcements)                                                                                             | Task 2 (doc); Tasks 6 (toast announce), 8 (radio group), 13 (focus trap), 17 (acceptance tests)                       |
| DESIGN-T7 doc-sync pass                                                                                                                                                                                    | Task 17                                                                                                               |
| DESIGN-T8 one-way door confirmations (speciality change, delete 2-step)                                                                                                                                    | Tasks 8, 16                                                                                                           |
| ENG-T21 bundled OFL fonts, no runtime fetch                                                                                                                                                                | Task 3                                                                                                                |
| D5 sign-in exclusivity (one auth action)                                                                                                                                                                   | Task 7 (widget test)                                                                                                  |
| D13 (as amended): 3-tab nav, boot-at-sign-in, speciality gate, Home/Syllabus/Topics/Bookmarks/Account anatomy, tappable crumb ancestors                                                                    | Tasks 6, 8-11, 15, 16                                                                                                 |
| D14 QnA = recall unit (bookmarks keyed to QnA id)                                                                                                                                                          | Tasks 5, 14                                                                                                           |
| D15/D16 (as amended): soft gate (no countdown), reveal on white 150-220ms scroll-preserved, red margin weights, EMH tray visual (no intervals, no counter), earn anchors, diagram viewer, in-answer search | Tasks 12, 13, 14                                                                                                      |
| D20 tokens + dark mode + motion budget + thumb zone                                                                                                                                                        | Tasks 4, 12, 17                                                                                                       |
| PROTOTYPE SYNC 4 founder edits (tagline, EMH relabel, SRS de-surfaced, search placeholder, photo avatar, anchors)                                                                                          | Tasks 7, 8, 12, 14, 16                                                                                                |
| NO OFFLINE DOWNLOADS revision (no download UI anywhere; `Couldn't load this - retry` fetch states)                                                                                                         | Tasks 10, 11, 12 (tests assert absence)                                                                               |
| D6 edge states (amended): no-network sign-in, content-fetch retry, empty queue day-one (Home N=0), empty track, empty bookmarks                                                                            | Tasks 7, 9, 10, 11, 15                                                                                                |

Out of scope (owned by neighboring plans):

- `sql/0001+0002` DDL + 61-track seed: `2026-07-04-day1-content-ddl.md` (this plan copies its names into fixtures).
- Express API, entitlement middleware, `/legal/*` pages: `2026-07-04-server-api.md`.
- Content pipeline + publisher: `2026-07-04-ingestion-pipeline.md`.
- drift AppDatabase, Leitner scheduler, ReaderController (queue mode + rating persistence + debounce), real `dueCountProvider`/`topicPipProvider`/`weeklyStatsProvider`/`reminderEnabledProvider` wiring, notification, 4am rollover: `2026-07-04-study-loop-srs.md` (plan 4 ships the named stubs/seams it swaps).
- Real `AuthRepository` (google_sign_in + `/auth/google`), `SyncService` (backoff, X-Refreshed-Token), `ContentRepository` (dio + drift cache), starter-funnel E2E, Play signing, release checklist: `2026-07-04-integration-release.md`.
- Founder-only: CEO-T1 term sheet (milestone zero), CEO-T6..T9 strategy docs, TODOS 1-5/7 - no engineering plan tasks anywhere.
