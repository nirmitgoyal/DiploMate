# Content Capture Protection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block screenshots/recordings of app content in release builds (Android + iOS) and overlay a faint identity watermark on reader content so external-camera photos are traceable to the leaking account.

**Architecture:** Two native launch-time blocks (Android `FLAG_SECURE`, iOS secure-layer wrap), both gated to release builds, no Dart-to-native channel. One pure-Dart overlay widget (`ContentWatermark` + `WatermarkedContent` wrapper) reading the session email from Riverpod, inserted into the reader view and the diagram viewer.

**Tech Stack:** Flutter 3.x / Dart, flutter_riverpod 2.x, Kotlin (Android embedding), Swift (iOS scene-based embedding, `FlutterSceneDelegate`).

**Spec:** `docs/superpowers/specs/2026-07-10-content-capture-protection-design.md`

## Global Constraints

- No new dependencies. Native code is hand-rolled (approach A, founder-approved 2026-07-10).
- Capture block active in RELEASE builds only; debug builds keep screenshots (QA, marketing). Gates: `!BuildConfig.DEBUG` (Kotlin), `#if !DEBUG` (Swift).
- DESIGN.md laws: the 7-step type scale is fixed, so the watermark uses `DmType.meta` verbatim (12.5px Manrope) - do NOT add a new font size. Watermark color is `dm.ink` at alpha 0.05 (light) / 0.07 (dark). No gradients, no shadows, no red.
- The watermark must never block reading: `IgnorePointer`, `ExcludeSemantics`, and a fallback text of `DiploMate` when no user is signed in.
- Watermark renders only on the reader view and the diagram viewer. The native block is app-wide by nature.
- All Flutter commands run from `/Users/nirmit/Codebases/DiploMate/app`.
- Writing convention: plain hyphens only, never em/en dashes, in all code, comments, and docs.
- Commit messages follow the repo's conventional style (`feat(app): ...`) and end with the Claude co-author trailer.

---

### Task 1: ContentWatermark widget + painter (TDD)

**Files:**

- Create: `app/lib/ui/reader/content_watermark.dart`
- Test: `app/test/ui/reader/content_watermark_test.dart`

**Interfaces:**

- Consumes: `sessionUserProvider` (`StateProvider<SessionUser?>`, `app/lib/app_providers.dart:18`), `SessionUser.email` (`String`, `app/lib/data/repos/auth_repository.dart:4`), `DmType.meta` + `context.dm` (`app/lib/theme/tokens.dart`).
- Produces: `class ContentWatermark extends ConsumerWidget` with const no-arg constructor (must be a direct child of a `Stack`); `class WatermarkPainter extends CustomPainter` with `WatermarkPainter({required String text, required Color color})` and public fields `text`, `color`; `class WatermarkedContent extends StatelessWidget` with `WatermarkedContent({Key? key, required Widget child})` wrapping child in a `Stack` with the watermark on top. Tasks 2 and 3 insert `WatermarkedContent`.

- [ ] **Step 1: Write the failing test**

Create `app/test/ui/reader/content_watermark_test.dart`:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/content_watermark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'ananya@example.com', specialityChangeCount: 0);

Widget bareHost({SessionUser? user}) => ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => user)],
      child: MaterialApp(
        theme: dmLightTheme(),
        home: const Scaffold(body: Stack(children: [ContentWatermark()])),
      ),
    );

WatermarkPainter _painterOf(WidgetTester t) {
  final paint = t.widget<CustomPaint>(find.descendant(
      of: find.byType(ContentWatermark), matching: find.byType(CustomPaint)));
  return paint.painter! as WatermarkPainter;
}

