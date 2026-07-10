import 'dart:ui' as ui;

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

  testWidgets('paint() actually draws visible ink, not just a shaped tree',
      (t) async {
    // runAsync escapes the FakeAsync zone that testWidgets installs, so the
    // engine can actually complete the toImage/toByteData futures. Without
    // it these awaits hang forever.
    final bytes = await t.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Fully opaque on purpose: proves tiles land on the canvas at all.
      // The production alpha (0.05/0.07) is whisper-faint by design and
      // would make the pixel-count assertion needlessly fragile here.
      WatermarkPainter(text: 'ananya@example.com', color: const Color(0xFF000000))
          .paint(canvas, const Size(400, 800));
      final image = await recorder.endRecording().toImage(400, 800);
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    expect(bytes, isNotNull, reason: 'runAsync returned null');
    final rgba = bytes!.buffer.asUint8List();
    var inkedPixels = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0) inkedPixels++;
    }
    // A rotated 12.5px email tiled across 400x800 paints thousands of ink
    // pixels; this floor is far above a stray antialiased pixel yet far
    // below the real count, so a font-rendering nudge will not trip it.
    expect(inkedPixels, greaterThan(2000), reason: 'inked=$inkedPixels');
  });
}
