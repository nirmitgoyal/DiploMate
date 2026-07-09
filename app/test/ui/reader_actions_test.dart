import 'package:diplomate/app_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tapQna = '01J0QNATAPBLOCK00000000001';
const _tapChapter = '01J0CHAPREGIONAL0000000001';

// Keyed by `online` so a second pumpWidget(host(online: false)) in the same
// test forces a fresh ReaderScreen element/state instead of Flutter reusing
// the prior (already revealed+rated) one at the same tree position.
Widget host({bool online = true}) => ProviderScope(
      key: ValueKey(online),
      overrides: [isOnlineProvider.overrideWith((ref) => online)],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ReaderScreen.browse(qnaId: _tapQna, chapterId: _tapChapter)),
    );

void main() {
  // The report row sits below the revealed 7-section answer; the default
  // 800x600 test surface is too short to hit-test it without scrolling, so
  // widen it (same idiom as reader_surface_test.dart's useTallSurface) -
  // this changes no assertion, only the canvas the assertions run against.
  Future<void> useTallSurface(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  testWidgets('search entry exists only post-reveal; search finds and counts', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsNothing, reason: 'pre-reveal: no search');
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.search));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'oblique');
    await t.pumpAndSettle();
    expect(find.textContaining('/'), findsWidgets, reason: 'n/N counter visible');
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'close restores the answer');
  });

  testWidgets('bookmark toggle flips icon and toasts', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.bookmark_border));
    await t.pump();
    expect(find.text('✓ Bookmarked'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await t.tap(find.byIcon(Icons.bookmark));
    await t.pump();
    expect(find.text('Bookmark removed'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('report row: online opens dialog and sends; offline is disabled with plain copy',
      (t) async {
    await useTallSurface(t);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.text('Report an answer error'));
    await t.pumpAndSettle();
    await t.tap(find.text('Send'));
    await t.pump();
    expect(find.text('✓ Report sent - thank you'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));

    await t.pumpWidget(host(online: false));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.text('Connect to the internet to report an error.'), findsOneWidget);
    await t.tap(find.text('Report an answer error'));
    await t.pumpAndSettle();
    expect(find.text('Send'), findsNothing, reason: 'disabled offline - no dialog');
  });
}
