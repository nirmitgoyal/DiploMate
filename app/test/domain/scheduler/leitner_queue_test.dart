import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

CardState cs(String id,
        {int bucket = 1,
        String due = '2026-07-04',
        String rated = '2026-07-01',
        bool endOfQueue = false,
        int interval = 1}) =>
    CardState(
        contentId: id,
        bucket: bucket,
        intervalDays: interval,
        dueLocalDay: due,
        lastRatedDay: rated,
        dueEndOfQueue: endOfQueue);

void main() {
  const today = '2026-07-04';

  test('queue is due-only: future cards and unseen cards never appear', () {
    final q = buildQueue({
      'A': cs('A', due: '2026-07-04'),
      'B': cs('B', due: '2026-07-05'), // tomorrow: excluded
    }, today);
    expect(q, ['A']);
  });

  test('overdue first, then lowest bucket, then oldest lastRatedDay', () {
    final q = buildQueue({
      'todayB2': cs('todayB2', bucket: 2, due: today, rated: '2026-07-01'),
      'overdue': cs('overdue', bucket: 3, due: '2026-07-02', rated: '2026-07-01'),
      'todayB1old': cs('todayB1old', bucket: 1, due: today, rated: '2026-06-28'),
      'todayB1new': cs('todayB1new', bucket: 1, due: today, rated: '2026-07-03'),
    }, today);
    expect(q, ['overdue', 'todayB1old', 'todayB1new', 'todayB2']);
  });

  test('again repeats (dueEndOfQueue, same day) go to the BACK of today', () {
    final q = buildQueue({
      'againNow': cs('againNow', due: today, endOfQueue: true, rated: today),
      'normal': cs('normal', bucket: 3, due: today, rated: '2026-07-01'),
    }, today);
    expect(q, ['normal', 'againNow']);
  });

  test('an end-of-queue card from YESTERDAY is plain overdue, not back-of-queue', () {
    final q = buildQueue({
      'staleAgain': cs('staleAgain', due: '2026-07-03', endOfQueue: true, rated: '2026-07-03'),
      'todayCard': cs('todayCard', due: today, rated: '2026-07-01'),
    }, today);
    expect(q, ['staleAgain', 'todayCard']);
  });

  test('deterministic tie-break by contentId', () {
    final a = buildQueue({
      'B': cs('B'),
      'A': cs('A'),
    }, today);
    final b = buildQueue({
      'A': cs('A'),
      'B': cs('B'),
    }, today);
    expect(a, b);
    expect(a, ['A', 'B']);
  });

  test('dueCountFor counts dueLocalDay <= day', () {
    final states = {
      'A': cs('A', due: '2026-07-04'),
      'B': cs('B', due: '2026-07-06'),
    };
    expect(dueCountFor(states, '2026-07-04'), 1);
    expect(dueCountFor(states, '2026-07-06'), 2);
  });
}
