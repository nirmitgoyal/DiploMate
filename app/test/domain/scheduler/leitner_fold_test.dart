import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

ReviewEvent ev(String rating, String day, {int seq = 0, String id = ''}) {
  final t = DateTime.parse('${day}T12:00:00').add(Duration(minutes: seq));
  return ReviewEvent(
    id: id.isEmpty ? '$rating-$day-$seq' : id,
    contentId: 'Q1',
    rating: rating,
    shownAt: t.subtract(const Duration(seconds: 30)),
    revealedAt: t.subtract(const Duration(seconds: 10)),
    ratedAt: t,
    localDay: day,
  );
}

void main() {
  test('no events -> null (card unseen, never queued: due-only queue)', () {
    expect(foldEvents('Q1', []), isNull);
  });

  test('first good: enters B1, moves to B2, due +1d, interval 1', () {
    final s = foldEvents('Q1', [ev('good', '2026-07-04')])!;
    expect(s.bucket, 2);
    expect(s.intervalDays, 1);
    expect(s.dueLocalDay, '2026-07-05');
    expect(s.lastRatedDay, '2026-07-04');
    expect(s.dueEndOfQueue, false);
  });

  test('good good: B2 -> B3, due +3d, interval 3', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-04'),
      ev('good', '2026-07-05'),
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 3);
    expect(s.dueLocalDay, '2026-07-08');
  });

  test('good in B3: stays B3, interval doubles (3 -> 6 -> 12)', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'),
      ev('good', '2026-07-02'),
      ev('good', '2026-07-05'),
      ev('good', '2026-07-11'),
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 12);
    expect(s.dueLocalDay, '2026-07-23');
  });

  test('again: back to B1, due SAME local day, end of queue, interval reset', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'),
      ev('again', '2026-07-02'),
    ])!;
    expect(s.bucket, 1);
    expect(s.intervalDays, 0);
    expect(s.dueLocalDay, '2026-07-02');
    expect(s.dueEndOfQueue, true);
  });

  test('hard: stays in bucket, keeps interval, due +2d', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'), // B2, interval 1
      ev('good', '2026-07-02'), // B3, interval 3
      ev('hard', '2026-07-05'), // stays B3, interval stays 3, due +2
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 3);
    expect(s.dueLocalDay, '2026-07-07');
    expect(s.dueEndOfQueue, false);
  });

  test('first rating hard: enters B1 and stays there, due +2d', () {
    final s = foldEvents('Q1', [ev('hard', '2026-07-04')])!;
    expect(s.bucket, 1);
    expect(s.dueLocalDay, '2026-07-06');
  });

  test('unknown rating value is skipped, state unchanged (FSRS forward-compat)', () {
    final withUnknown = foldEvents('Q1', [
      ev('good', '2026-07-04'),
      ev('easy', '2026-07-05'), // future FSRS value: skip + log
    ]);
    final without = foldEvents('Q1', [ev('good', '2026-07-04')]);
    expect(withUnknown!.bucket, without!.bucket);
    expect(withUnknown.intervalDays, without.intervalDays);
    expect(withUnknown.dueLocalDay, without.dueLocalDay);
  });

  test('only-unknown events -> null (card still unseen for scheduling)', () {
    expect(foldEvents('Q1', [ev('easy', '2026-07-04')]), isNull);
  });

  test('uiLabelForWire is the 2026-07-04 relabel', () {
    expect(uiLabelForWire[WireRating.good], 'Easy');
    expect(uiLabelForWire[WireRating.hard], 'Medium');
    expect(uiLabelForWire[WireRating.again], 'Hard');
  });
}