void main() {
  testWidgets('watermark tiles the session email', (t) async {
    await t.pumpWidget(bareHost(user: _user));
    expect(_painterOf(t).text, 'ananya@example.com');
  });

  testWidgets('no session user falls back to app name, never blocks render',
      (t) async {
    await t.pumpWidget(bareHost(user: null));
    expect(_painterOf(t).text, 'DiploMate');
  });

  testWidgets('watermark is untappable and invisible to semantics', (t) async {
    await t.pumpWidget(bareHost(user: _user));
    expect(
        find.descendant(
            of: find.byType(ContentWatermark),
            matching: find.byType(IgnorePointer)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ContentWatermark),
            matching: find.byType(ExcludeSemantics)),
        findsOneWidget);
  });

  testWidgets('WatermarkedContent = child + watermark overlay', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: dmLightTheme(),
        home: const Scaffold(
            body: WatermarkedContent(child: Text('the content'))),
      ),
    ));
    expect(find.text('the content'), findsOneWidget);
    expect(find.byType(ContentWatermark), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader/content_watermark_test.dart`
Expected: FAIL - compile error, `content_watermark.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `app/lib/ui/reader/content_watermark.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../theme/tokens.dart';

/// Deterrence overlay (capture-protection spec 2026-07-10). Screenshot
/// BLOCKING is native (FLAG_SECURE / iOS secure layer); this covers the
/// analog hole: an external-camera photo of the screen carries the signed-in
/// user's email, so a leak identifies the leaking account.
///
/// Must be a direct child of a [Stack] (it is a [Positioned.fill]).
class ContentWatermark extends ConsumerWidget {
  const ContentWatermark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fallback keeps the reader usable if the session is ever null here;
    // the watermark degrades, reading never blocks.
    final text = ref.watch(sessionUserProvider)?.email ?? 'DiploMate';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: WatermarkPainter(
              text: text,
              // Whisper-faint: body contrast must stay >= 4.5:1 (DESIGN.md).
              color: context.dm.ink.withValues(alpha: dark ? 0.07 : 0.05),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a content surface with the watermark overlay. StackFit.expand keeps
/// the child filling exactly the space it filled before wrapping.
class WatermarkedContent extends StatelessWidget {
  const WatermarkedContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [child, const ContentWatermark()],
      );
}

class WatermarkPainter extends CustomPainter {
  WatermarkPainter({required this.text, required this.color});

  final String text;
  final Color color;

  static const double _hSpacing = 180;
  static const double _vSpacing = 120;
  static final double _angle = -30 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      // DmType.meta verbatim: the type scale is fixed (DESIGN.md law).
      text: TextSpan(text: text, style: DmType.meta.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.rotate(_angle);
    // Rotated corners extend past (0,0)..(w,h) in rotated coordinates;
    // overscan by the bounding diagonal so tiles reach every corner.
    final diag = size.width + size.height;
    var row = 0;
    for (var y = -diag; y < diag; y += _vSpacing) {
      // ponytail: half-step stagger on odd rows so a cropped photo still
      // catches at least one full email.
      final xOffset = row.isOdd ? _hSpacing / 2 : 0.0;
      for (var x = -diag; x < diag; x += _hSpacing) {
        tp.paint(canvas, Offset(x + xOffset, y));
      }
      row++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WatermarkPainter old) =>
      old.text != text || old.color != color;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader/content_watermark_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/reader/content_watermark.dart app/test/ui/reader/content_watermark_test.dart
git commit -m "feat(app): identity watermark widget (capture-protection spec)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Overlay watermark on the reader view

**Files:**

- Modify: `app/lib/ui/reader/reader_view.dart:135-136` (Scaffold body) and the matching closer near line 428
- Test: `app/test/ui/reader/content_watermark_test.dart` (add one test)

**Interfaces:**

- Consumes: `WatermarkedContent({required Widget child})` from Task 1; `ReaderScreen.browse({required String? qnaId, String? chapterId})` (`app/lib/ui/reader/reader_screen.dart:23`); fixture QnA ids used by `app/test/ui/reader_surface_test.dart` (`01J0QNATAPBLOCK00000000001` / `01J0CHAPREGIONAL0000000001`).
- Produces: every `ReaderView` render (queue and browse both return `ReaderView` from `ReaderScreen.build`) carries the watermark.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `app/test/ui/reader/content_watermark_test.dart`:

```dart
  testWidgets('reader view renders the watermark over content', (t) async {
    // Tall surface: idiomatic for the reader's long-form content
    // (see reader_surface_test.dart).
    await t.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user)],
      child: MaterialApp(
        theme: dmLightTheme(),
        home: const ReaderScreen.browse(
            qnaId: '01J0QNATAPBLOCK00000000001',
            chapterId: '01J0CHAPREGIONAL0000000001'),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('transversus abdominis plane'), findsOneWidget,
        reason: 'content rendered');
    expect(_painterOf(t).text, 'ananya@example.com');
  });
