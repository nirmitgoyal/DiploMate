# Android Prod-Ready (Play Closed Beta) - Design

**Date:** 2026-07-11
**Status:** Approved by founder (section-by-section, this session)
**Finish line:** A release-signed `.aab` that is uploadable to Play closed
testing, with sign-in, sync, notifications, and capture protection verified
on a physical Android phone. Manual upload flow per TODOS.md v1 plan
(billing and CI/CD stay deferred, TODO #1).

## Context

The Flutter app builds and runs on iOS (verified on device 2026-07-09/10).
The Android side is still the untouched Flutter template plus the
capture-protection FLAG_SECURE code from PR #5. Known gaps found in this
session's exploration:

1. `INTERNET` permission exists only in the debug manifest. A release build
   has no network: Dio API calls, Sentry, and Google sign-in all fail.
2. `flutter_local_notifications` v17 requires core library desugaring;
   `app/android/app/build.gradle.kts` does not enable it. Android 13+ also
   needs `POST_NOTIFICATIONS` in the manifest and the plugin's receivers for
   scheduled notifications to survive reboot.
3. Release builds sign with debug keys (template TODO still in place).
4. `applicationId` is the template-ish `com.diplomate.diplomate`.
5. App label is lowercase "diplomate" with the default Flutter icon on both
   platforms. `logos/export/logo-1024.png` exists and is the approved source.
6. Google Cloud has no Android OAuth client; Dart passes the web
   `serverClientId` via `--dart-define=GOOGLE_SERVER_CLIENT_ID`.
7. Capture protection code is in `MainActivity.kt` (release-only
   FLAG_SECURE) but has never been verified on an Android device.

## Decisions (founder-approved)

- **D1 - Scope:** One hardening slice, one PR. Blockers, branding, runbook,
  and device verification together.
- **D2 - Application id:** `com.diplomate.app` on BOTH platforms. Android:
  `applicationId`, `namespace`, and Kotlin package all rename. iOS:
  `PRODUCT_BUNDLE_IDENTIFIER` renames too (nothing shipped to App Store, so
  now is the only cheap moment); this requires a new iOS OAuth client and a
  `GIDClientID` + URL-scheme swap in `Info.plist`.
- **D3 - Branding:** Label/display name "DiploMate" on both platforms.
  Launcher icons (including Android adaptive icon and the iOS AppIcon set)
  generated one-shot from `logos/export/logo-1024.png` via
  `flutter_launcher_icons` as a dev dependency.
- **D4 - Signing:** Upload keystore generated locally via `keytool` (founder
  owns the passwords). `key.properties` and `*.jks` are gitignored;
  `key.properties.example` is committed. The release build type reads
  `key.properties` and FAILS HARD when it is missing - no debug-key
  fallback, because the first Play upload permanently enrolls the upload
  key.
- **D5 - Distribution:** Manual `flutter build appbundle` + Play Console
  upload, per TODOS.md. No CI/CD in this slice.

## Components

### 1. Android release config (`app/android/`)

- `app/src/main/AndroidManifest.xml`: add `INTERNET` permission,
  `POST_NOTIFICATIONS` permission, and the `flutter_local_notifications`
  scheduled-notification receivers (`ScheduledNotificationReceiver`,
  `ScheduledNotificationBootReceiver` with `RECEIVE_BOOT_COMPLETED`).
  No exact-alarm permission: `NotificationService` uses
  `inexactAllowWhileIdle`.
- `app/build.gradle.kts`: enable core library desugaring + add
  `desugar_jdk_libs`; rename `namespace`/`applicationId` to
  `com.diplomate.app`; add `signingConfigs.release` reading
  `key.properties` with an explicit error when absent; wire it to the
  release build type.
- Kotlin package move: `com/diplomate/diplomate/MainActivity.kt` ->
  `com/diplomate/app/MainActivity.kt` with the package statement updated.
  FLAG_SECURE logic unchanged.
- `android/.gitignore`: `key.properties`, `*.jks`, `*.keystore`.

### 2. iOS rename + branding parity (`app/ios/`)

- `PRODUCT_BUNDLE_IDENTIFIER`: `com.diplomate.diplomate` ->
  `com.diplomate.app` (Runner; RunnerTests follows as
  `com.diplomate.app.RunnerTests`).
- `Info.plist`: `CFBundleDisplayName` -> "DiploMate"; `GIDClientID` and the
  reversed-client-id URL scheme swap to the NEW iOS OAuth client once the
  founder creates it (runbook step). Until then iOS sign-in is broken on
  the renamed bundle - acceptable, nothing is shipped.
- AppIcon set regenerated from `logos/export/logo-1024.png`.

### 3. Branding (`app/`)

- `flutter_launcher_icons` dev dependency with its config block in
  `pubspec.yaml`, run once, generated icons committed, both platforms.
  Android `android:label` -> "DiploMate".

### 4. Founder runbook (`docs/android-release-runbook.md`)

`docs/release-checklist.md` ALREADY covers the Google Cloud console
clients, consent screen, Play Console setup, Data Safety form, store
listing, and release smoke. The runbook does not duplicate any of it. It
contains only what that checklist lacks:

1. `keytool` command to generate the upload keystore; fill in
   `key.properties` from the example file.
2. Release build recipe:
   `flutter build appbundle --release
--dart-define=API_BASE_URL=https://diplomate-api.herokuapp.com
--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`
   (same placeholder conventions as the release checklist).
3. Device capture-protection verification matrix (section 5 below),
   mirroring the 2026-07-10 iPhone run.
4. Pointers into `docs/release-checklist.md` for everything console-side.

`docs/release-checklist.md` itself gets three surgical edits in this
slice:

- Package name `com.diplomate.diplomate` -> `com.diplomate.app`
  (sections 1 and 3).
- New section 1 checkbox: the **upload keystore's** SHA-1 is registered
  on the ANDROID OAuth client (alongside debug and Play App Signing
  SHA-1s).
- New section 1 checkbox: the new **iOS** OAuth client for
  `com.diplomate.app` exists and its id matches `GIDClientID` in
  `Info.plist`.

### 5. Verification (physical Android phone in hand)

- Static: `flutter analyze` clean; full test suite green (no regression to
  the existing 163+ tests).
- Debug build on phone: sign-in (fake-auth recipe until console clients
  exist, then real Google sign-in), speciality activation, pack sync/study
  loop against the Heroku backend, scheduled notification fires, watermark
  visible on answer views.
- Release-signed build on phone: screenshot blocked, screen recording
  black, app-switcher preview blank (FLAG_SECURE matrix, mirroring the
  2026-07-10 iPhone run); real sign-in works with the registered SHA-1.
- iOS regression after the bundle-id rename: app builds and Google sign-in
  works with the new iOS OAuth client.
- `flutter build appbundle` produces a signed `.aab` - the uploadable
  artifact.

## Error handling

- Missing `key.properties` on a release build: Gradle fails with a message
  naming the runbook, never silently debug-signs.
- Missing dart-defines produce empty `API_BASE_URL`/`GOOGLE_SERVER_CLIENT_ID`
  at runtime today (existing behavior); the runbook recipe is the guard.
  No new runtime validation code in this slice.
- `DEV_FAKE_AUTH` defaults to false via `bool.fromEnvironment`; release
  recipe simply omits it. No code change needed.

## Out of scope

Billing and paywall, CI/CD pipeline (both TODO #1), Play listing creative
and screenshots (founder work), FSRS migration (TODO #2), pre-iOS-17
capture fallback, D1 os_log audit (iOS), cohort recruiting (TODO #4).

## Open items for the founder (non-code)

- Run the keystore + Google Cloud console + Play Console runbook steps;
  the code slice is complete without them but real-auth device
  verification and the actual upload wait on the console clients.
