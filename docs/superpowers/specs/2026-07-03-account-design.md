# Account - design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

Identity + settings rows. Reached via bottom nav only (no account icon in any
topbar). Hosts the one-time speciality change.

## UI (top → bottom)

- Topbar title: `Account`.
- Identity block: avatar = Google profile photo (46px circle, cover-fit;
  placeholder `<img>` with `onerror` fallback to the letter monogram `A` until
  real auth lands - 2026-07-04 founder pass) · `Dr. Ananya Rao` ·
  `ananya.rao@gmail.com`.
- **Rows:**
  1. `Exam speciality` (target icon) - subtitle is dynamic: starts `Not set`;
     after onboarding `<Speciality> · can change once`; after the one change
     `<Speciality> · one-time change used`. Tap opens the Speciality screen in
     change mode - **only while the change is unused**; after that the row is
     `aria-disabled` and inert.
  2. `Daily recall reminder` - subtitle `On · 8:00 pm` (inert; opt-out slot,
     D19).
  3. `Sign out` (inert).
  4. `Delete account` (danger red, trash icon) - subtitle `Removes your data
permanently` (inert; Play-mandate slot).
- Bottom nav: Account active.

## Verify (manual, preview server)

1. Before onboarding, subtitle reads `Not set`; after choosing, `<Speciality>
· can change once`.
2. Row opens change mode with the current track pre-selected and CTA `Save
change`.
3. Change to a different track → subtitle `· one-time change used`, row inert
   thereafter; re-saving the same track does not consume the change.
4. Reminder / Sign out / Delete rows render but perform no action.

## Confirmations + sync line (2026-07-04, DESIGN.md State Specs 14-15)

Speciality change and account deletion follow the one-way-door dialogs in
DESIGN.md State Spec 14 (exact copy there). A quiet sync row shows
`Not synced yet` / `Last synced today` / `Last synced N days ago`,
amber when >=3 days stale.