```

Add the import at the top of the file:

```dart
import 'package:diplomate/ui/reader/reader_screen.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader/content_watermark_test.dart`
Expected: FAIL - new test errors (`ContentWatermark` not found in tree; `_painterOf` throws "no matching widget").

- [ ] **Step 3: Wire the watermark into ReaderView**

In `app/lib/ui/reader/reader_view.dart`, add the import after the existing imports (line 4):

```dart
import 'content_watermark.dart';
```

Replace (currently lines 135-136):

```dart
    return Scaffold(
      body: SafeArea(
```

with:

```dart
    return Scaffold(
      body: WatermarkedContent(
          child: SafeArea(
```

Then find the build method's closer (just before `class _RateButton`, currently lines 425-431):

```dart
          ],
        ),
      ),
    );
  }
}
```

and replace it with (one added paren closes `WatermarkedContent`):

```dart
          ],
        ),
      )),
    );
  }
}
```

There are other `],`/`),` runs in the file - match on the full block above (it is the only one immediately followed by `}` at column 0 twice then `class _RateButton`). Verify with `flutter analyze` if unsure.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/reader/content_watermark_test.dart test/ui/reader_surface_test.dart`
Expected: PASS - all watermark tests plus the existing 4 reader surface tests (proves the wrap broke no layout).

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/reader/reader_view.dart app/test/ui/reader/content_watermark_test.dart
git commit -m "feat(app): overlay identity watermark on reader view

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Overlay watermark on the diagram viewer

**Files:**

- Modify: `app/lib/ui/reader/diagram_viewer.dart:164-183` (the viewer's `Expanded` image area)
- Modify: `app/test/ui/diagram_viewer_test.dart:24-27` (host needs a `ProviderScope` now) plus one new test

**Interfaces:**

- Consumes: `WatermarkedContent` / `ContentWatermark` / `WatermarkPainter` from Task 1.
- Produces: the fullscreen `_DiagramViewer` dialog carries the watermark over the zoomable image.

- [ ] **Step 1: Write the failing test**

In `app/test/ui/diagram_viewer_test.dart`, add imports:

```dart
import 'package:diplomate/ui/reader/content_watermark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

Replace the `host()` function (lines 24-27):

```dart
Widget host() => MaterialApp(
    theme: dmLightTheme(),
    home: Scaffold(
        body: DiagramPlate(image: _img, bytesLoader: () async => _bytes)));
```

with:

```dart
Widget host() => ProviderScope(
    child: MaterialApp(
        theme: dmLightTheme(),
        home: Scaffold(
            body: DiagramPlate(image: _img, bytesLoader: () async => _bytes))));
```

Append inside `main()`:

```dart
  testWidgets('viewer overlays the identity watermark on the image', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Tap to enlarge'));
    await t.pumpAndSettle();
    final paint = t.widget<CustomPaint>(find.descendant(
        of: find.byType(ContentWatermark),
        matching: find.byType(CustomPaint)));
    // No session override in this host: fallback text proves the viewer
    // never depends on auth state to render.
    expect((paint.painter! as WatermarkPainter).text, 'DiploMate');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/diagram_viewer_test.dart`
