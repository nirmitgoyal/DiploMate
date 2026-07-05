/// Contract-verbatim. Plan 6 implements (backoff + jitter, X-Refreshed-Token).
abstract class SyncService {
  Future<void> flush();
  Stream<DateTime?> lastSyncedAt();
}
