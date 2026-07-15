import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 4', () {
    expect(db.schemaVersion, 4);
  });

  test('replaceChapterContent derives + stores the list-page summary', () async {
    final items = [
      {
        'id': 'Q_SUMMARY_SECTION', 'chapter_id': 'C1', 'question': 'Q1',
        'years': null, 'marks': null, 'earns_marks': [], 'sort_order': 0,
        'images': [],
        'sections': [
          {'key': 'def', 'heading': 'Definition', 'body_md': 'A block.', 'marks': 1},
          {'key': 'sum', 'heading': 'Summary', 'body_md': 'Know the plane.', 'marks': null},
        ],
      },
      {
        'id': 'Q_FIRST_SECTION', 'chapter_id': 'C1', 'question': 'Q2',
        'years': null, 'marks': null, 'earns_marks': [], 'sort_order': 1,
        'images': [],
        // No `Summary` section (real Bedrock shape) + markdown to strip.
        'sections': [
          {'key': 'ind', 'heading': 'Indications', 'body_md': '**Full stomach**, GORD.', 'marks': 2},
        ],
      },
      {
        'id': 'Q_SERVER_AUTHORED', 'chapter_id': 'C1', 'question': 'Q3',
        'years': null, 'marks': null, 'earns_marks': [], 'sort_order': 2,
        'images': [], 'summary': 'Server-authored gist.',
        'sections': [
          {'key': 'x', 'heading': 'X', 'body_md': 'ignored', 'marks': null},
        ],
      },
    ];
    await db.replaceChapterContent('C1', 1, items);
    final rows = await db.readQnasByChapter('C1');

    expect(rows.map((r) => r.summary), [
      'Know the plane.', // dedicated Summary section wins
      'Full stomach, GORD.', // first section, markdown stripped
      'Server-authored gist.', // explicit server field honored over sections
    ]);
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