Expected: existing 3 tests PASS (ProviderScope wrap is inert), new test FAILS with "no matching widget" for `ContentWatermark`.

- [ ] **Step 3: Wire the watermark into the viewer**

In `app/lib/ui/reader/diagram_viewer.dart`, add the import after `import '../../theme/tokens.dart';`:

```dart
import 'content_watermark.dart';
```

Replace (currently lines 164-165):

```dart
                Expanded(
                  child: GestureDetector(
```

with:

```dart
                Expanded(
                  child: WatermarkedContent(
                      child: GestureDetector(
```

Replace the matching closer (currently lines 181-184, immediately before `OutlinedButton`):

```dart
                    ),
                  ),
                ),
                OutlinedButton(
```

with:

```dart
                    ),
                  )),
                ),
                OutlinedButton(
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/ui/diagram_viewer_test.dart`
Expected: PASS (4 tests, including focus-restoration - the wrap must not steal focus or gestures; `IgnorePointer` guarantees pinch/double-tap still hit `InteractiveViewer`).

- [ ] **Step 5: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/ui/reader/diagram_viewer.dart app/test/ui/diagram_viewer_test.dart
git commit -m "feat(app): overlay identity watermark on diagram viewer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Android capture block (FLAG_SECURE)

**Files:**

- Modify: `app/android/app/src/main/kotlin/com/diplomate/diplomate/MainActivity.kt` (whole file, currently 5 lines)

**Interfaces:**

- Consumes: nothing from other tasks. `BuildConfig` is generated in the same package (`namespace = "com.diplomate.diplomate"` in `app/android/app/build.gradle.kts:8`), so no extra import.
- Produces: release-build window refuses screenshots, screen recording, and app-switcher previews. No Dart-visible surface.

- [ ] **Step 1: Replace MainActivity.kt**

Full new content of `app/android/app/src/main/kotlin/com/diplomate/diplomate/MainActivity.kt`:

```kotlin
package com.diplomate.diplomate

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture-protection spec 2026-07-10: licensed QnA content must not
        // be screenshotted or screen-recorded. Debug builds stay capturable
        // for QA and marketing shots.
        if (!BuildConfig.DEBUG) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter build apk --release 2>&1 | tail -5`
Expected: `Built build/app/outputs/flutter-apk/app-release.apk` (the release path compiles the FLAG_SECURE branch). If release signing is not configured and the build fails on signing, `flutter build apk --debug` proving compilation is the fallback gate; note it in the commit body.

- [ ] **Step 3: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/android/app/src/main/kotlin/com/diplomate/diplomate/MainActivity.kt
git commit -m "feat(android): FLAG_SECURE blocks content capture in release builds

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: iOS capture block (secure-layer wrap)

**Files:**

- Modify: `app/ios/Runner/SceneDelegate.swift` (whole file, currently 6 lines)

**Interfaces:**

- Consumes: nothing from other tasks. `FlutterSceneDelegate` conforms to `UIWindowSceneDelegate`, so `window: UIWindow?` is available.
- Produces: release-build screenshots and recordings capture a blank frame. No Dart-visible surface.

- [ ] **Step 1: Replace SceneDelegate.swift**

Full new content of `app/ios/Runner/SceneDelegate.swift`:

```swift
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Capture-protection spec 2026-07-10: wrapping the window's layer inside a
  // secure UITextField layer makes system screenshots and screen recordings
  // capture a blank frame (the standard banking/OTT technique). Debug builds
  // stay capturable for QA. Re-verify on every major iOS release: this rides
  // on unofficial-but-stable UIKit behavior.
  private let secureField = UITextField()
  private var secured = false

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    #if !DEBUG
    guard !secured, let window else { return }
    secured = true
    makeSecure(window)
    #endif
  }

  private func makeSecure(_ window: UIWindow) {
    secureField.isSecureTextEntry = true
    window.addSubview(secureField)
    window.layer.superlayer?.addSublayer(secureField.layer)
    if #available(iOS 17.0, *) {
      secureField.layer.sublayers?.last?.addSublayer(window.layer)
    } else {
      secureField.layer.sublayers?.first?.addSublayer(window.layer)
    }
  }
}
```

