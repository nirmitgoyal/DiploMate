import 'dart:async';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/signin/signin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(AuthRepository auth) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(theme: dmLightTheme(), home: const SignInScreen()),
    );

/// FakeAuthRepository resolves with no real async gap, so a widget-test
/// pump can never observe the in-flight window. This repo holds
/// signInWithGoogle() open on a Completer until the test releases it.
class _SlowAuthRepository implements AuthRepository {
  final _completer = Completer<SessionUser>();

  @override
  Future<SessionUser> signInWithGoogle() => _completer.future;

  @override
  Future<SessionUser?> restoreSession() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<SessionUser> setSpeciality(String specialityId) => _completer.future;
}

void main() {
  testWidgets('renders wordmark, tagline, lede, specimen, single Google CTA, legal line',
      (t) async {
    await t.pumpWidget(host(FakeAuthRepository()));
    expect(find.text('DiploMate'), findsOneWidget);
    expect(find.text('Written by Doctors. Solved for Success!'), findsOneWidget);
    expect(find.text('Master DNB theory answers by recalling them, not rereading them.'),
        findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Terms of Service · Privacy Policy'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsOneWidget,
        reason: 'D5: exactly one auth action');
  });

  testWidgets('offline error is distinct from auth error', (t) async {
    final auth = FakeAuthRepository()..failWith = AuthOffline();
    await t.pumpWidget(host(auth));
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text("You're offline - connect and retry."), findsOneWidget);

    auth.failWith = Exception('boom');
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('Sign-in failed - try again.'), findsOneWidget);
  });

  testWidgets('cancel returns to idle with no error (DESIGN.md State Spec 2)',
      (t) async {
    final auth = FakeAuthRepository()..failWith = SignInCancelled();
    await t.pumpWidget(host(auth));
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('Sign-in failed - try again.'), findsNothing);
    expect(find.text("You're offline - connect and retry."), findsNothing);
    final btn = t.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('in-flight disables the CTA', (t) async {
    final auth = _SlowAuthRepository();
    await t.pumpWidget(host(auth));
    await t.tap(find.text('Continue with Google'));
    await t.pump(); // one frame into the async call, signInWithGoogle still pending
    final btn = t.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
    auth._completer.complete(const SessionUser(
        id: 'x', email: 'x@example.com', specialityChangeCount: 0));
    await t.pumpAndSettle();
  });
}
