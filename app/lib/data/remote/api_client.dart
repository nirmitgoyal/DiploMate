import 'package:dio/dio.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStore});

  final String baseUrl;
  final TokenStore tokenStore;
  late final Dio dio;
  String? sessionJwt;

  Future<void> init() async {
    sessionJwt = await tokenStore.read();
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      // Outside voice #6: an Eco-dyno wake manifests as time-to-first-byte
      // through the Heroku router - a RECEIVE timeout. Basic dyno is the
      // recommendation; this guard keeps Eco survivable.
      receiveTimeout: const Duration(seconds: 35),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final jwt = sessionJwt;
        if (jwt != null) options.headers['Authorization'] = 'Bearer $jwt';
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Sliding renewal (D5 addendum): store and continue - never
        // interrupts an in-flight sync batch (state 4).
        final refreshed = response.headers.value('x-refreshed-token');
        if (refreshed != null) {
          sessionJwt = refreshed;
          tokenStore.write(refreshed); // fire-and-forget persist
        }
        handler.next(response);
      },
    ));
  }

  Future<void> setSessionJwt(String? jwt) async {
    sessionJwt = jwt;
    await tokenStore.write(jwt);
  }

  Future<({String sessionJwt, Map<String, dynamic> user})> authGoogle(
      String idToken) async {
    final res = await dio.post('/auth/google', data: {'id_token': idToken});
    final jwt = res.data['session_jwt'] as String;
    await setSessionJwt(jwt);
    return (sessionJwt: jwt, user: res.data['user'] as Map<String, dynamic>);
  }
}
