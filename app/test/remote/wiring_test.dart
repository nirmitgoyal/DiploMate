import 'dart:typed_data';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_auth_repository.dart';
import 'package:diplomate/data/remote/remote_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/router.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

class _FakeGoogle implements GoogleSignInLike {
  _FakeGoogle({this.token});
  final String? token;
  @override
  Future<String?> idToken({required bool silent}) async => token;
  @override
  Future<void> signOut() async {}
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

/// Boots the app the way main() does (restore the session on the injected,
/// already-init'd ApiClient, seed sessionUserProvider) then pumps
/// MaterialApp.router. This is the production wiring under test, minus
/// google_sign_in / secure storage platform channels (injected fakes). The
/// caller inits the ApiClient first so it can install a stub http adapter.
Future<ProviderContainer> _boot(WidgetTester tester,
    {required ApiClient api, required GoogleSignInLike google}) async {
  final container = ProviderContainer(
    overrides: [
      ...remoteOverrides(
          apiBaseUrl: 'https://api.test',
          serverClientId: 'web.client',
          api: api,
          google: google),
      // This test exercises auth + routing, not the study loop; stub the due
      // queue so Home never opens a live drift review-events stream (which
      // would race the in-memory DB close at teardown).
      dueQueueProvider.overrideWithValue(const []),
    ],
  );
  addTearDown(container.dispose);

  // The pre-runApp bootstrap does real dio I/O (restoreSession); run it in the
  // real async zone (as production main() does) - inside testWidgets' fake-async
  // a stubbed dio Future would never resolve. The try/catch mirrors main()'s
  // guarded bootstrap: an offline cold-start degrades to Sign-in, never throws.
  // The try/catch mirrors main()'s guarded bootstrap: an offline cold-start
  // degrades to Sign-in, never throws. (The guard sits around the same dio I/O
  // main() guards; runAsync surfaces a throw to the framework, so catch inside.)
  final user = await tester.runAsync<SessionUser?>(() async {
    try {
      return await container.read(authRepositoryProvider).restoreSession();
    } catch (_) {
      return null;
    }
  });
  container.read(sessionUserProvider.notifier).state = user;

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
          theme: dmLightTheme(), routerConfig: ref.watch(routerProvider)),
    ),
  ));
  // Bounded pumps (not pumpAndSettle): Home's resumeChapter FutureProvider keeps
  // scheduling frames, so the tree never fully settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

void main() {
  testWidgets('no stored JWT -> boots to Sign-in', (tester) async {
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: _MemoryTokenStore());
    await api.init();
    await _boot(tester, api: api, google: _FakeGoogle());
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('stored JWT + /manifest 200 + silent re-auth -> lands Home',
      (tester) async {
    final api = ApiClient(
        baseUrl: 'https://api.test', tokenStore: _MemoryTokenStore('stored-jwt'));
    await api.init();
    api.dio.httpClientAdapter = _StubAdapter((o) {
      if (o.path == '/manifest') {
        return ResponseBody.fromString(
            '{"schema_version":1,"min_app_version":1,"specialities":[]}', 200,
            headers: {
              'content-type': ['application/json']
            });
      }
      if (o.path == '/auth/google') {
        return ResponseBody.fromString(
            '{"session_jwt":"jwt2","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":"S1","speciality_change_count":0}}',
            200,
            headers: {
              'content-type': ['application/json']
            });
      }
      return ResponseBody.fromString('{}', 200,
          headers: {
            'content-type': ['application/json']
          });
    });

    await _boot(tester, api: api, google: _FakeGoogle(token: 'gid'));
    // Signed-in + speciality set (S1) -> router lands Home, not Sign-in/Speciality.
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Exam speciality'), findsNothing);
    expect(find.text('This Week'), findsOneWidget, reason: 'landed on Home');
  });

  testWidgets(
      'C1: live 401 during sync flush nulls the session and bounces to Sign-in',
      (tester) async {
    // Start signed-in on Home (stored JWT, /manifest 200, silent re-auth).
    final api = ApiClient(
        baseUrl: 'https://api.test', tokenStore: _MemoryTokenStore('stored-jwt'));
    await api.init();
    api.dio.httpClientAdapter = _StubAdapter((o) {
      if (o.path == '/manifest') {
        return ResponseBody.fromString(
            '{"schema_version":1,"min_app_version":1,"specialities":[]}', 200,
            headers: {
              'content-type': ['application/json']
            });
      }
      if (o.path == '/auth/google') {
        return ResponseBody.fromString(
            '{"session_jwt":"jwt2","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":"S1","speciality_change_count":0}}',
            200,
            headers: {
              'content-type': ['application/json']
            });
      }
      // The first flush drains empty pending tables (returns early), so the only
      // HTTP is the bookmarks PUT - answer it 401 to simulate an expired session
      // discovered mid background-sync.
      return ResponseBody.fromString('{"error":"unauthorized"}', 401,
          headers: {
            'content-type': ['application/json']
          });
    });

    final container =
        await _boot(tester, api: api, google: _FakeGoogle(token: 'gid'));
    expect(find.text('This Week'), findsOneWidget, reason: 'started on Home');

    // Fire the exact sync path main() runs on app-start / backgrounding. The
    // 401 handler is fire-and-forget async (signOut + null the session), so let
    // its microtasks drain in the real zone before pumping the router.
    await tester.runAsync(() async {
      await container.read(syncServiceProvider).flush();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // onAuthExpired signed out AND nulled sessionUserProvider -> router redirect.
    expect(container.read(sessionUserProvider), isNull,
        reason: 'session cleared by onAuthExpired');
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'bounced to Sign-in, not stranded on a dead Home');
  });

  testWidgets(
      'C2: offline cold-start (restore probe connectionError) does not crash, shows Sign-in',
      (tester) async {
    // Returning user launching offline: JWT present, but the /manifest whoami
    // probe throws connectionError. restoreSession() rethrows it; the bootstrap
    // wrapper must swallow it and degrade to Sign-in rather than crash pre-runApp.
    final api = ApiClient(
        baseUrl: 'https://api.test', tokenStore: _MemoryTokenStore('stored-jwt'));
    await api.init();
    api.dio.httpClientAdapter = _StubAdapter(
        (o) => throw DioException.connectionError(
            requestOptions: RequestOptions(path: o.path), reason: 'offline'));

    // _boot runs the same guarded bootstrap sequence as main() (see the helper).
    await _boot(tester, api: api, google: _FakeGoogle());
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'offline boot degraded to Sign-in without throwing');
  });
}
