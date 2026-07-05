class SessionUser {
  const SessionUser({required this.id, required this.email, this.name, this.photoUrl,
      this.specialityId, required this.specialityChangeCount});
  final String id, email;
  final String? name, photoUrl, specialityId;
  final int specialityChangeCount;

  SessionUser copyWith({String? specialityId, int? specialityChangeCount}) => SessionUser(
      id: id, email: email, name: name, photoUrl: photoUrl,
      specialityId: specialityId ?? this.specialityId,
      specialityChangeCount: specialityChangeCount ?? this.specialityChangeCount);
}

class ChangeLimitReached implements Exception {}

class SignInCancelled implements Exception {}

class AuthOffline implements Exception {}

/// Contract-verbatim. Plan 6 implements against google_sign_in + POST /auth/google.
abstract class AuthRepository {
  Future<SessionUser> signInWithGoogle();
  Future<SessionUser?> restoreSession();
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<SessionUser> setSpeciality(String specialityId);
}
