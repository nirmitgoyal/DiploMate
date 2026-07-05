import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:diplomate/ui/speciality/speciality_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: null, specialityChangeCount: 0);

void main() {
  testWidgets('speciality list meets the tap-target guideline (48dp floor)', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user)],
      child: MaterialApp(
          theme: dmLightTheme(), home: const SpecialityScreen(changeMode: false)),
    ));
    await t.pumpAndSettle();
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('reader rating tray buttons are labeled for TalkBack', (t) async {
    // bySemanticsLabel walks the semantics tree, which only exists while a
    // handle is held (ensureSemantics) - without it every lookup finds
    // nothing regardless of the widget tree's actual Semantics labels.
    final handle = t.ensureSemantics();
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ReaderScreen.browse(
              qnaId: '01J0QNATAPBLOCK00000000001',
              topicId: '01J0TOPICTAPBLOCK000000001')),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Rate Easy'), findsOneWidget);
    expect(find.bySemanticsLabel('Rate Medium'), findsOneWidget);
    expect(find.bySemanticsLabel('Rate Hard'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('reveal under reduced motion is an instant swap', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: dmLightTheme(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ReaderScreen.browse(
              qnaId: '01J0QNATAPBLOCK00000000001',
              topicId: '01J0TOPICTAPBLOCK000000001'),
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pump(); // ONE frame, no animation wait
    expect(find.textContaining('fascial plane block'), findsOneWidget);
  });

  // Flagged gap: the speciality radiogroup was only asserted architecturally
  // (Semantics(inMutuallyExclusiveGroup: true)) - never keyboard-tested for
  // the DESIGN.md A11y Executable Pack's "roving radio focus" law
  // (ArrowDown/ArrowUp move selection between visible rows).
  testWidgets('speciality list: ArrowDown/ArrowUp move selection between visible rows',
      (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user)],
      child: MaterialApp(
          theme: dmLightTheme(), home: const SpecialityScreen(changeMode: false)),
    ));
    await t.pumpAndSettle();
    // Narrow to a stable, short visible set so row order is deterministic
    // and every candidate row is on screen without scrolling.
    await t.enterText(find.byType(TextField), 'Anatomy');
    await t.pumpAndSettle();
    expect(find.text('Anatomy (DNB)'), findsOneWidget);

    // Resolve from a context inside the row (its Text), matching the
    // diagram-viewer focus-trap test's pattern - resolving from the InkWell
    // ancestor's own context finds the enclosing FocusTraversalGroup's node
    // instead of the row's.
    Focus.of(t.element(find.text('Anatomy (DNB)'))).requestFocus();
    await t.pumpAndSettle();

    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget); // sanity: still on screen
    final cta = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(cta.onPressed, isNotNull,
        reason: 'ArrowDown moved the roving radio selection onto a row');

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pumpAndSettle();
    final ctaAfterUp = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(ctaAfterUp.onPressed, isNotNull,
        reason: 'ArrowUp moved selection back; a row remains selected');
  });
}
