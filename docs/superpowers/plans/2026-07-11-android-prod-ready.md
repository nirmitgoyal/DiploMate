# Android Prod-Ready (Play Closed Beta) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A release-signed `.aab` uploadable to Play closed testing, with sign-in, sync, notifications, and capture protection verified on a physical Android phone.

**Architecture:** Pure config/packaging slice - no new Dart runtime code. Android manifest + Gradle hardening, application-id rename on both platforms, one-shot icon generation, docs (runbook + checklist edits), then an on-device verification matrix. Spec: `docs/superpowers/specs/2026-07-11-android-prod-ready-design.md`.

**Tech Stack:** Flutter 3.44.4, AGP 9.0.1 (Kotlin DSL, `newDsl=false`, `builtInKotlin=false`), Gradle 9.1.0, Kotlin 2.3.20, JDK 21 (present at `/Library/Java/JavaVirtualMachines/temurin-21.jdk`), flutter_local_notifications 17.2.4, google_sign_in 7.2.0, flutter_launcher_icons ^0.14.4.

## Global Constraints

- Application id is exactly `com.diplomate.app` on BOTH platforms (Android `namespace`+`applicationId`, iOS `PRODUCT_BUNDLE_IDENTIFIER`).
- User-visible app name is exactly `DiploMate`.
- Release builds FAIL HARD without `android/key.properties` - never debug-sign a release artifact (first Play upload permanently enrolls the upload key).
- NEVER commit: `key.properties`, `*.jks`, `*.keystore`, iOS `DEVELOPMENT_TEAM` pbxproj edits, or the temporary cleartext manifest edit from Task 9. `app/android/.gitignore` already covers the keystore files - do not weaken it.
- `MainActivity.kt` FLAG_SECURE logic is behaviorally untouched (package rename only). `buildFeatures { buildConfig = true }` must survive every build.gradle.kts edit.
- No em-dashes or en-dashes anywhere (code, docs, commit messages) - plain hyphens only.
- All commands run from `/Users/nirmit/Codebases/DiploMate/app` unless stated otherwise. This machine's `find` is proxied by rtk and rejects `-exec`/`-not`; prefix with `command ` (e.g. `command find`) when you need real find.
- Working tree: execute on a feature branch (e.g. `feat/android-prod-ready`) created from `main`.

---

### Task 1: Android toolchain on this Mac

The machine has NO Android SDK (`flutter doctor` shows "Unable to locate Android SDK"; `adb` not on PATH). Nothing Android-side can compile until this lands. JDK 21 is already installed system-wide.

**Files:**

- None in the repo (host setup only; `flutter config` writes to `~/.config/flutter/settings`).

**Interfaces:**

- Produces: working `flutter build apk` toolchain + `adb` for every later task.

- [ ] **Step 1: Install Android command-line tools via Homebrew**

```bash
brew install --cask android-commandlinetools
```

Expected: installs to `/opt/homebrew/share/android-commandlinetools`.

- [ ] **Step 2: Install platform-tools (adb) and accept licenses**

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
sdkmanager --install "platform-tools"
flutter config --android-sdk /opt/homebrew/share/android-commandlinetools
yes | flutter doctor --android-licenses
```

Expected: licenses all accepted. (AGP auto-downloads the exact platform/build-tools/NDK versions it needs on first build - do not pre-install platforms.)

- [ ] **Step 3: Verify doctor is green for Android**

```bash
flutter doctor
/opt/homebrew/share/android-commandlinetools/platform-tools/adb --version
```

Expected: `[✓] Android toolchain - develop for Android devices` and an adb version string. If doctor complains about a missing `cmdline-tools component`, run `sdkmanager --install "cmdline-tools;latest"` and re-check.

- [ ] **Step 4: Nothing to commit** (host-only task; confirm `git status` in the repo is clean).

---

### Task 2: Release-blocker manifest permissions + desugaring

A release build currently has NO network (INTERNET permission lives only in the debug manifest) and `flutter_local_notifications` 17.x will not compile without core library desugaring. This is also the first-ever Android compile of the FLAG_SECURE code from PR #5.

**Files:**

- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/debug/AndroidManifest.xml`
- Modify: `app/android/app/build.gradle.kts`

**Interfaces:**

- Produces: `flutter build apk --debug` and `--release` compile green; manifest carries `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` + the plugin's two receivers.

