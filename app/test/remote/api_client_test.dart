import 'dart:typed_data';

import 'package:diplomate/data/remote/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

/// Dio adapter stub: scripted responses, records requests.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(options);
    return handler(options);
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('bearer header attached; X-Refreshed-Token is stored without breaking the call', () async {
    final store = MemoryTokenStore()..value = 'old-jwt';
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await client.init();
    client.dio.httpClientAdapter = StubAdapter((o) {
      expect(o.headers['Authorization'], 'Bearer old-jwt');
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        'content-type': ['application/json'],
        'x-refreshed-token': ['new-jwt'],
      });
    });
    final res = await client.dio.get('/health');
    expect(res.statusCode, 200);
    expect(store.value, 'new-jwt', reason: 'sliding renewal persisted');
    expect(client.sessionJwt, 'new-jwt');
  });

  test('authGoogle posts id_token and installs the returned session JWT', () async {
    final store = MemoryTokenStore();
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await client.init();
    client.dio.httpClientAdapter = StubAdapter((o) {
      expect(o.path, '/auth/google');
      return ResponseBody.fromString(
          '{"session_jwt":"fresh","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":null,"speciality_change_count":0}}',
          200,
          headers: {'content-type': ['application/json']});
    });
    final out = await client.authGoogle('gid');
    expect(out.sessionJwt, 'fresh');
    expect(store.value, 'fresh');
    expect(out.user['id'], 'u1');
  });

  test('receive timeout is >= 35s (Eco-wake guard targets the right timer)', () async {
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await client.init();
    expect(client.dio.options.receiveTimeout!.inSeconds, greaterThanOrEqualTo(35));
  });
}
