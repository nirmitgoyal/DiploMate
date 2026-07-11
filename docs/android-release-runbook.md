# Android release runbook

What `docs/release-checklist.md` does not cover: keystore, local release
builds, and the on-device capture-protection matrix. Console-side setup
(OAuth clients, consent screen, Play Console, Data Safety, listing, release
smoke) lives in `docs/release-checklist.md` - run that checklist for every
rollout; run this runbook for machine setup and local builds.

Placeholders follow the checklist's conventions: `<web-client-id>` = the
Google Cloud WEB OAuth client id.

## 1. One-time: upload keystore

Generate (choose real passwords; store them in your password manager):

```bash
mkdir -p ~/keystores
keytool -genkey -v -keystore ~/keystores/diplomate-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10950 -alias upload
```

Then `cp app/android/key.properties.example app/android/key.properties`
and fill in the real values. `key.properties` and `*.jks` are gitignored -
NEVER commit either. Losing this keystore is recoverable (Play App Signing
lets you register a new upload key via support), but treat it as precious.

Upload-key SHA-1 (needed for the ANDROID OAuth client, checklist section 1):

```bash
keytool -list -v -keystore ~/keystores/diplomate-upload.jks -alias upload | grep "SHA1:"
```

## 2. One-time: iOS OAuth client swap (bundle id renamed 2026-07-11)

The iOS bundle id is now `com.diplomate.app`; the iOS OAuth client baked
into `app/ios/Runner/Info.plist` still belongs to the old
`com.diplomate.diplomate` client, so iOS Google sign-in fails until:

1. Google Cloud Console -> Credentials -> Create OAuth client -> iOS,
   bundle id `com.diplomate.app`.
2. In `app/ios/Runner/Info.plist` replace BOTH values:
   - `GIDClientID`: the new client id
     (`<number>-<hash>.apps.googleusercontent.com`)
   - the `CFBundleURLSchemes` entry: the same id REVERSED
     (`com.googleusercontent.apps.<number>-<hash>`)
3. Commit those two lines.

## 3. Per-release: build the bundle

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://diplomate-api.herokuapp.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Output: `app/build/app/outputs/bundle/release/app-release.aab`. Upload via
Play Console -> Testing (checklist sections 3-6). The build FAILS with
`android/key.properties not found` if section 1 was skipped - that is by
design; never work around it by debug-signing.

Both dart-defines are REQUIRED: omitting them builds successfully but
ships an app with an empty backend URL and empty OAuth audience - sign-in
always fails (this bit the 2026-07-10 iOS device run).

## 4. Device capture-protection matrix (Android)

Run on a physical phone after any change to MainActivity, the reader, the
watermark, or before any Play upload. Debug builds are intentionally
capturable (FLAG_SECURE is `!BuildConfig.DEBUG`); test a RELEASE build.

Local-server recipe (no console clients needed): see
"On-device fake-auth run recipe" in the capture-protection notes - start
`server/` with `DEV_FAKE_AUTH=true`, build with
`--dart-define=API_BASE_URL=http://<MAC-LAN-IP>:3000 --dart-define=DEV_FAKE_AUTH=true`.
Release builds block cleartext http: temporarily add
`android:usesCleartextTraffic="true"` to the `<application>` tag of
`app/android/app/src/main/AndroidManifest.xml` for the test run, then
`git restore` it BEFORE committing anything. Never ship that flag.

| #   | Check                                       | Pass looks like                                        |
| --- | ------------------------------------------- | ------------------------------------------------------ |
| 1   | Screenshot (power+voldown) on reader answer | System blocks it / captured image is black             |
| 2   | Screen recording started, browse reader     | Recording plays back black over content                |
| 3   | App switcher (recents) card                 | Card is blank/secure, no content visible               |
| 4   | Live screen while using app                 | Fully readable (protection must not fail closed)       |
| 5   | Watermark on answer + diagram views         | Session email tiled, faint but legible up close        |
| 6   | Notification permission prompt on first run | Appears; accepting schedules the daily reminder        |
| 7   | Google sign-in (release, Play-installed)    | Succeeds - needs checklist section 1 SHA-1s registered |

Record each run's results (date, device, OS, pass/fail per row) at the
bottom of this file.

## 5. Results log

| Date | Device | OS  | Rows passed | Notes |
| ---- | ------ | --- | ----------- | ----- |
