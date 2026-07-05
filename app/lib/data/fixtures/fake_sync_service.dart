import '../../services/sync_service.dart';

class FakeSyncService implements SyncService {
  DateTime? last = DateTime(2026, 7, 1, 9);

  @override
  Future<void> flush() async {}

  @override
  Stream<DateTime?> lastSyncedAt() => Stream.value(last);
}
