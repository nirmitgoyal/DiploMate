import 'dart:typed_data';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_auth_repository.dart';
import 'package:diplomate/data/remote/remote_providers.dart';
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
  // a stubbed dio Future would never resolve.
  final user = await tester.runAsync(
      () => container.read(authRepositoryProvider).restoreSession());
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
}
