import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/speciality/speciality_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared across all tests in this file: FixtureContentRepository caches its
// decoded JSON doc after the first load. A fresh instance per test would
// each hit rootBundle.loadString via the platform channel, and a second
// raw asset-bundle load from a later testWidgets() block in the same file
// never resolves (a flutter_test binding limitation, not app behavior).
final _content = FixtureContentRepository();

Widget host({bool changeMode = false, FakeAuthRepository? auth, SessionUser? user}) =>
    ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(_content),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        sessionUserProvider.overrideWith((ref) => user),
      ],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: SpecialityScreen(changeMode: changeMode)),
    );

void main() {
  testWidgets('renders 61 tracks under two group headers, CTA disabled until pick',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('DNB - Broad Specialities'), findsOneWidget);
    expect(find.text('61 of 61 tracks'), findsOneWidget);
    // DrNB header sits ~31 rows down; the list virtualizes offscreen rows,
    // so it must be scrolled into view before it is found.
    await t.scrollUntilVisible(find.text('DrNB - Super Specialities'), 500,
        scrollable:
            find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
    expect(find.text('DrNB - Super Specialities'), findsOneWidget);
    final cta = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(cta.onPressed, isNull);
  });

  testWidgets('substring search filters and Enter picks top match', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'drnb');
    await t.pumpAndSettle();
    expect(find.text('31 of 61 tracks'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'cardio');
    await t.pumpAndSettle();
    // Cardiology, Cardiovascular & Thoracic Surgery, Paediatric Cardiology
    // (verified against fixture_content_repository.dart's 61-row seed list;
    // "Cardiac Anaesthesia" does not contain the substring "cardio")
    expect(find.text('3 of 61 tracks'), findsOneWidget);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final cta = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(cta.onPressed, isNotNull, reason: 'Enter selected the top match');
  });

  testWidgets('empty search state suggests shorter terms', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('No matches. Try a shorter term - e.g. "cardio".'), findsOneWidget);
  });

  testWidgets('change mode confirms with one-way-door copy and blocks a second change',
      (t) async {
    const user = SessionUser(
        id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
        specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);
    final auth = FakeAuthRepository();
    await auth.signInWithGoogle();
    await auth.setSpeciality('01J0SPECANAES0000000000001');
    await t.pumpWidget(host(changeMode: true, auth: auth, user: user));
    await t.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Anatomy');
    await t.pumpAndSettle();
    await t.tap(find.text('Anatomy (DNB)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save change'));
    await t.pumpAndSettle();
    expect(find.textContaining('You can change your speciality once - this is that change.'), findsOneWidget);
    await t.tap(find.text('Change speciality'));
    await t.pumpAndSettle();
    // Flush the toast's 1500ms auto-dismiss timer (DmMotion.toastHold) so it
    // fires before the test ends rather than leaking a pending Timer.
    await t.pump(const Duration(milliseconds: 1500));

    // second distinct change hits the server rule
    final again = await auth.setSpeciality('01J0SPECANAES0000000000001')
        .then((_) => false, onError: (e) => e is ChangeLimitReached);
    expect(again, isTrue);
  });

  testWidgets('re-saving the same track skips the confirm dialog and does not consume the change',
      (t) async {
    const user = SessionUser(
        id: 'u2', email: 'a@b.c', name: 'Ananya', photoUrl: null,
        specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);
    final auth = FakeAuthRepository();
    await auth.signInWithGoogle();
    await auth.setSpeciality('01J0SPECANAES0000000000001');
    await t.pumpWidget(host(changeMode: true, auth: auth, user: user));
    await t.pumpAndSettle();

    // current track is pre-selected; tap Save change without picking a
    // different row.
    await t.tap(find.text('Save change'));
    await t.pumpAndSettle();
    expect(find.text('Use your one change?'), findsNothing,
        reason: 'same-track save is not a real change; no one-way-door prompt');
    // Flush the toast's 1500ms auto-dismiss timer (DmMotion.toastHold) so it
    // fires before the test ends rather than leaking a pending Timer.
    await t.pump(const Duration(milliseconds: 1500));

    // the change is still unused - a later real change must still work.
    final user2 = await auth.setSpeciality('01J0SPECFIXTURE0000000002');
    expect(user2.specialityChangeCount, 1);
  });
}