- [ ] **Step 1: Baseline build (isolates pre-existing breakage from this task's edits)**

```bash
flutter build apk --debug
```

Expected: SUCCESS (proves PR #5's MainActivity + buildConfig compile). If it fails, fix the baseline first and note the cause in the commit message - do not mix baseline fixes into Step 2's edits. Likely baseline culprits: SDK licenses (rerun Task 1 Step 2), first-run NDK/platform downloads (slow, let them finish).

- [ ] **Step 2: Add permissions + receivers to the main manifest**

In `app/android/app/src/main/AndroidManifest.xml`, add the three `<uses-permission>` lines directly after the opening `<manifest ...>` tag, and the two `<receiver>` blocks directly before `</application>` (after the `flutterEmbedding` meta-data):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

```xml
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

No exact-alarm permission: `NotificationService` uses `AndroidScheduleMode.inexactAllowWhileIdle` (`app/lib/services/notification_service.dart:118`).

- [ ] **Step 3: Allow cleartext LAN traffic in DEBUG builds only**

The on-device dev loop talks to a local server over `http://<LAN-IP>:3000` (same reason iOS has `NSAllowsLocalNetworking`). Android API 28+ blocks cleartext by default in every build type. Edit `app/android/app/src/debug/AndroidManifest.xml` to:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The INTERNET permission is required for development. Specifically,
         the Flutter tool needs it to communicate with the running application
         to allow setting breakpoints, to provide hot reload, etc.
    -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Dev loop talks to a local API server over plain http on the LAN
         (same intent as iOS NSAllowsLocalNetworking). Debug builds only -
         this overlay never reaches a release artifact. -->
    <application android:usesCleartextTraffic="true"/>
</manifest>
```

- [ ] **Step 4: Enable core library desugaring**

In `app/android/app/build.gradle.kts`, change the `compileOptions` block to:

```kotlin
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 17.x uses java.time; AGP requires
        // desugaring for it below API 26.
        isCoreLibraryDesugaringEnabled = true
    }
```

and add a top-level `dependencies` block at the end of the file (after the `flutter { ... }` block):

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Step 5: Build both variants to verify**

```bash
flutter build apk --debug
flutter build apk --release
```

Expected: both SUCCESS. (Release still debug-signs at this point - Task 4 fixes that.) Then confirm the merged release manifest carries the permissions and NOT the cleartext flag:

```bash
grep -c "INTERNET\|POST_NOTIFICATIONS\|RECEIVE_BOOT_COMPLETED" \
  build/app/intermediates/merged_manifests/release/*/AndroidManifest.xml
grep -c "usesCleartextTraffic" \
  build/app/intermediates/merged_manifests/release/*/AndroidManifest.xml || echo "cleartext absent: OK"
```

Expected: first grep >= 3; second prints `cleartext absent: OK` (grep exits nonzero).

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/debug/AndroidManifest.xml android/app/build.gradle.kts
git commit -m "fix(android): release manifest permissions + notification receivers + desugaring"
```

---

### Task 3: Application id rename to com.diplomate.app (Android)

Founder decision D2: permanent id is `com.diplomate.app`. Must land BEFORE anything is uploaded to Play or registered in Google Cloud.

**Files:**

- Modify: `app/android/app/build.gradle.kts` (namespace, applicationId; drop the two template TODO comments)
- Move: `app/android/app/src/main/kotlin/com/diplomate/diplomate/MainActivity.kt` -> `app/android/app/src/main/kotlin/com/diplomate/app/MainActivity.kt`

**Interfaces:**

- Produces: Android package/application id `com.diplomate.app` - consumed verbatim by Task 7's docs and by the founder's Google Cloud + Play Console setup.

- [ ] **Step 1: Rename namespace + applicationId in build.gradle.kts**

In `app/android/app/build.gradle.kts`:

```kotlin
    namespace = "com.diplomate.app"
```

and in `defaultConfig`, replacing the template TODO comment above it:

```kotlin
        // Permanent id - enrolled in Play Console and Google OAuth clients.
        // Never change after the first Play upload.
        applicationId = "com.diplomate.app"
```

- [ ] **Step 2: Move the Kotlin source to the new package**

```bash
mkdir -p android/app/src/main/kotlin/com/diplomate/app
git mv android/app/src/main/kotlin/com/diplomate/diplomate/MainActivity.kt android/app/src/main/kotlin/com/diplomate/app/MainActivity.kt
rmdir android/app/src/main/kotlin/com/diplomate/diplomate
```

Then edit line 1 of the moved file: `package com.diplomate.diplomate` -> `package com.diplomate.app`. Touch nothing else in the file.

- [ ] **Step 3: Verify no stale references**

```bash
grep -rn "com.diplomate.diplomate" android/
```

Expected: no matches.

- [ ] **Step 4: Build to verify**

```bash
flutter build apk --debug
```

Expected: SUCCESS.

- [ ] **Step 5: Commit**

```bash
git add -A android/
git commit -m "feat(android): rename application id to com.diplomate.app"
```

---

### Task 4: Release signing - fail hard without key.properties

Founder decision D4. The release build type reads `android/key.properties`; a missing file must abort `assembleRelease`/`bundleRelease` with a message naming the runbook - NOT fall back to debug signing, and NOT produce an unsigned artifact.

**Files:**

- Modify: `app/android/app/build.gradle.kts`
- Create: `app/android/key.properties.example`

**Interfaces:**

- Consumes: `android/key.properties` (gitignored, created by the founder per Task 7's runbook) with keys `storeFile`, `storePassword`, `keyPassword`, `keyAlias`.
- Produces: signed release artifacts; the exact error message `android/key.properties not found - release builds must be signed with the upload keystore. See docs/android-release-runbook.md.`

- [ ] **Step 1: Create the example file**

Create `app/android/key.properties.example`:

```properties
# Copy to android/key.properties (gitignored) and fill in.
# Generate the keystore first - see docs/android-release-runbook.md.
storeFile=/Users/nirmit/keystores/diplomate-upload.jks
storePassword=CHANGE-ME
keyPassword=CHANGE-ME
keyAlias=upload
```

- [ ] **Step 2: Wire signing into build.gradle.kts**

At the top of `app/android/app/build.gradle.kts`, after the `plugins { }` block:

```kotlin
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
```

(Kotlin DSL note: the `import` must be the FIRST statement in the file, above `plugins { }`.)

Inside `android { }`, add before `buildTypes`:

```kotlin
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
```

Replace the whole `buildTypes` block (deleting the template TODO comment and the debug-key line):

```kotlin
    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // No else: a guard task below fails release builds instead of
            // letting them debug-sign or emit an unsigned artifact.
        }
    }
```

At the very end of the file (after the `dependencies { }` block from Task 2), add:

```kotlin
// Release artifacts must never fall back to debug signing: the first Play
// upload permanently enrolls the upload key. Fail with a pointer instead.
tasks.configureEach {
    if ((name == "assembleRelease" || name == "bundleRelease") && !keystorePropertiesFile.exists()) {
        doFirst {
            throw GradleException(
                "android/key.properties not found - release builds must be signed " +
                    "with the upload keystore. See docs/android-release-runbook.md."
            )
        }
    }
}
```

- [ ] **Step 3: Verify the failure path (no key.properties)**

```bash
ls android/key.properties 2>/dev/null || echo "absent: OK"
flutter build appbundle --release
```

Expected: `absent: OK`, then BUILD FAILURE whose output contains `android/key.properties not found` and `docs/android-release-runbook.md`. Also verify debug is unaffected:

```bash
flutter build apk --debug
```

Expected: SUCCESS.

- [ ] **Step 4: Verify the success path with a throwaway keystore**

```bash
SCRATCH=/private/tmp/claude-501/-Users-nirmit-Codebases-DiploMate/b6d847cc-d46b-4974-888e-5c3ee201686e/scratchpad
keytool -genkey -v -keystore "$SCRATCH/throwaway.jks" -keyalg RSA -keysize 2048 -validity 30 \
  -alias upload -storepass throwaway123 -keypass throwaway123 \
  -dname "CN=throwaway, OU=dev, O=dev, L=dev, S=dev, C=IN"
printf 'storeFile=%s/throwaway.jks\nstorePassword=throwaway123\nkeyPassword=throwaway123\nkeyAlias=upload\n' "$SCRATCH" > android/key.properties
flutter build appbundle --release
```

Expected: SUCCESS, artifact at `build/app/outputs/bundle/release/app-release.aab`. Confirm it is signed with the throwaway cert:

```bash
jarsigner -verify -verbose:summary build/app/outputs/bundle/release/app-release.aab | tail -5
```

Expected: `jar verified` (a self-signed-certificate warning is fine).

- [ ] **Step 5: Confirm key.properties is not committable, then remove it**

```bash
git check-ignore android/key.properties && echo "ignored: OK"
rm android/key.properties
```

Expected: `ignored: OK`. (Keep `$SCRATCH/throwaway.jks` - Task 9's release-build steps reuse it.)

- [ ] **Step 6: Commit**

```bash
git add android/app/build.gradle.kts android/key.properties.example
git commit -m "feat(android): upload-keystore release signing, fail hard without key.properties"
```

---

### Task 5: Branding - "DiploMate" label + launcher icons (both platforms)

Founder decision D3. Source of truth: `logos/export/logo-1024.png` (paper `#F6F8FA` rounded-rect background, teal `#0A6E67` monogram, exam-red `#B4271F` margin rule - all on-system per DESIGN.md).

**Files:**

- Create: `app/assets/icon/icon-1024.png` (copy of the logo; committed so icon regen is reproducible)
- Modify: `app/pubspec.yaml` (dev dep + `flutter_launcher_icons:` config block)
- Modify: `app/android/app/src/main/AndroidManifest.xml` (`android:label`)
- Modify: `app/ios/Runner/Info.plist` (`CFBundleDisplayName`)
- Generated (committed): `app/android/app/src/main/res/mipmap-*/*`, `app/android/app/src/main/res/values/colors.xml` (adaptive background), `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*`

**Interfaces:**

- Produces: user-visible name `DiploMate` and branded icons; Task 9 verifies them on the launcher.

- [ ] **Step 1: Copy the icon source into the app**

```bash
mkdir -p assets/icon
cp ../logos/export/logo-1024.png assets/icon/icon-1024.png
```

(Not added to the `flutter: assets:` runtime bundle - it is generator input only.)

- [ ] **Step 2: Add flutter_launcher_icons dev dep + config**

In `app/pubspec.yaml`, add to `dev_dependencies`:

```yaml
flutter_launcher_icons: ^0.14.4
```

and add this top-level block at the end of the file:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  remove_alpha_ios: true
  image_path: assets/icon/icon-1024.png
  adaptive_icon_background: "#F6F8FA"
  adaptive_icon_foreground: assets/icon/icon-1024.png
```

`#F6F8FA` = the logo's own background = DESIGN.md `--paper`, so the adaptive mask blends seamlessly.

- [ ] **Step 3: Record the default-icon checksums, then generate**

```bash
md5 -q android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
flutter pub get
dart run flutter_launcher_icons
md5 -q android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

Expected: generator prints per-platform success; both md5 values CHANGE (iOS default was `c785f8932297af4acd5f5ccb7630f01c`).

- [ ] **Step 4: Set the visible names**

In `app/android/app/src/main/AndroidManifest.xml`: `android:label="diplomate"` -> `android:label="DiploMate"`.

In `app/ios/Runner/Info.plist`: the `<string>` under `CFBundleDisplayName`: `Diplomate` -> `DiploMate`.

- [ ] **Step 5: Build both platforms to verify nothing broke**

```bash
flutter build apk --debug
flutter build ios --release --no-codesign
```

Expected: both SUCCESS. (`remove_alpha_ios: true` keeps App Store icon validation happy; the iOS build also validates the regenerated asset catalog.)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/icon/ android/app/src/main/res/ android/app/src/main/AndroidManifest.xml ios/Runner/Assets.xcassets/ ios/Runner/Info.plist
git commit -m "feat: DiploMate branding - app label and launcher icons from logos/export"
```

---

### Task 6: iOS bundle id rename to com.diplomate.app

Founder decision D2, iOS half. Nothing has shipped to the App Store, so this is the only cheap moment. The existing `GIDClientID` in Info.plist stays for now (it belongs to the OLD bundle's iOS OAuth client); the founder swaps it after creating the new iOS client - runbook step in Task 7. iOS Google sign-in is knowingly broken until that swap; spec accepts this.

**Files:**

- Modify: `app/ios/Runner.xcodeproj/project.pbxproj` (6 occurrences: 3x Runner, 3x RunnerTests)

**Interfaces:**

- Produces: iOS bundle id `com.diplomate.app` - consumed by Task 7's checklist edit and the founder's new iOS OAuth client.

- [ ] **Step 1: Replace every occurrence**

```bash
sed -i '' 's/com\.diplomate\.diplomate/com.diplomate.app/g' ios/Runner.xcodeproj/project.pbxproj
grep -c "com.diplomate.app" ios/Runner.xcodeproj/project.pbxproj
grep -rn "com.diplomate.diplomate" ios/
```

Expected: count 6 (3 Runner + 3 RunnerTests, which become `com.diplomate.app.RunnerTests`); final grep: no matches.

- [ ] **Step 2: Build to verify**

```bash
flutter build ios --release --no-codesign
```

Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(ios): rename bundle id to com.diplomate.app"
```

---

### Task 7: Docs - release runbook + release-checklist edits

`docs/release-checklist.md` already owns everything console-side (OAuth clients, consent screen, Play Console, Data Safety, listing, smoke). The new runbook contains ONLY what that checklist lacks, plus pointers. The checklist gets three surgical edits.

**Files:**

- Create: `docs/android-release-runbook.md`
- Modify: `docs/release-checklist.md`

**Interfaces:**

- Consumes: Task 4's error message and key.properties format; Task 3/6's `com.diplomate.app`.
- Produces: the founder's copy-paste path from zero to an uploadable `.aab`.

- [ ] **Step 1: Create `docs/android-release-runbook.md` with exactly this content**

````markdown
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
````

- [ ] **Step 2: Edit `docs/release-checklist.md` - package renames**

Replace `com.diplomate.diplomate` with `com.diplomate.app` in both places (section 1 "One **ANDROID** OAuth client exists for package..." and section 3 "The app is created in Play Console under package...").

- [ ] **Step 3: Edit `docs/release-checklist.md` - two new section-1 checkboxes**

After the debug-SHA-1 checkbox (the one ending "...on the ANDROID client in Google Cloud Console."), insert:

```markdown
- [ ] The **upload keystore's** SHA-1 is also registered on the ANDROID
      OAuth client. Get it with
      `keytool -list -v -keystore ~/keystores/diplomate-upload.jks -alias upload | grep "SHA1:"`
      (see `docs/android-release-runbook.md` section 1).
```

At the end of section 1 (after the "Blocking fact" checkbox), append:

```markdown
- [ ] An **iOS** OAuth client exists for bundle id `com.diplomate.app`, and
      its client id matches both `GIDClientID` and the reversed-id URL
      scheme in `app/ios/Runner/Info.plist` (see
      `docs/android-release-runbook.md` section 2).
```

- [ ] **Step 4: Verify internal consistency**

```bash
grep -rn "com.diplomate.diplomate" docs/release-checklist.md docs/android-release-runbook.md
grep -c "android-release-runbook" docs/release-checklist.md
```

Expected: first grep matches ONLY the runbook's section-2 historical mention of the old id; second returns 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add docs/android-release-runbook.md docs/release-checklist.md
git commit -m "docs: android release runbook + checklist updates for com.diplomate.app"
```

---

### Task 8: Full static gate

No new Dart code was written, but pubspec, icons, and both platform configs changed. Gate before device work.

**Files:** none (verification only; fix-forward if anything fails).

- [ ] **Step 1: Analyze**

```bash
cd /Users/nirmit/Codebases/DiploMate/app
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

```bash
flutter test
```

Expected: all tests pass (suite was 170/170 on 2026-07-10). Any failure: fix, rerun, commit the fix with a message explaining root cause.

- [ ] **Step 3: Both release builds**

```bash
SCRATCH=/private/tmp/claude-501/-Users-nirmit-Codebases-DiploMate/b6d847cc-d46b-4974-888e-5c3ee201686e/scratchpad
printf 'storeFile=%s/throwaway.jks\nstorePassword=throwaway123\nkeyPassword=throwaway123\nkeyAlias=upload\n' "$SCRATCH" > android/key.properties
flutter build appbundle --release
flutter build ios --release --no-codesign
rm android/key.properties
```

Expected: both SUCCESS. (Throwaway keystore from Task 4; recreate it if the scratchpad was cleared.)

- [ ] **Step 4: Nothing to commit** unless Steps 1-2 forced fixes.

---

### Task 9: On-device verification matrix (physical Android phone)

Executes runbook section 4 for the first time. Needs: the phone (USB, developer mode + USB debugging enabled), same Wi-Fi as the Mac, local Postgres with the `diplomate_dev` DB (already schema-applied per the 2026-07-10 run).

**Files:**

- Modify: `docs/android-release-runbook.md` (results log row only)
- Temporary NEVER-COMMITTED edit: `app/android/app/src/main/AndroidManifest.xml` (cleartext flag for the release test run)

**Interfaces:**

- Consumes: Task 4's throwaway keystore, Task 7's runbook, the fake-auth server recipe.
- Produces: a filled results-log row - the branch's completion evidence.

- [ ] **Step 1: Start the local fake-auth server** (repo root, separate terminal/background)

```bash
cd /Users/nirmit/Codebases/DiploMate/server
DEV_FAKE_AUTH=true SESSION_JWT_SECRET='{"v1":"dev-secret"}' GOOGLE_WEB_CLIENT_ID=dev-dummy \
  DATABASE_URL=postgres://localhost/diplomate_dev PORT=3000 npm start
```

Verify: `curl -fsS http://localhost:3000/health` returns `{"ok":true}`.

- [ ] **Step 2: Connect the phone**

```bash
export PATH="$PATH:/opt/homebrew/share/android-commandlinetools/platform-tools"
adb devices
ipconfig getifaddr en0
```

Expected: one `device` entry (accept the RSA prompt on the phone); note the Mac's LAN IP.

- [ ] **Step 3: Debug run - functional pass (matrix rows 5-6 + sync loop)**

```bash
cd /Users/nirmit/Codebases/DiploMate/app
flutter run -d <android-device-id> \
  --dart-define=API_BASE_URL=http://<MAC-LAN-IP>:3000 \
  --dart-define=DEV_FAKE_AUTH=true
```

Walk: sign in (fake -> dev@example.com), pick speciality, open a topic, reveal an answer, rate a card. Verify: watermark email tiled on the answer view; notification permission prompt appeared; launcher shows the DiploMate name + new icon; no crash in `flutter run` logs. Server-side: `psql diplomate_dev -c "SELECT count(*) FROM review_events"` grew after the rating.

- [ ] **Step 4: Release build - capture matrix (rows 1-4)**

Temporarily allow cleartext for this run (NEVER commit; mirrors the iOS local-only DEVELOPMENT_TEAM pattern):

In `app/android/app/src/main/AndroidManifest.xml` add `android:usesCleartextTraffic="true"` to the `<application ...>` tag. Then:

```bash
SCRATCH=/private/tmp/claude-501/-Users-nirmit-Codebases-DiploMate/b6d847cc-d46b-4974-888e-5c3ee201686e/scratchpad
printf 'storeFile=%s/throwaway.jks\nstorePassword=throwaway123\nkeyPassword=throwaway123\nkeyAlias=upload\n' "$SCRATCH" > android/key.properties
flutter build apk --release \
  --dart-define=API_BASE_URL=http://<MAC-LAN-IP>:3000 \
  --dart-define=DEV_FAKE_AUTH=true
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

On the phone, sign in and open a reader answer, then run matrix rows 1-4 (screenshot, recording, app switcher, live readability). FLAG_SECURE is active: release build, `BuildConfig.DEBUG == false`.

- [ ] **Step 5: Restore the tree**

```bash
git restore android/app/src/main/AndroidManifest.xml
rm android/key.properties
git status
```

Expected: clean tree (only the runbook row from Step 6 pending).

- [ ] **Step 6: Record results**

Append a row to the runbook's results log (`docs/android-release-runbook.md` section 5): date, device model, Android version, rows 1-6 pass/fail (row 7 stays open - console-gated). Any FAIL: STOP, use superpowers:systematic-debugging, fix, rerun the failed row before proceeding.

```bash
cd /Users/nirmit/Codebases/DiploMate
git add docs/android-release-runbook.md
git commit -m "docs: record first Android device-matrix run"
```

---

### Task 10: Finish the branch

- [ ] **Step 1: Whole-branch review + merge/PR** - use superpowers:finishing-a-development-branch. PR title: `feat: Android prod-ready for Play closed beta`. Body summarizes: blockers fixed (network, desugaring, notifications), `com.diplomate.app` rename both platforms, branding, fail-hard release signing, runbook + checklist docs, device-matrix results.

- [ ] **Step 2: Founder follow-ups (not blocking the merge)** - listed in the PR body as unchecked items: run runbook section 1 (real keystore), checklist section 1 (OAuth clients incl. upload SHA-1 + new iOS client), deploy the backend (health endpoint currently 404), then matrix row 7 (real sign-in on a Play-installed build).
