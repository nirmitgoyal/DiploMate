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
}
