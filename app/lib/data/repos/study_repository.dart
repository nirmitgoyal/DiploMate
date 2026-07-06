import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/local_day.dart';
import '../../domain/models.dart';
import '../db/app_db.dart';

const _uuid = Uuid();
const _sessionIdleWindow = Duration(minutes: 30); // D9: session_start definition

/// Local-first event writers. Every write completes in drift BEFORE the
/// returned future resolves; callers ack the UI only after awaiting (D4).
class StudyRepository {
  StudyRepository(this._db, {DateTime Function() now = DateTime.now})
      : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Persists the review event (and its recall_rated app event) and returns
  /// the domain event. Resolves only after both rows are in drift.
  Future<ReviewEvent> recordRating({
    required String qnaId,
    required WireRating rating,
    required DateTime shownAt,
    required DateTime revealedAt,
  }) async {
    final ratedAt = _now();
    final event = ReviewEvent(
      id: _uuid.v4(),
      contentId: qnaId,
      rating: rating.name, // wire string; enum owned by sql/0003_users_events.sql
      shownAt: shownAt,
      revealedAt: revealedAt,
      ratedAt: ratedAt,
      localDay: localDay(ratedAt),
    );
    await _db.transaction(() async {
      await _db.into(_db.pendingReviewEvents).insert(
            PendingReviewEventsCompanion.insert(
              id: event.id,
              contentId: event.contentId,
              rating: event.rating,
              shownAt: event.shownAt,
              revealedAt: event.revealedAt,
              ratedAt: event.ratedAt,
              localDay: event.localDay,
            ),
            mode: InsertMode.insertOrIgnore, // idempotent on id (D4)
          );
      await _insertAppEvent(eventType: 'recall_rated', contentId: qnaId);
    });
    return event;
  }

  Future<void> recordAppEvent({
    required String eventType,
    String? contentId,
    int? hiddenMs,
  }) =>
      _insertAppEvent(
          eventType: eventType, contentId: contentId, hiddenMs: hiddenMs);

  /// D9: session_start = first activity after >= 30 min of inactivity.
  Future<void> recordSessionStartIfIdle() async {
    final last = await (_db.select(_db.pendingAppEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .getSingleOrNull();
    final now = _now();
    if (last == null || now.difference(last.occurredAt) >= _sessionIdleWindow) {
      await _insertAppEvent(eventType: 'session_start');
    }
  }

  Future<void> _insertAppEvent({
    required String eventType,
    String? contentId,
    int? hiddenMs,
  }) async {
    final occurredAt = _now();
    await _db.into(_db.pendingAppEvents).insert(
          PendingAppEventsCompanion.insert(
            id: _uuid.v4(),
            eventType: eventType,
            contentId: Value(contentId),
            hiddenMs: Value(hiddenMs),
            occurredAt: occurredAt,
            localDay: localDay(occurredAt),
          ),
        );
  }

  Future<List<ReviewEvent>> allReviewEvents() async {
    final rows = await (_db.select(_db.pendingReviewEvents)
          ..orderBy([(t) => OrderingTerm.asc(t.ratedAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Stream<List<ReviewEvent>> watchReviewEvents() =>
      (_db.select(_db.pendingReviewEvents)
            ..orderBy([(t) => OrderingTerm.asc(t.ratedAt)]))
          .watch()
          .map((rows) => rows.map(_toDomain).toList());

  ReviewEvent _toDomain(PendingReviewEvent row) => ReviewEvent(
        id: row.id,
        contentId: row.contentId,
        rating: row.rating,
        shownAt: row.shownAt,
        revealedAt: row.revealedAt,
        ratedAt: row.ratedAt,
        localDay: row.localDay,
      );
}
