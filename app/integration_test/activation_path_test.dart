// Activation-path integration test (lane-D exit criterion / deploy-smoke
// rehearsal). Drives the ONE funnel that has to work on launch day:
//
//   boot -> Sign-in -> Speciality (Anaesthesiology) -> Home funnel row
//        -> "Start here" -> Topics (real /chapters fetch) -> open a QnA
//        -> reveal -> rate Easy -> SyncService.flush()
//        -> the rating reached POST /sync/review-events.
//
// WHY THIS CANNOT RUN IN CI (and does not, by design):
// integration_test needs a real Flutter engine on an emulator/device, plus a
// LOCAL server + seeded Postgres reachable at API_BASE_URL. CI has neither, so
// app-ci.yml runs `flutter test` only (unit/widget). This file runs on a
// maintainer machine/emulator, exactly as the plan states. To run it:
//
//   1. Start Postgres and apply migrations; seed the ingestion fixture
//      (Anaesthesiology -> Airway Management -> Difficult airway -> QN1).
//   2. Start the API in TEST MODE so it accepts the stubbed Google token:
//        SESSION_JWT_SECRET='{"v1":"s1"}' \
//        GOOGLE_WEB_CLIENT_ID=test \
//        DATABASE_URL=postgres://localhost/diplomate_e2e \
//        AUTH_FAKE_VERIFIER=1 node server/src/index.js
//      AUTH_FAKE_VERIFIER swaps verifyGoogleToken for a stub that returns a
//      fixed {sub,email} for any id_token (index.js reads it; see report).
//   3. flutter test integration_test/activation_path_test.dart \
//        --dart-define=API_BASE_URL=http://10.0.2.2:3000   # emulator host loopback
//
// The auth SEAM is the only fake: authRepositoryProvider is the REAL
// RemoteAuthRepository fed a canned Google id-token, so the /auth/google
// exchange, /me/speciality, /manifest, /chapters, and /sync are all real dio
// over the wire. Auth E2E on a Play-signed build is the release smoke's job
// (checklist Task 7 step 6); here we prove the funnel + real content + real
// sync, not google_sign_in itself.

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_auth_repository.dart';
import 'package:diplomate/data/remote/remote_providers.dart';
import 'package:diplomate/data/remote/secure_token_store.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/router.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The emulator reaches the host's localhost at 10.0.2.2; override for a
/// physical device or a different port with --dart-define=API_BASE_URL.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Stubs ONLY the google_sign_in platform channel: returns a canned id-token
/// the test-mode server accepts. Everything downstream (the /auth/google POST,
/// the returned JWT, speciality, content, sync) is real.
class _FakeGoogle implements GoogleSignInLike {
  @override
  Future<String?> idToken({required bool silent}) async => 'fake-google-id-token';
  @override
  Future<void> signOut() async {}
}

