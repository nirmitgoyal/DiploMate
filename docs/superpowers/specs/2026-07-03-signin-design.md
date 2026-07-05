# Sign-in - design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo). Tokens, type, color per
`DESIGN.md`; this spec covers structure, copy, and behavior.
Status: **Implemented in the prototype (2026-07-03).**

## What

One quiet composition, one action (D5: Google-only). No splash, no carousel,
no stock imagery. The visual anchor is a cropped model-answer specimen - the
product selling itself.

## UI (top → bottom)

- Wordmark: `Diplo` + bold `Mate`.
- Tagline under the wordmark (teal small-caps, the product's one exclamation):
  `Written by Doctors. Solved for Success!` (added 2026-07-04, founder pass).
- Lede: `Master DNB theory answers by recalling them - not rereading them.`
- **Answer specimen** (cropped, bottom-fading):
  - Question: `Define TAP block. Describe the anatomical basis, technique and
complications.`
  - Overline: `What earns marks`
  - Body: TAP-block definition paragraph, fading out.
- Primary button (Google icon): `Continue with Google`.
- Utility copy: `Terms of Service · Privacy Policy` (plain text, not wired
  links; sync-explainer sentence cut 2026-07-04, founder pass).
- No status-bar topbar title, no bottom nav.

## Behaviors

- `Continue with Google` → `openSpec('onboard')` - the **mandatory speciality
  gate**, not a direct nav to Home.
- If a speciality is already chosen, the gate short-circuits and the button
  lands on Home directly (onboarding shown once).
- No other auth affordance exists on the screen (D5 test: exactly one action).

## Non-goals

- Real OAuth, offline variant (`plain message + retry` - designed, not built),
  loading states.

## Verify (manual, preview server)

1. Reload → Sign-in shows; exactly one action button.
2. First `Continue with Google` → Speciality onboarding (not Home).
3. Complete onboarding, revisit Sign-in via chip, tap CTA again → straight to
   Home.

## States (2026-07-04, DESIGN.md State Specs 2-3)

In-flight: button disabled + spinner; cancel returns to idle, no error.
Auth error: `Sign-in failed - try again.` Offline: `You're offline -
connect and retry.` Distinct copies, meta size, `--exam-red`.
