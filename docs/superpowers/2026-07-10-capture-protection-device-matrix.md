# Content Capture Protection - Manual Device Matrix (founder gate)

Branch `feat/content-capture-protection` @ `ea0d8a1`. Five code commits complete and reviewed;
Dart suite 170/170; iOS release build compiles here; Android was NOT compiled here (no Android
SDK on the build machine). **Native capture-blocking cannot be claimed to work until this matrix
passes on physical hardware.** Simulators/emulators are not trustworthy for the iOS secure-layer
effect; the Android emulator does honor FLAG_SECURE.

This is an uncommitted handoff artifact. Record results in the PR body, keep it, or delete it.

## What was built

- Dart identity watermark (signed-in email, tiled faint) on the reader view and the diagram viewer - deters external-camera photos (the "analog hole" no software blocks).
- Android `FLAG_SECURE`, release builds only - blocks screenshots, recording, app-switcher preview.
- iOS secure-`UITextField`-layer wrap, release builds only - system capture grabs a blank frame.
- Debug builds stay fully capturable (QA/marketing). No new dependencies. No Dart-native channel.

---

## Matrix - run every row on a PHYSICAL device, record pass/fail

Order matters: build first, then behavior.

- [ ] **Android release build compiles.** `flutter build apk --release` on an SDK machine. This is the FIRST real compile of `MainActivity.kt` + the `buildFeatures { buildConfig = true }` fix (AGP 9.0.1 defaults buildConfig off). If it errors on `BuildConfig`, that fix is where to look.
- [ ] **Android release screenshot** - open reader, try a screenshot. Expect: system refuses ("Can't take screenshot due to security policy") or saves black.
- [ ] **Android release recording / `adb exec-out screencap`** - while reader open. Expect: black frames.
- [ ] **Android app switcher** - background the app. Expect: preview blank/black.
- [ ] **iOS release screenshot** - `flutter run --release -d <iphone>`, screenshot the reader. Expect: Photos shows a blank/black image.
- [ ] **iOS release screen recording** - Control Center record over the reader. Expect: blank recording.
- [ ] **iOS app switcher** - background the app. Expect: no content visible. (If it leaks, apply plan Task 6 Step 4 - the app-switcher cover edit.)
- [ ] **Debug builds, both platforms** - `flutter run` (debug), screenshot. Expect: captures work normally.
- [ ] **Watermark, light + dark** - reader + diagram viewer in both themes. Expect: faint tiled email visible; body text plainly readable.

## Additions the final review surfaced (each targets a risk source review could not settle)

- [ ] **iOS paired assertion: live screen READABLE while the capture is BLANK.** The layer-reparent trick done wrong can blank the _real_ screen too (fail-closed). Confirm content is readable on-device at the exact moment the screenshot comes out blank.
- [ ] **iOS: exercise BOTH OS branches on real hardware.** Code branches on iOS 17 (`.last`) vs below (`.first`); deployment target is 13.0, so the pre-17 path is live. A pass on one iOS generation does not validate the other - test a pre-17 device (or lowest supported) AND a 17+ device.
- [ ] **iOS: the empty secure field never steals first responder / breaks text entry** (search field, sign-in) in a release build.
- [ ] **iOS: background -> foreground 2-3 times, incl. an app-switcher resume and a lock/Control-Center interruption.** Confirm every capture stays blank, not just the first. (Tests the latched one-shot `secured` guard - see decision D1.)
- [ ] **Traceability over a REAL dark diagram** - photograph the diagram viewer with an external camera on a dark/black-background figure (ultrasound, black line drawing). Judge whether the email is actually legible, not just "faint email visible" generically. (Empirical input to decision D2.)

---

## Decisions for you (not blockers to the matrix, but to production)

**D1 - iOS silent fail-open (Important, fast-follow before ANY production release).**
`SceneDelegate.swift` sets `secured = true` _before_ the layer surgery runs, and every reparent step is an unguarded optional chain. If an optional is nil on first activation (plausible UIKit timing, or a future-iOS sublayer-order change), the reparent no-ops, `secured` latches true, and it never retries that session - the app renders normally but stays fully capturable, visually identical to success on the live screen. The only way you'd ever notice is an actual captured screenshot. Fix: set `secured = true` only after a verified-non-nil reparent, and emit a release-visible `os_log` on the nil branches (a debug `assert` is dead code here - the block is `#if !DEBUG`). Decide after the matrix confirms the happy path blanks.

**D2 - watermark over dark diagrams (design decision, fast-follow).**
The watermark is `dm.ink` (near-black) at 5%/7% alpha - tuned for legibility over the white reader answer. Over a dark diagram image it may be near-invisible and therefore not traceable, exactly on the higher-value leak target. This is a spec limitation, not an implementation bug (the plan fixed the color law and forbade touching `WatermarkPainter`). If matrix row "traceability over a real dark diagram" fails, a follow-up visual pass is needed (contrast-adaptive alpha, a thin light/dark outline, or a faint scrim behind the diagram) - needs design sign-off.

**D3 - merge timing.** The final review says "ready to merge, with the device matrix as a mandatory pre-release gate." You can merge the branch now and treat the matrix + D1 as release gates, or hold the merge until the matrix passes. Your call.

## Cheap fast-follows (bundle whenever the files are next touched)

- Dark-mode alpha test (one `dmDarkTheme()` variant of the painter test).
- Dispose the `ui.Image` in the pixel test.
- Long-email tile overlap: `_hSpacing` is a fixed 180px; a ~45-char institutional email (~290px) overlaps the next column and slightly degrades traceability - derive spacing from laid-out text width.
