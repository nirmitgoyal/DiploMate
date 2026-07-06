import 'dart:math';

import 'package:dio/dio.dart';

import '../../services/sync_service.dart';
import '../db/app_db.dart';
import 'api_client.dart';

/// Real SyncService (plan 6, Task 4). Drains the pending event tables to the
/// server, merges bookmarks LWW, and stamps last_synced_at - all LOCAL-FIRST:
/// a row is deleted only once the server has accepted it (inserted), and a
/// persistently-rejected row is dropped as poison only after 5 rejections
/// (the counter lives in drift, so the count survives restarts - T4). A
/// network/5xx/401 arms an exponential backoff window; calls inside the window
/// return immediately so a flaky connection never becomes a retry storm.
class RemoteSyncService implements SyncService {
  RemoteSyncService({
    required ApiClient api,
    required AppDatabase db,
    DateTime Function() now = DateTime.now,
    Random? random,
    void Function() onAuthExpired = _noop,
  })  : _api = api,
        _db = db,
        _now = now,
        _random = random ?? Random(),
        _onAuthExpired = onAuthExpired;

  final ApiClient _api;
  final AppDatabase _db;
  final DateTime Function() _now;
  final Random _random;
  final void Function() _onAuthExpired;

  // Backoff state (in memory - a fresh process starts clean and simply tries
  // again, which is correct: the durable guarantee is the drain/poison state,
  // not the backoff clock).
  DateTime? _nextAttempt;
  int _failures = 0;

  static void _noop() {}

  static const _lastSyncedKey = 'last_synced_at';
  static const _maxBackoffMinutes = 32;

  @override
  Future<void> flush() async {
    if (_nextAttempt != null && _now().isBefore(_nextAttempt!)) {
      return; // inside the backoff window - no HTTP, no retry storm
    }
    try {
      await _drain(
        path: '/sync/review-events',
        rows: await _db.unsyncedReviewEvents(),
        toWire: _reviewToWire,
        idOf: (r) => r.id,
        onInserted: _db.deleteReviewEventsByIds,
        onRejected: _db.recordReviewRejections,
      );
      await _drain(
        path: '/sync/app-events',
        rows: await _db.unsyncedAppEvents(),
        toWire: _appToWire,
        idOf: (r) => r.id,
        onInserted: _db.deleteAppEventsByIds,
        onRejected: _db.recordAppRejections,
      );
      await _syncBookmarks();

      // Full success: reset backoff and stamp the clock.
      _failures = 0;
      _nextAttempt = null;
      await _db.writeSetting(_lastSyncedKey, _now().toIso8601String());
    } on DioException catch (e) {
      _handleFailure(e);
    }
  }

  @override
  Stream<DateTime?> lastSyncedAt() =>
      _db.watchSetting(_lastSyncedKey).map((v) => v == null ? null : DateTime.tryParse(v));

  // POST a batch, delete the rows the server took, bump/poison the rest.
  Future<void> _drain<R>({
    required String path,
    required List<R> rows,
    required Map<String, dynamic> Function(R) toWire,
    required String Function(R) idOf,
    required Future<void> Function(List<String>) onInserted,
    required Future<void> Function(List<String>) onRejected,
  }) async {
    if (rows.isEmpty) return;
    final res = await _api.dio.post(path, data: {
      'events': [for (final r in rows) toWire(r)],
    });
    final body = res.data as Map<String, dynamic>;
    final rejectedIds = {
      for (final r in (body['rejected'] as List? ?? const []))
        (r as Map<String, dynamic>)['id'] as String,
    };
    // Everything sent that the server did NOT reject was accepted (inserted or
    // idempotently already-present) - either way it is safe to delete locally.
    final acceptedIds = [
      for (final r in rows)
        if (!rejectedIds.contains(idOf(r))) idOf(r),
    ];
    await onInserted(acceptedIds);
    if (rejectedIds.isNotEmpty) await onRejected(rejectedIds.toList());
  }

  Future<void> _syncBookmarks() async {
    final local = await _db.readBookmarkRows();
    final res = await _api.dio.put('/me/bookmarks', data: {
      'bookmarks': [
        for (final b in local)
          {
            'content_id': b.contentId,
            'updated_at': b.updatedAt.toIso8601String(),
            'deleted': b.deleted,
          },
      ],
    });
    final body = res.data as Map<String, dynamic>;
    // Server response is the merged truth (incl. tombstones); overwrite local
    // rows with it, keeping server updated_at/deleted (LWW resolved server-side).
    for (final b in (body['bookmarks'] as List? ?? const [])) {
      final m = b as Map<String, dynamic>;
      await _db.upsertBookmark(
        m['content_id'] as String,
        DateTime.parse(m['updated_at'] as String),
        m['deleted'] as bool? ?? false,
      );
    }
  }

  void _handleFailure(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) _onAuthExpired();
    // Arm backoff on 401 / 5xx / network. A plain 4xx (bad client request) is
    // not transient, so it does not open a window - but per-row 400s are
    // already handled as `rejected` inside _drain, so a whole-request 4xx here
    // is genuinely exceptional; still, don't wedge on it.
    final transient = status == null || status == 401 || status >= 500;
    if (!transient) return;
    final backoffMin = min(pow(2, _failures).toInt(), _maxBackoffMinutes);
    final jitter = 1 + (_random.nextDouble() * 0.5 - 0.25); // +/- 25%
    _nextAttempt = _now().add(
        Duration(milliseconds: (backoffMin * 60000 * jitter).round()));
    _failures++;
  }

  Map<String, dynamic> _reviewToWire(PendingReviewEvent r) => {
        'id': r.id,
        'content_id': r.contentId,
        'rating': r.rating,
        'shown_at': r.shownAt.toIso8601String(),
        'revealed_at': r.revealedAt.toIso8601String(),
        'rated_at': r.ratedAt.toIso8601String(),
        'local_day': r.localDay,
      };

  Map<String, dynamic> _appToWire(PendingAppEvent r) => {
        'id': r.id,
        'event_type': r.eventType,
        'content_id': r.contentId,
        'hidden_ms': r.hiddenMs,
        'occurred_at': r.occurredAt.toIso8601String(),
        'local_day': r.localDay,
      };
}
