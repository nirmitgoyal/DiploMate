# App shell & navigation — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color,
motion per `DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Single-file prototype shell. All screens are pre-rendered as `.pane` elements
inside one `.view-root` (phone frame); a router toggles visibility. No build
step, no dependencies; fonts from Google Fonts CDN.

## UI

- **Status bar** on every pane (`statusbar()`): time `7:14` (demo), wifi +
  battery icons.
- **Bottom nav** (`nav(active)`) — three tabs, in order:
  `Home` → `today` · `Syllabus` → `syllabus` · `Account` → `account`.
- **Active-tab mapping:** today → Home; syllabus **and** topics → Syllabus;
  **bookmarks → Home** (stack child); account → Account. Sign-in, Speciality,
  Reader, the paywall sheet, and the fullscreen diagram viewer render **no
  bottom nav**.
- Desktop chrome (masthead, "Go to screen" chips, footnote) is demo
  scaffolding, not app UI. Chip specials: `__paywall` → show Syllabus then open
  the sheet; `Speciality` → force re-show onboarding.

## Behaviors

- `show(root,screen)` — the router. Closes the fullscreen viewer, toggles
  `.pane.show` by `data-screen`, **resets any reader to `before`** (recall gate
  survives re-entry), closes in-answer search, scrolls the view to top.
- All in-app nav is event delegation on `data-go`. Special targets:
  `speciality-onboard` → `openSpec('onboard')`;
  `speciality-change` → `openSpec('change')`, gated on the one-time change
  being unused.
- **Boot:** every root starts at `signin` — onboarding is only reachable
  through "Continue with Google".
- `toast(rd,msg)` — bottom ack pill, auto-hides after 1500 ms.

## Non-goals

- Real routing/URL state, persistence across reload, multi-phone rendering
  (single `dir-b` root only).

## Verify (manual, preview server)

1. Reload → Sign-in is the visible pane.
2. Tab taps switch panes; Topics keeps the Syllabus tab lit; Bookmarks keeps
   Home lit.
3. Reveal an answer in Reader, leave via bottom nav, return → Reader is back
   at pre-reveal, search bar closed.
4. Open the fullscreen diagram, tap a nav tab → viewer closes with the
   navigation.