If the compiler reports that `sceneDidBecomeActive` does not override a superclass method, remove the `override` keyword and the `super.sceneDidBecomeActive(scene)` line (the base class then has no implementation to forward to).

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter build ios --release --no-codesign 2>&1 | tail -5`
Expected: `Built .../Runner.app` with no Swift errors (release build compiles the `#if !DEBUG` branch).

- [ ] **Step 3: Commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/ios/Runner/SceneDelegate.swift
git commit -m "feat(ios): secure-layer wrap blanks screenshots in release builds

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Verification matrix (manual) + Sentry leak check

**Files:**

- No source changes expected. Possible conditional change: `app/ios/Runner/SceneDelegate.swift` (step 4).

**Interfaces:**

- Consumes: everything above.
- Produces: evidence the spec's success criteria hold; the founder sign-off gate.

- [ ] **Step 1: Full test suite green**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test`
Expected: all tests pass (spec criterion 6).

- [ ] **Step 2: Sentry telemetry leak check (read-only)**

Open `app/lib/main.dart:73-83`. Confirm the `SentryFlutter.init` options set neither `options.attachScreenshot = true` nor any `options.replay.*` sample rate. Both default to off in sentry_flutter 9.x, so content cannot leak through crash telemetry. If either is ever present, set it to false/0 - as of this plan they are absent, so expect no change.

- [ ] **Step 3: Manual device matrix**

This is native behavior; widget tests cannot cover it. Run each row and record the result in the PR/commit body:

| Check                                                | Command / action                                                         | Expected                                                                       |
| ---------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Android release screenshot                           | `flutter run --release -d <android>` then try a screenshot in the reader | System refuses ("Can't take screenshot due to security policy") or saves black |
| Android release recording / `adb exec-out screencap` | attempt while reader open                                                | Black frames                                                                   |
| Android app switcher                                 | background the app                                                       | Preview blank/black                                                            |
| iOS release screenshot                               | `flutter run --release -d <iphone>`, screenshot the reader               | Photos shows a blank/black image                                               |
| iOS release screen recording                         | Control Center record over the reader                                    | Blank recording                                                                |
| iOS app switcher                                     | background the app                                                       | No content visible (see step 4 if it leaks)                                    |
| Debug builds, both platforms                         | `flutter run` (debug), screenshot                                        | Captures work normally                                                         |
| Watermark, light + dark                              | open reader + diagram viewer in both themes                              | Faint tiled email visible; text plainly readable                               |

Simulator caveat: the iOS secure-layer effect is only trustworthy on a physical device; simulator screenshots may not reproduce it. Android emulator honors FLAG_SECURE.

- [ ] **Step 4 (conditional): iOS app-switcher cover**

Only if the iOS switcher row above showed content. Two edits to `SceneDelegate.swift`:

First, add a new member and a new override inside the class, alongside the existing `secureField`/`secured` members:

```swift
  private let coverView = UIView()

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    #if !DEBUG
    guard let window else { return }
    coverView.frame = window.bounds
    coverView.backgroundColor = .systemBackground
    window.addSubview(coverView)
    #endif
  }
```

Second, add `coverView.removeFromSuperview()` to the EXISTING `sceneDidBecomeActive` override from Task 5 (do not declare a second override). The merged body becomes:

```swift
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    coverView.removeFromSuperview()
    #if !DEBUG
    guard !secured, let window else { return }
    secured = true
    makeSecure(window)
    #endif
  }
```

Re-run the iOS switcher row, then amend/commit:

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/ios/Runner/SceneDelegate.swift
git commit -m "feat(ios): cover app-switcher snapshot while backgrounded

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Done - report matrix results to the founder**

All spec success criteria (1-6) checked off with evidence.
