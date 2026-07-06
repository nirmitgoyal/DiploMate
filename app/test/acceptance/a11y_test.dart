import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/home/home_screen.dart';
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

  // Flagged gap (a11y pack closure): the DESIGN.md A11y Executable Pack names
  // "TalkBack semantic order per screen" as landed + test-enforced, but no
  // test asserted it. TalkBack (absent an explicit sortKey, which this app
  // does not use) reads in visual top-to-bottom order, so getTopLeft(...).dy
  // is a faithful proxy for traversal order without walking the raw
  // SemanticsNode tree.
  testWidgets(
      'Home TalkBack order: greeting -> primary CTA -> ghost CTA -> stats -> resume -> nav',
      (t) async {
    final handle = t.ensureSemantics();
    // due>0 so the primary CTA renders - State 6 hides it entirely at
    // due==0, which would make this ordering moot for that element.
    await t.pumpWidget(ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => _user),
        dueCountProvider.overrideWithValue(12),
      ],
      child: MaterialApp(
        theme: dmLightTheme(),
        // Nav lives in AppShell (see app/lib/router.dart), a separate
        // widget from HomeScreen - reproduced here so "nav" is a real,
        // comparable element rather than an assumption.
        home: Scaffold(
          body: const HomeScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined), label: 'Syllabus'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
            ],
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final greetingY = t.getTopLeft(find.textContaining('Ananya')).dy;
    final primaryCtaY =
        t.getTopLeft(find.text('View 12 suggested answers')).dy;
    final ghostCtaY = t.getTopLeft(find.text('View your bookmarks')).dy;
    final statsY = t.getTopLeft(find.text('This Week')).dy;
    final resumeY = t.getTopLeft(find.text('Airway Management')).dy;
    final navY = t.getTopLeft(find.text('Home').last).dy;

    expect(greetingY, lessThan(primaryCtaY),
        reason: 'greeting reads before the primary CTA');
    expect(primaryCtaY, lessThan(ghostCtaY),
        reason: 'primary CTA reads before the ghost CTA');
    expect(ghostCtaY, lessThan(statsY),
        reason: 'ghost CTA reads before This Week stats');
    expect(statsY, lessThan(resumeY),
        reason: 'stats read before the pinned resume row');
    expect(resumeY, lessThan(navY),
        reason: 'resume row reads before the bottom nav');
    handle.dispose();
  });

  testWidgets(
      'Reader TalkBack order: question -> reveal, then question -> answer -> rating tray',
      (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ReaderScreen.browse(
              qnaId: '01J0QNATAPBLOCK00000000001',
              topicId: '01J0TOPICTAPBLOCK000000001')),
    ));
    await t.pumpAndSettle();

    final questionY =
        t.getTopLeft(find.textContaining('transversus abdominis plane')).dy;
    final revealY = t.getTopLeft(find.text('Reveal model answer')).dy;
    expect(questionY, lessThan(revealY),
        reason: 'question reads before the reveal control');

    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();

    final questionYAfter =
        t.getTopLeft(find.textContaining('transversus abdominis plane')).dy;
    final answerY = t.getTopLeft(find.textContaining('fascial plane block')).dy;
    final ratingTrayY = t.getTopLeft(find.text('Easy')).dy;
    expect(questionYAfter, lessThan(answerY),
        reason: 'question reads before the revealed answer');
    expect(answerY, lessThan(ratingTrayY),
        reason: 'answer reads before the rating tray');
    handle.dispose();
  });
}
