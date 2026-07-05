import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_auth_repository.dart';
import 'package:diplomate/data/fixtures/fake_sync_service.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/theme/tokens.dart';
import 'package:diplomate/ui/account/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records whether deleteAccount() was invoked, for dismiss-safety assertions.
class _RecordingAuthRepository extends FakeAuthRepository {
  bool deleteAccountCalled = false;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    return super.deleteAccount();
  }
}

SessionUser user({int changes = 0}) => SessionUser(
    id: 'u1', email: 'ananya@example.com', name: 'Ananya Sharma', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: changes);

Widget host({int changes = 0, FakeSyncService? sync, FakeAuthRepository? auth}) => ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => user(changes: changes)),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        if (sync != null) syncServiceProvider.overrideWithValue(sync),
      ],
      child: MaterialApp(theme: dmLightTheme(), home: const AccountScreen()),
    );

void main() {
  testWidgets('identity, sync line, speciality row, reminder, sign out, delete; no downloads/storage rows',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Ananya Sharma'), findsOneWidget);
    expect(find.text('ananya@example.com'), findsOneWidget);
    expect(find.text('A'), findsOneWidget, reason: 'letter fallback avatar');
    expect(find.textContaining('Last synced'), findsOneWidget);
    expect(find.text('Exam speciality'), findsOneWidget);
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.textContaining('torage'), findsNothing);
    expect(find.textContaining('ownload'), findsNothing);
  });

  testWidgets('change-used state greys the speciality row', (t) async {
    await t.pumpWidget(host(changes: 1));
    await t.pumpAndSettle();
    expect(find.text('one-time change used'), findsOneWidget);
  });

  testWidgets('delete account is a 2-step confirm', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Delete account'));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('This is permanent'), findsOneWidget);
  });

  testWidgets('sync line renders amber at >= 3 days stale (DESIGN.md State Spec 15)', (t) async {
    final sync = FakeSyncService()
      ..last = DateTime.now().subtract(const Duration(days: 5));
    await t.pumpWidget(host(sync: sync));
    await t.pumpAndSettle();
    final textWidget = t.widget<Text>(find.textContaining('Last synced'));
    expect(textWidget.style?.color, dmLight.amber);
  });

  testWidgets('sync line renders ink3 (not amber) below 3 days stale', (t) async {
    final sync = FakeSyncService()
      ..last = DateTime.now().subtract(const Duration(days: 1));
    await t.pumpWidget(host(sync: sync));
    await t.pumpAndSettle();
    final textWidget = t.widget<Text>(find.textContaining('Last synced'));
    expect(textWidget.style?.color, dmLight.ink3);
    expect(textWidget.style?.color, isNot(dmLight.amber));
  });

  testWidgets('never-synced renders "Not synced yet"', (t) async {
    final sync = FakeSyncService()..last = null;
    await t.pumpWidget(host(sync: sync));
    await t.pumpAndSettle();
    expect(find.text('Not synced yet'), findsOneWidget);
  });

  testWidgets('dismissing dialog 1 (Cancel) does not delete the account', (t) async {
    final auth = _RecordingAuthRepository();
    await t.pumpWidget(host(auth: auth));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete account'));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(auth.deleteAccountCalled, isFalse);
    expect(find.text('Ananya Sharma'), findsOneWidget, reason: 'session unchanged');
  });

  testWidgets('dismissing dialog 2 (Keep my account) does not delete the account', (t) async {
    final auth = _RecordingAuthRepository();
    await t.pumpWidget(host(auth: auth));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete account'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('This is permanent'), findsOneWidget);
    await t.tap(find.text('Keep my account'));
    await t.pumpAndSettle();
    expect(find.text('This is permanent'), findsNothing);
    expect(auth.deleteAccountCalled, isFalse);
    expect(find.text('Ananya Sharma'), findsOneWidget, reason: 'session unchanged');
  });
}
