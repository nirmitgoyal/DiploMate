import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';
import 'package:diplomate/services/notification_service.dart';

CardState cs(String id, String due) => CardState(
    contentId: id,
    bucket: 1,
    intervalDays: 1,
    dueLocalDay: due,
    lastRatedDay: '2026-07-01',
    dueEndOfQueue: false);

void main() {
  test('no card states -> no notifications (day-zero users get silence)', () {
    expect(planReminders({}, DateTime(2026, 7, 4, 10, 0)), isEmpty);
  });

  test('due today, before 8pm -> exact one-shot tonight + countless repeat '
      'from tomorrow', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-02')},
        DateTime(2026, 7, 4, 10, 0));
    expect(plan.length, 2);
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.id, 1);
    expect(oneShot.fireAt, DateTime(2026, 7, 4, 20, 0));
    expect(oneShot.body, '2 answers due today');
    final repeat = plan.singleWhere((p) => p.repeatsDaily);
    expect(repeat.id, 2);
    expect(repeat.fireAt, DateTime(2026, 7, 5, 20, 0));
    expect(repeat.body, 'Your recall queue has answers due');
  });

  test('after 8pm tonight -> one-shot moves to tomorrow with TOMORROW\'s count', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-05')},
        DateTime(2026, 7, 4, 21, 0)); // 9pm: tonight's slot has passed
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.fireAt, DateTime(2026, 7, 5, 20, 0));
    expect(oneShot.body, '2 answers due today'); // A overdue + B due by the 5th
  });

  test('nothing due today but due in 3 days -> one-shot skips to that day '
      '(never a zero-count or lying notification between)', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-07')}, DateTime(2026, 7, 4, 10, 0));
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.fireAt, DateTime(2026, 7, 7, 20, 0));
    expect(oneShot.body, '1 answer due today'); // singular
    final repeat = plan.singleWhere((p) => p.repeatsDaily);
    expect(repeat.fireAt, DateTime(2026, 7, 8, 20, 0));
  });

  test('FRESHNESS: re-planning after a rating replaces the stale count', () {
    final before = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-04')},
        DateTime(2026, 7, 4, 10, 0));
    expect(before.singleWhere((p) => !p.repeatsDaily).body,
        '2 answers due today');
    // User rates A 'good' at 10:05 -> A due tomorrow. Reschedule trigger fires.
    final after = planReminders(
        {'A': cs('A', '2026-07-05'), 'B': cs('B', '2026-07-04')},
        DateTime(2026, 7, 4, 10, 5));
    expect(after.singleWhere((p) => !p.repeatsDaily).body,
        '1 answer due today');
  });

  test('FRESHNESS: post-rollover re-plan uses the new local day', () {
    // 3:59am July 5: study-day is still July 4; card due July 5.
    final before = planReminders(
        {'A': cs('A', '2026-07-05')}, DateTime(2026, 7, 5, 3, 59));
    // fire day chosen by calendar: July 5 8pm has count 1 -> fine either side,
    // but the count must be computed for the FIRE day, not "now"'s study day.
    expect(before.singleWhere((p) => !p.repeatsDaily).fireAt,
        DateTime(2026, 7, 5, 20, 0));
    final after = planReminders(
        {'A': cs('A', '2026-07-05')}, DateTime(2026, 7, 5, 4, 1));
    expect(after.singleWhere((p) => !p.repeatsDaily).body,
        '1 answer due today');
  });
}
