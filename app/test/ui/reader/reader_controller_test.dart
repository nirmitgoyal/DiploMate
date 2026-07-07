import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/ui/reader/reader_controller.dart';

void main() {
  late AppDatabase db;
  late StudyRepository repo;
  var now = DateTime(2026, 7, 4, 10, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 7, 4, 10, 0);
    repo = StudyRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  group('queue mode', () {
    test('starts unrevealed at position 1 and records recall_shown', () async {
      final c = ReaderController.queue(
          repo: repo, queue: ['Q1', 'Q2'], now: () => now);
      expect(c.mode, ReaderMode.queue);
      expect(c.currentQnaId, 'Q1');
      expect(c.position, 1);
      expect(c.total, 2);
      expect(c.revealed, false);
      await pumpEventQueue();
      final events = await db.select(db.pendingAppEvents).get();
      expect(events.where((e) => e.eventType == 'recall_shown').length, 1);
    });

    test('reveal records recall_revealed with hidden_ms >= elapsed', () async {
      final c = ReaderController.queue(repo: repo, queue: ['Q1'], now: () => now);
      now = now.add(const Duration(seconds: 14));
      await c.reveal();
      expect(c.revealed, true);
      final events = await db.select(db.pendingAppEvents).get();
      final revealed =
          events.singleWhere((e) => e.eventType == 'recall_revealed');
      expect(revealed.hiddenMs, 14000);
      expect(revealed.contentId, 'Q1');
    });

    test('rate persists then auto-advances; queue exhausts to complete', () async {
      final c = ReaderController.queue(
          repo: repo, queue: ['Q1', 'Q2'], now: () => now);
      await c.reveal();
      await c.rate(WireRating.good);
      expect(c.currentQnaId, 'Q2');
      expect(c.position, 2);
      expect(c.revealed, false); // next card starts at the recall gate
      await c.reveal();
      await c.rate(WireRating.again);
      expect(c.complete, true);
      expect(c.currentQnaId, isNull);
      final rows = await db.select(db.pendingReviewEvents).get();
      expect(rows.length, 2);
    });

    test('rate before reveal is a no-op (soft gate)', () async {
      final c = ReaderController.queue(repo: repo, queue: ['Q1'], now: () => now);
      await c.rate(WireRating.good);
      expect((await db.select(db.pendingReviewEvents).get()), isEmpty);
      expect(c.position, 1);
    });
  });

  group('browse mode', () {
    test('rate-then-stay: rating persists but does NOT advance', () async {
      final c = ReaderController.browse(
          repo: repo,
          qnaId: 'Q2',
          chapterQnaIds: ['Q1', 'Q2', 'Q3'],
          now: () => now);
      expect(c.mode, ReaderMode.browse);
      expect(c.currentQnaId, 'Q2');
      await c.reveal();
      await c.rate(WireRating.hard);
      expect(c.currentQnaId, 'Q2'); // stays
      expect(c.revealed, true); // still on the revealed answer
      expect(c.hasNextInChapter, true);
      expect((await db.select(db.pendingReviewEvents).get()).length, 1);
    });

    test('nextInChapter advances within the chapter and resets the gate', () async {
      final c = ReaderController.browse(
          repo: repo,
          qnaId: 'Q2',
          chapterQnaIds: ['Q1', 'Q2', 'Q3'],
          now: () => now);
      await c.reveal();
      c.nextInChapter();
      expect(c.currentQnaId, 'Q3');
      expect(c.revealed, false);
      expect(c.hasNextInChapter, false); // Q3 is last
    });
  });
}
