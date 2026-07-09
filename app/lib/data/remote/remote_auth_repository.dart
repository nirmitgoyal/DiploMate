import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repos/auth_repository.dart';
import 'api_client.dart';

/// Thin seam over google_sign_in v7 (singleton instance API).
/// serverClientId MUST be the WEB client id - it becomes the ID token `aud`
/// the API verifies against GOOGLE_WEB_CLIENT_ID (D5).
abstract class GoogleSignInLike {
  Future<String?> idToken({required bool silent});
  Future<void> signOut();
}

class RealGoogleSignIn implements GoogleSignInLike {
  RealGoogleSignIn({required String serverClientId})
      : _init = GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  final Future<void> _init;

  @override
  Future<String?> idToken({required bool silent}) async {
    await _init;
    final account = silent
        ? await GoogleSignIn.instance.attemptLightweightAuthentication()
        : await GoogleSignIn.instance.authenticate();
    return account?.authentication.idToken;
  }

  @override
  Future<void> signOut() async {
    await _init;
    await GoogleSignIn.instance.signOut();
  }
}

/// ponytail: dev-only fake, skips Google entirely on the simulator. Active only
/// when built with --dart-define=DEV_FAKE_AUTH=true; the backend must ALSO run
/// with DEV_FAKE_AUTH set or it rejects 'dev-fake-token'. Never wired in prod.
class FakeGoogleSignIn implements GoogleSignInLike {
  @override
  Future<String?> idToken({required bool silent}) async => 'dev-fake-token';
  @override
  Future<void> signOut() async {}
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required this.api, required this.google});
  final ApiClient api;
  final GoogleSignInLike google;

  SessionUser _toUser(Map<String, dynamic> u) => SessionUser(
        id: u['id'] as String,
        email: u['email'] as String,
        name: u['name'] as String?,
        photoUrl: u['photo_url'] as String?,
        specialityId: u['speciality_id'] as String?,
        specialityChangeCount: (u['speciality_change_count'] ?? 0) as int,
      );

  Future<SessionUser> _exchange({required bool silent}) async {
    final String? idToken;
    try {
      idToken = await google.idToken(silent: silent);
    } catch (_) {
      throw SignInCancelled();
    }
    if (idToken == null) throw SignInCancelled();
    try {
      final out = await api.authGoogle(idToken);
      return _toUser(out.user);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AuthOffline();
      }
      rethrow;
    }
  }

  @override
  Future<SessionUser> signInWithGoogle() => _exchange(silent: false);

  @override
  Future<SessionUser?> restoreSession() async {
    if (api.sessionJwt == null) return null;
    try {
      // /manifest doubles as the whoami probe: authed + cheap.
      final res = await api.dio.get('/manifest');
      if (res.statusCode == 200) {
        // We have no /me read endpoint (inventory-locked); user fields come
        // from the LAST sign-in and live in drift local_settings (plan 5).
        // Re-auth silently to refresh them:
        return _exchange(silent: true);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // expired-online (state 6): silent re-auth with the same account.
        try {
          return await _exchange(silent: true);
        } on SignInCancelled {
          await api.setSessionJwt(null);
          return null;
        }
      }
      // expired-offline (state 5): keep the JWT; caller stays signed-in
      // visually and sync retries later with backoff.
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await google.signOut();
    await api.setSessionJwt(null);
  }

  @override
  Future<void> deleteAccount() async {
    await api.dio.delete('/me');
    await signOut();
  }

  @override
  Future<SessionUser> setSpeciality(String specialityId) async {
    try {
      final res = await api.dio
          .post('/me/speciality', data: {'speciality_id': specialityId});
      final current = res.data as Map<String, dynamic>;
      return SessionUser(
        id: '', email: '', name: null, photoUrl: null,
        specialityId: current['speciality_id'] as String?,
        specialityChangeCount: current['speciality_change_count'] as int,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw ChangeLimitReached();
      rethrow;
    }
  }
}
