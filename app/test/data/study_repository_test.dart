import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late StudyRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 7, 4, 21, 30); // 9:30 pm local
    repo = StudyRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('recordRating persists a review event row BEFORE resolving (D4)', () async {
    final e = await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 45)),
        revealedAt: now.subtract(const Duration(seconds: 12)));
    // The await IS the ack gate: by the time the future resolves the row is in drift.
    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
    expect(rows.single.id, e.id);
    expect(rows.single.rating, 'good');
    expect(rows.single.localDay, '2026-07-04');
    expect(rows.single.syncedAt, isNull);
  });

  test('recordRating also writes a recall_rated app event (D9 funnel)', () async {
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.again,
        shownAt: now.subtract(const Duration(seconds: 45)),
        revealedAt: now.subtract(const Duration(seconds: 12)));
    final appRows = await db.select(db.pendingAppEvents).get();
    expect(appRows.where((r) => r.eventType == 'recall_rated').length, 1);
    expect(appRows.single.contentId, 'Q1');
  });

  test('rating survives app kill: rows persist across a reopen (file db)', () async {
    final tempDir = Directory.systemTemp.createTempSync('diplomate');
    try {
      final file = File('${tempDir.path}/kill.db');
      final db1 = AppDatabase(NativeDatabase(file));
      final r1 = StudyRepository(db1, now: () => now);
      await r1.recordRating(
          qnaId: 'Q1',
          rating: WireRating.hard,
          shownAt: now.subtract(const Duration(seconds: 30)),
          revealedAt: now.subtract(const Duration(seconds: 11)));
      await db1.close(); // "kill" - the ack only ever happens after this insert
      final db2 = AppDatabase(NativeDatabase(file));
      final rows = await db2.select(db2.pendingReviewEvents).get();
      expect(rows.length, 1);
      expect(rows.single.rating, 'hard');
      await db2.close();
    } finally {
      tempDir.deleteSync(recursive: true); // no leaked db files across test runs
    }
  });

  test('recordAppEvent writes recall_revealed with hidden_ms', () async {
    await repo.recordAppEvent(
        eventType: 'recall_revealed', contentId: 'Q1', hiddenMs: 14200);
    final row = await db.select(db.pendingAppEvents).getSingle();
    expect(row.eventType, 'recall_revealed');
    expect(row.hiddenMs, 14200);
    expect(row.localDay, '2026-07-04');
  });

  test('session_start: written when idle > 30 min, skipped when active', () async {
    await repo.recordSessionStartIfIdle(); // no prior events -> session_start
    await repo.recordAppEvent(eventType: 'topic_opened', contentId: 'T1');
    now = now.add(const Duration(minutes: 10));
    await repo.recordSessionStartIfIdle(); // active 10 min ago -> skip
    now = now.add(const Duration(minutes: 31));
    await repo.recordSessionStartIfIdle(); // idle 31 min -> session_start
    final rows = await db.select(db.pendingAppEvents).get();
    expect(rows.where((r) => r.eventType == 'session_start').length, 2);
  });

  test('allReviewEvents returns domain events sorted by ratedAt', () async {
    now = DateTime(2026, 7, 4, 10, 0);
    await repo.recordRating(
        qnaId: 'Q2',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    now = DateTime(2026, 7, 4, 9, 0); // earlier rating recorded second
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    final events = await repo.allReviewEvents();
    expect(events.map((e) => e.contentId).toList(), ['Q1', 'Q2']);
  });

  test('content update (chapter refresh) leaves review events + fold untouched', () async {
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    final before = foldAll(await repo.allReviewEvents());

    // Simulate exactly what plan 6's chapter refresh does: delete + reinsert
    // qnas rows in one transaction. Events are keyed by stable ULIDs (A4).
    await db.transaction(() async {
      await db.delete(db.qnas).go();
      await db.into(db.qnas).insert(QnasCompanion.insert(
          id: 'Q1', chapterId: 'T1', question: 'Updated wording',
          earnsMarks: '[]', sections: '[]'));
    });

    final after = foldAll(await repo.allReviewEvents());
    expect(after['Q1']!.bucket, before['Q1']!.bucket);
    expect(after['Q1']!.intervalDays, before['Q1']!.intervalDays);
    expect(after['Q1']!.dueLocalDay, before['Q1']!.dueLocalDay);
  });
}
