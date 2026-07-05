import '../repos/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failWith});

  /// Set in tests: SignInCancelled(), AuthOffline(), or any Exception.
  Object? failWith;
  SessionUser? _user;

  static const _fresh = SessionUser(
      id: '01J0USERFIXTURE00000000001', email: 'ananya@example.com',
      name: 'Ananya Sharma', photoUrl: null, specialityId: null,
      specialityChangeCount: 0);

  @override
  Future<SessionUser> signInWithGoogle() async {
    final f = failWith;
    if (f != null) throw f;
    return _user ??= _fresh;
  }

  @override
  Future<SessionUser?> restoreSession() async => _user;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteAccount() async => _user = null;

  @override
  Future<SessionUser> setSpeciality(String specialityId) async {
    final u = _user ?? _fresh;
    if (u.specialityId != null &&
        u.specialityId != specialityId &&
        u.specialityChangeCount >= 1) {
      throw ChangeLimitReached();
    }
    final changed = u.specialityId != null && u.specialityId != specialityId;
    return _user = u.copyWith(
        specialityId: specialityId,
        specialityChangeCount: u.specialityChangeCount + (changed ? 1 : 0));
  }
}
