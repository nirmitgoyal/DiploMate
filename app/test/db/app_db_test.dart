import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 3', () {
    expect(db.schemaVersion, 3);
  });

  test('content mirror round-trips a qna row with contract column names', () async {
    await db.into(db.specialities).insert(SpecialitiesCompanion.insert(
        id: '01SPEC', name: 'Anaesthesia', examType: 'DNB', slug: 'anaesthesia'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        id: '01CHAP', specialityId: '01SPEC', title: 'Airway Management',
        slug: 'airway-management'));
    await db.into(db.qnas).insert(QnasCompanion.insert(
        id: '01QNA', chapterId: '01CHAP', question: 'Define TAP block.',
        earnsMarks: '[]', sections: '[]'));

    final row = await (db.select(db.qnas)
          ..where((q) => q.id.equals('01QNA')))
        .getSingle();
    expect(row.chapterId, '01CHAP');
    expect(row.question, 'Define TAP block.');
  });

  test('pending_review_events stores an event with null synced_at', () async {
    await db.into(db.pendingReviewEvents).insert(
        PendingReviewEventsCompanion.insert(
            id: 'uuid-1',
            contentId: '01QNA',
            rating: 'good',
            shownAt: DateTime.utc(2026, 7, 4, 10, 0, 0),
            revealedAt: DateTime.utc(2026, 7, 4, 10, 0, 15),
            ratedAt: DateTime.utc(2026, 7, 4, 10, 0, 20),
            localDay: '2026-07-04'));
    final row = await db.select(db.pendingReviewEvents).getSingle();
    expect(row.syncedAt, isNull);
    expect(row.rating, 'good');
  });

  test('duplicate review-event id is ignored (idempotent local insert)', () async {
    final e = PendingReviewEventsCompanion.insert(
        id: 'uuid-dup',
        contentId: '01QNA',
        rating: 'again',
        shownAt: DateTime.utc(2026, 7, 4),
        revealedAt: DateTime.utc(2026, 7, 4),
        ratedAt: DateTime.utc(2026, 7, 4),
        localDay: '2026-07-04');
    await db.into(db.pendingReviewEvents).insert(e);
    await db
        .into(db.pendingReviewEvents)
        .insert(e, mode: InsertMode.insertOrIgnore);
    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
  });

  test('cached_chapters and bookmarks and local_settings exist', () async {
    await db.into(db.cachedChapters).insert(CachedChaptersCompanion.insert(
        chapterId: '01CHAP', contentVersion: 3,
        cachedAt: DateTime.utc(2026, 7, 4)));
    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
        contentId: '01QNA', updatedAt: DateTime.utc(2026, 7, 4)));
    await db.into(db.localSettings).insert(LocalSettingsCompanion.insert(
        key: 'reminder_enabled', value: 'true'));
    expect((await db.select(db.bookmarks).getSingle()).deleted, false);
  });
}
