# Content Capture Protection - Design

Date: 2026-07-10
Status: Approved (brainstorm session with founder)

## Context

DiploMate's moat is its content: verbatim, licensed QnA material rendered in
the reader (`app/lib/ui/reader/`). The founder wants users prevented from
screenshotting the QnA section and deterred from photographing it with another
device's camera.

## Requirements (recalibrated against what is technically possible)

1. **Screenshots and screen recordings of app content must not capture
   content** in release builds, on both Android and iOS.
2. **Photos taken with another device's camera cannot be blocked by any
   software** (the analog hole; no app, including Netflix or banking apps, can
   do this). The agreed mitigation is deterrence: content is overlaid with a
   faint tiled watermark of the logged-in user's email, so any leaked photo
   identifies the account that leaked it.

Decision: protection level = capture block + identity watermark
(founder-approved 2026-07-10).

## Non-goals

- Blocking external-camera photography (impossible; watermark is the answer).
- Screenshot-attempt telemetry / account flagging (deferred; can be added
  later on iOS via `userDidTakeScreenshotNotification`).
- DRM, code obfuscation, root/jailbreak detection.
- Watermarking on screens that show only fragments (search results,
  bookmarks, syllabus). The app-wide capture block already covers them.

## Behavior matrix

| Surface                                               | Release build                                                                                       | Debug build                   |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------- |
| Android screenshot / recording / app-switcher preview | Blocked by `FLAG_SECURE`                                                                            | Allowed (QA, marketing shots) |
| iOS screenshot / screen recording                     | Captures blank/black (secure-layer wrap)                                                            | Allowed                       |
| iOS app-switcher snapshot                             | No content visible (verify; add a lifecycle cover view if the secure layer alone does not blank it) | Normal                        |
| External camera photo of reader                       | Possible but traceable: tiled email watermark visible                                               | Same                          |

The capture block is app-wide. The watermark renders only where verbatim
content is displayed: the reader view and the diagram viewer.

## Components

### 1. Android capture block

`app/android/.../MainActivity.kt`: in `onCreate`, add
`WindowManager.LayoutParams.FLAG_SECURE` to the window, gated on
`!BuildConfig.DEBUG`. Two lines, official platform API. Also disables casting
and screen share for the app, which is intended.

### 2. iOS capture block

`app/ios/Runner/AppDelegate.swift`: wrap the key window's layer in a secure
`UITextField` layer (`isSecureTextEntry = true`) at launch, gated
`#if !DEBUG`. Roughly 30 lines of Swift. This is the industry-standard
technique used by banking and OTT apps: screenshots and recordings capture a
blank frame. It relies on unofficial-but-stable UIKit behavior; App Store
review risk is low (widely shipped), but the technique must be re-verified on
each major iOS release.

No Dart-to-native channel is needed on either platform; both blocks are set
once at launch in native code.

### 3. Identity watermark (Flutter)

New widget `ContentWatermark` (about 60 lines of Dart), placed above the
reader content and the diagram viewer via a `Stack`:

- `IgnorePointer` + `CustomPaint`; painter tiles the user's email rotated
  -30 degrees across the viewport.
- Stationary overlay (does not scroll with content) - cheaper to paint, and
  camera photos still capture it.
- Text source: the existing session-user provider (`SessionUser.email`).
  Fallback when null: the app name. The watermark must never block reading.
- Excluded from semantics; zero accessibility impact.

## Watermark visual spec (DESIGN.md-compliant)

- Font: Manrope, about 12px.
- Color: ink at ~5% opacity in light theme, ~7% in dark theme.
- Tile spacing: generous, about 180px between repeats.
- Constraints honored: body contrast stays >= 4.5:1, answer-on-white
  signature untouched, no gradients or shadows (color law 6), red never used.

## Edge cases and risks

- **Sentry**: verify session replay / screenshot attachment stays disabled so
  content never leaks through telemetry.
- **Dev auth bypass**: fake user watermarks as `ananya@example.com`;
  acceptable for QA.
- **Apple review / iOS updates**: secure-layer trick is unofficial behavior.
  Mitigation: manual verify on each iOS major; if it ever breaks, fall back to
  screenshot detection + warning while a fix is found.
- **Integration tests** run in debug builds and are unaffected by the block.

## Success criteria

1. Android release build: screenshot attempt is blocked by the system;
   screen recording shows black; app switcher shows no content.
2. iOS release build: screenshot in Photos is blank; screen recording is
   blank; app switcher shows no content.
3. Debug builds on both platforms: screenshots work normally.
4. Reader and diagram viewer show the tiled email watermark in both themes;
   text readability and contrast are visually unchanged.
5. Widget test passes: watermark renders the session email, and falls back
   gracefully when the user is null.
6. Existing test suite stays green.