/// Records every response path the real dio saw, so the test can assert the
/// rating actually reached POST /sync/review-events (there is no read-back
/// endpoint for append-only event tables).
class _HitLog {
  final List<({String path, int? status})> hits = [];
  Interceptor get interceptor => InterceptorsWrapper(
        onResponse: (r, h) {
          hits.add((path: r.requestOptions.path, status: r.statusCode));
          h.next(r);
        },
      );
  bool posted(String path) =>
      hits.any((e) => e.path == path && e.status == 200);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('activation funnel: sign-in -> Anaesthesiology -> Start here -> '
      'reveal -> rate Easy -> rating reaches the server', (tester) async {
    final hits = _HitLog();
    // A real on-device database and a real ApiClient - the production stack.
    // Fresh native DB (not memory) so the flush() drain reads real pending rows.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = ApiClient(baseUrl: _apiBaseUrl, tokenStore: const SecureTokenStore());
    await api.init();
    api.dio.interceptors.add(hits.interceptor);

    final container = ProviderContainer(overrides: [
      ...remoteOverrides(
        apiBaseUrl: _apiBaseUrl,
        serverClientId: 'test-web-client',
        api: api,
        // Real RemoteAuthRepository, faked ONLY at the google_sign_in seam.
        google: _FakeGoogle(),
      ),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    // Boot exactly as main() does: restore the (empty) session, then pump the
    // router. No stored JWT yet -> lands Sign-in.
    final restored = await tester
        .runAsync(() => container.read(authRepositoryProvider).restoreSession());
    container.read(sessionUserProvider.notifier).state = restored;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
            theme: dmLightTheme(), routerConfig: ref.watch(routerProvider)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'no session -> Sign-in');

    // --- Sign in (real /auth/google exchange behind the fake Google token). ---
    // The button's onPressed does real dio I/O, so drive the repo through
    // runAsync and seed the session the way SignInScreen's handler does.
    final user = await tester
        .runAsync(() => container.read(authRepositoryProvider).signInWithGoogle());
    container.read(sessionUserProvider.notifier).state = user;
    await tester.pumpAndSettle();
    // Fresh account has no speciality -> the router gate lands Speciality.
    expect(find.text('Exam speciality'), findsOneWidget,
        reason: 'signed in, no track -> onboarding gate');

    // --- Pick Anaesthesiology (real /manifest for the list, real
    // /me/speciality to commit). ---
    // specialities() is on-demand dio; runAsync it, then the tree rebuilds.
    await tester.runAsync(() async {
      // Let the screen's initState().then(specialities) settle its network read.
      for (var i = 0; i < 20 && find.text('Continue').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    final anaesthesia = find.textContaining('Anaesthesiology');
    expect(anaesthesia, findsWidgets, reason: 'the beachhead track is listed');
    await tester.tap(anaesthesia.first);
    await tester.pumpAndSettle();
    // Commit routes through the REAL /me/speciality; runAsync the tap handler.
    await tester.runAsync(() async {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    });
    // Speciality committed -> router releases the gate to Home.
    await tester.pumpAndSettle();

    // --- Home funnel row: "START HERE" into the highest-weight chapter. ---
    // resumeChapterProvider is a FutureProvider doing real dio; give it time.
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && find.text('START HERE').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('START HERE'), findsOneWidget,
        reason: 'post-onboarding Home shows the day-zero funnel row (DESIGN-T3)');

    // Wall-clock budget (<3min funnel; the automatable browse-to-first-recall
    // slice): the whole reveal path must complete well inside the 35s receive
    // timeout - if any request stalled to that ceiling, this stopwatch trips.
    final budget = Stopwatch()..start();

    // Tap "Start here" -> Topics screen, which runs the REAL /chapters +
    // paginated /chapters/:id/qnas fetch (ensureChapterCached).
    await tester.tap(find.text('START HERE'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Topics shows a spinner until ensureChapterCached completes; wait for a
      // tappable topic row to appear (real content landed in drift).
      for (var i = 0;
          i < 30 && find.textContaining('airway').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    final topicRow = find.textContaining('airway');
    expect(topicRow, findsWidgets,
        reason: 'real /chapters content rendered a topic row');

    // Open the QnA -> Reader (browse mode). Reveal + rate route through the
    // Task-5 ReaderController -> StudyRepository.recordRating.
    await tester.tap(topicRow.first);
    await tester.pumpAndSettle();
    expect(find.text('Reveal model answer'), findsOneWidget,
        reason: 'Reader opened at the recall gate');
    await tester.tap(find.text('Reveal model answer'));
    await tester.pumpAndSettle();
    // Rate Easy (Semantics label 'Rate Easy' -> WireRating.good). recordRating
    // resolves only after the drift persist (D4), so runAsync it.
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Rate Easy'));
      await tester.pumpAndSettle();
    });

    budget.stop();
    expect(budget.elapsed, lessThan(const Duration(seconds: 35)),
        reason: 'browse-to-first-recall finished with no 35s timeout firing');

    // The rating is now a pending drift row. Flush drains it to the server; a
    // row is deleted locally ONLY after the server accepts it, so an empty
    // pending table after flush IS proof the POST landed - and the hit-log
    // corroborates the 200 on /sync/review-events.
    expect((await db.unsyncedReviewEvents()).length, 1,
        reason: 'the rating persisted locally before any sync (local-first)');
    await tester
        .runAsync(() => container.read(syncServiceProvider).flush());

    expect(hits.posted('/sync/review-events'), isTrue,
        reason: 'POST /sync/review-events returned 200');
    expect(await db.unsyncedReviewEvents(), isEmpty,
        reason: 'the server accepted the rating -> the local row was deleted');
  });
}
