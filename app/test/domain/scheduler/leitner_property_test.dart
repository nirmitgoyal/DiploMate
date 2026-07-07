import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/local_day.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

const ratingsWithUnknown = ['again', 'hard', 'good', 'easy']; // 'easy' = unknown

List<ReviewEvent> randomHistory(Random rnd, String contentId, int n) {
  var day = '2026-01-01';
  var t = DateTime.parse('2026-01-01T09:00:00');
  final events = <ReviewEvent>[];
  for (var i = 0; i < n; i++) {
    day = addLocalDays(day, rnd.nextInt(4)); // 0-3 day gaps
    t = t.add(Duration(hours: 6 + rnd.nextInt(48)));
    events.add(ReviewEvent(
      id: '$contentId-$i',
      contentId: contentId,
      rating: ratingsWithUnknown[rnd.nextInt(ratingsWithUnknown.length)],
      shownAt: t.subtract(const Duration(seconds: 40)),
      revealedAt: t.subtract(const Duration(seconds: 12)),
      ratedAt: t,
      localDay: day,
    ));
  }
  return events;
}

bool sameState(CardState? a, CardState? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.contentId == b.contentId &&
      a.bucket == b.bucket &&
      a.intervalDays == b.intervalDays &&
      a.dueLocalDay == b.dueLocalDay &&
      a.lastRatedDay == b.lastRatedDay &&
      a.dueEndOfQueue == b.dueEndOfQueue;
}

void main() {
  test('PROPERTY fold determinism: same event list folds to the same state', () {
    final rnd = Random(42);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      expect(sameState(foldEvents('Q$run', events), foldEvents('Q$run', events)),
          isTrue,
          reason: 'run $run diverged');
    }
  });

  test('PROPERTY replay idempotence: full re-fold == incremental applyRating', () {
    final rnd = Random(7);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      CardState? incremental;
      for (final e in events) {
        incremental = applyRating('Q$run', incremental, e);
      }
      expect(sameState(foldEvents('Q$run', events), incremental), isTrue,
          reason: 'run $run: incremental replay diverged from full fold');
    }
  });

  test('PROPERTY hard carries bucket and interval, due = ratedDay + 2', () {
    final rnd = Random(99);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      CardState? prev;
      for (final e in events) {
        final next = applyRating('Q$run', prev, e);
        if (e.rating == 'hard') {
          expect(next!.bucket, prev?.bucket ?? 1,
              reason: 'run $run: hard changed bucket');
          expect(next.intervalDays, prev?.intervalDays ?? 0,
              reason: 'run $run: hard changed interval');
          expect(next.dueLocalDay, addLocalDays(e.localDay, 2),
              reason: 'run $run: hard due is not +2d');
        }
        prev = next;
      }
    }
  });

  test('PROPERTY unknown ratings are transparent: fold(with) == fold(without)', () {
    final rnd = Random(1234);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      final known = events
          .where((e) => ['again', 'hard', 'good'].contains(e.rating))
          .toList();
      expect(
          sameState(foldEvents('Q$run', events), foldEvents('Q$run', known)),
          isTrue,
          reason: 'run $run: unknown rating leaked into state');
    }
  });

  test('PROPERTY content updates never touch scheduling: fold depends only on '
      'the event list (stable content IDs, A4)', () {
    // A chapter refresh rewrites qnas rows but never review events.
    // Fold input is the event list alone, so state must be identical however
    // often "content metadata" changes around it. Modeled by folding the same
    // events twice with an unrelated mutation between - plus a db-level proof
    // in test/data/study_repository_test.dart (Task 6).
    final rnd = Random(2026);
    for (var run = 0; run < 100; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      final before = foldEvents('Q$run', events);
      final unrelated = randomHistory(rnd, 'OTHER$run', 5); // "content update" noise
      foldAll(unrelated);
      final after = foldEvents('Q$run', events);
      expect(sameState(before, after), isTrue, reason: 'run $run');
    }
  });

  test('PROPERTY B3 doubling base is always >= 3 (reachability invariant)', () {
    final rnd = Random(555);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(40));
      CardState? prev;
      for (final e in events) {
        prev = applyRating('Q$run', prev, e);
        if (prev != null && prev.bucket == 3) {
          expect(prev.intervalDays >= 3, isTrue,
              reason: 'run $run: B3 with interval ${prev.intervalDays}');
        }
      }
    }
  });

  test('PROPERTY buildQueue is deterministic and due-only', () {
    final rnd = Random(31337);
    for (var run = 0; run < 100; run++) {
      final all = <ReviewEvent>[];
      for (var c = 0; c < 10; c++) {
        all.addAll(randomHistory(rnd, 'Q$run-$c', 1 + rnd.nextInt(10)));
      }
      final states = foldAll(all);
      const today = '2026-02-15';
      final q1 = buildQueue(states, today);
      final q2 = buildQueue(Map.fromEntries(states.entries.toList().reversed), today);
      expect(q1, q2, reason: 'run $run: map order leaked into queue order');
      for (final id in q1) {
        expect(states[id]!.dueLocalDay.compareTo(today) <= 0, isTrue,
            reason: 'run $run: non-due card $id queued');
      }
    }
  });
}
