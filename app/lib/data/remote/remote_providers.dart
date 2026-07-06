import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../providers/study_providers.dart';
import 'api_client.dart';
import 'remote_auth_repository.dart';
import 'remote_content_repository.dart';
import 'remote_sync_service.dart';
import 'secure_token_store.dart';

/// The one shared ApiClient for the app. Constructed in [remoteOverrides] and
/// read (never re-created) by every remote provider, so the same dio instance -
/// with the same JWT + connectivity interceptor - backs auth, content, sync,
/// and error reporting. Tests inject their own client; main() lets it default.
final _apiClientProvider = Provider<ApiClient>((_) =>
    throw StateError('apiClientProvider must be overridden by remoteOverrides'));

final _googleProvider = Provider<GoogleSignInLike>((_) =>
    throw StateError('googleProvider must be overridden by remoteOverrides'));

/// Swaps the plan-4 fakes for the real dio + google_sign_in stack. main()
/// builds a ProviderContainer with these, inits the ApiClient (reads the stored
/// JWT), restores the session, then runApp - so the SAME client is init'd
/// before the app and used by it.
///
/// [api]/[google] are injection seams for tests; production leaves them null.
List<Override> remoteOverrides({
  required String apiBaseUrl,
  required String serverClientId,
  ApiClient? api,
  GoogleSignInLike? google,
}) {
  final client =
      api ?? ApiClient(baseUrl: apiBaseUrl, tokenStore: const SecureTokenStore());
  return [
    // Shared client override, plus the dio-observed connectivity interceptor -
    // installed once here (has `ref`, so it can flip isOnlineProvider). No
    // connectivity_plus dependency: any success -> online, a connection/timeout
    // error -> offline (ponytail: coarse but free; add the package only if this
    // proves too blunt).
    _apiClientProvider.overrideWith((ref) {
      client.dio.interceptors.add(InterceptorsWrapper(
        onResponse: (r, h) {
          ref.read(isOnlineProvider.notifier).state = true;
          h.next(r);
        },
        onError: (e, h) {
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            ref.read(isOnlineProvider.notifier).state = false;
          }
          h.next(e);
        },
      ));
      return client;
    }),
    _googleProvider.overrideWithValue(
        google ?? RealGoogleSignIn(serverClientId: serverClientId)),
    authRepositoryProvider.overrideWith((ref) => RemoteAuthRepository(
        api: ref.watch(_apiClientProvider), google: ref.watch(_googleProvider))),
    contentRepositoryProvider.overrideWith((ref) => RemoteContentRepository(
          api: ref.watch(_apiClientProvider),
          db: ref.watch(appDatabaseProvider),
          specialityId: () async =>
              ref.read(sessionUserProvider)?.specialityId,
        )),
    syncServiceProvider.overrideWith((ref) => RemoteSyncService(
          api: ref.watch(_apiClientProvider),
          db: ref.watch(appDatabaseProvider),
          // 401 with no silent re-auth means the session is gone - drive the
          // auth layer to sign out so the router bounces to Sign-in.
          onAuthExpired: () => ref.read(authRepositoryProvider).signOut(),
        )),
    reportErrorProvider.overrideWith((ref) {
      final c = ref.watch(_apiClientProvider);
      return (qnaId, message) =>
          c.dio.post('/qna/$qnaId/report', data: {'message': message});
    }),
  ];
}
