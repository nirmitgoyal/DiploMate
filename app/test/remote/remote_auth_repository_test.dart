import 'dart:typed_data';

import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_auth_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

class FakeGoogle implements GoogleSignInLike {
  FakeGoogle({this.token, this.cancel = false});
  String? token;
  bool cancel;
  bool signedOut = false;
  @override
  Future<String?> idToken({required bool silent}) async {
    if (cancel) return null;
    return token;
  }
  @override
  Future<void> signOut() async => signedOut = true;
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ApiClient clientWith(ResponseBody Function(RequestOptions) handler, TokenStore store) {
  final c = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
  return c;
}

void main() {
  test('signInWithGoogle: id token -> /auth/google -> SessionUser + stored JWT', () async {
    final store = MemoryTokenStore();
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    api.dio.httpClientAdapter = StubAdapter((o) => ResponseBody.fromString(
        '{"session_jwt":"jwt1","user":{"id":"u1","email":"a@b.c","name":"Ananya","photo_url":null,"speciality_id":null,"speciality_change_count":0}}',
        200,
        headers: {'content-type': ['application/json']}));
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));

    final user = await repo.signInWithGoogle();
    expect(user.id, 'u1');
    expect(store.value, 'jwt1');
  });

  test('cancelled Google flow throws SignInCancelled; network failure throws AuthOffline',
      () async {
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await api.init();
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(cancel: true));
    expect(repo.signInWithGoogle(), throwsA(isA<SignInCancelled>()));

    api.dio.httpClientAdapter = StubAdapter((o) =>
        throw DioException.connectionError(requestOptions: o, reason: 'down'));
    final repo2 = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));
    expect(repo2.signInWithGoogle(), throwsA(isA<AuthOffline>()));
  });

  test('restoreSession: stored JWT + silent token refresh path on 401', () async {
    final store = MemoryTokenStore()..value = 'stored-jwt';
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    var calls = 0;
    api.dio.httpClientAdapter = StubAdapter((o) {
      calls++;
      if (o.path == '/manifest' && calls == 1) {
        return ResponseBody.fromString('{"error":"session_expired"}', 401,
            headers: {'content-type': ['application/json']});
      }
      if (o.path == '/auth/google') {
        return ResponseBody.fromString(
            '{"session_jwt":"jwt2","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":"S1","speciality_change_count":0}}',
            200,
            headers: {'content-type': ['application/json']});
      }
      return ResponseBody.fromString(
          '{"schema_version":1,"min_app_version":1,"specialities":[]}', 200,
          headers: {'content-type': ['application/json']});
    });
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));
    final user = await repo.restoreSession();
    expect(user!.specialityId, 'S1', reason: 'expired-online -> silent re-auth -> active');
    expect(store.value, 'jwt2');
  });

  test('signOut clears the stored JWT and the Google session', () async {
    final store = MemoryTokenStore()..value = 'jwt';
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    final google = FakeGoogle(token: 'gid');
    final repo = RemoteAuthRepository(api: api, google: google);
    await repo.signOut();
    expect(store.value, isNull);
    expect(google.signedOut, isTrue);
  });
}
