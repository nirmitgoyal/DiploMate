import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _onboarded = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget appWith(SessionUser? user) => ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => user)],
      child: const DiplomateApp(),
    );

void main() {
  testWidgets('boots at Sign-in with no session', (t) async {
    await t.pumpWidget(appWith(null));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('session without speciality is gated to Speciality (no nav, no back)', (t) async {
    await t.pumpWidget(appWith(const SessionUser(
        id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
        specialityId: null, specialityChangeCount: 0)));
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('onboarded session lands on Home with 3 tabs', (t) async {
    await t.pumpWidget(appWith(_onboarded));
    await t.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets(
      'live sign-in navigates off Sign-in without remount; live sign-out returns to it',
      (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const DiplomateApp(),
    ));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'boots signed-out at Sign-in');

    // Flip session state post-build (not a pre-seed) - this is the case
    // GoRouter's redirect never re-runs for without a refreshListenable.
    container.read(sessionUserProvider.notifier).state = _onboarded;
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsNothing,
        reason: 'live sign-in must navigate off Sign-in');
    expect(find.text('Home'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget,
        reason: 'lands on the 3-tab shell');

    container.read(sessionUserProvider.notifier).state = null;
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'live sign-out must return to Sign-in');
    expect(find.byType(NavigationBar), findsNothing);
  });
}
