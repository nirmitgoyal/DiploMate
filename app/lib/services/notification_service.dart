import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db/app_db.dart';
import '../domain/scheduler/leitner.dart';

const _reminderHour = 20; // 8:00 pm (Account row: "On · 8:00 pm")
const _oneShotId = 1;
const _repeatId = 2;
const queuePayload = 'queue'; // deep-link payload -> Reader queue mode

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.fireAt,
    required this.body,
    required this.repeatsDaily,
  });

  final int id;
  final DateTime fireAt; // local wall clock
  final String body;
  final bool repeatsDaily;
}

/// Pure planner - all D19 honesty rules live here (ENG-T11: fresh count at
/// fire OR countless copy; this plan does both). The next day with a nonzero
/// due count gets an EXACT-count one-shot; that count is true at fire because
/// dueCountFor(states, day) for a fixed day only changes via ratings, and
/// every rating re-plans. Days after it get COUNTLESS copy; due counts never
/// decrease over days without ratings, so countless copy never lies either.
List<ScheduledReminder> planReminders(
    Map<String, CardState> states, DateTime now) {
  if (states.isEmpty) return const [];

  // First candidate fire slot: today 8pm if still ahead, else tomorrow 8pm.
  var fireAt = DateTime(now.year, now.month, now.day, _reminderHour);
  if (!fireAt.isAfter(now)) fireAt = fireAt.add(const Duration(days: 1));

  // Walk forward to the first fire day with a nonzero due count. At 8pm the
  // study day equals the calendar day (8pm > 4am rollover).
  final fmt = DateFormat('yyyy-MM-dd');
  for (var i = 0; i < 366; i++) {
    final day = fmt.format(fireAt);
    final count = dueCountFor(states, day);
    if (count > 0) {
      return [
        ScheduledReminder(
          id: _oneShotId,
          fireAt: fireAt,
          body: count == 1
              ? '1 answer due today'
              : '$count answers due today',
          repeatsDaily: false,
        ),
        ScheduledReminder(
          id: _repeatId,
          fireAt: fireAt.add(const Duration(days: 1)),
          body: 'Your recall queue has answers due',
          repeatsDaily: true,
        ),
      ];
    }
    fireAt = fireAt.add(const Duration(days: 1));
  }
  return const [];
}

/// Thin executor around flutter_local_notifications. All logic is in
/// planReminders; this class is deliberately dumb glue.
/// ponytail: plugin calls untested (method channel); the planner carries the tests.
class NotificationService {
  NotificationService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDatabase _db;

  static const _channel = AndroidNotificationDetails(
    'daily_reminder',
    'Daily recall reminder',
    channelDescription: 'One reminder when answers are due for recall',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init({required void Function() onTapOpensQueue}) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == queuePayload) onTapOpensQueue();
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Cancel-then-schedule from a fresh plan. Callers (plan 6 wiring): after
  /// every rating, on app background, post-4am-rollover, and on app start.
  Future<void> reschedule({
    required Map<String, CardState> states,
    required DateTime now,
  }) async {
    await _plugin.cancelAll();
    if (!await reminderEnabled()) return;
    for (final r in planReminders(states, now)) {
      await _plugin.zonedSchedule(
        r.id,
        'DiploMate',
        r.body,
        tz.TZDateTime.from(r.fireAt, tz.local),
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: r.repeatsDaily ? DateTimeComponents.time : null,
        payload: queuePayload,
      );
    }
  }

  Future<bool> reminderEnabled() async {
    final row = await (_db.select(_db.localSettings)
          ..where((s) => s.key.equals('reminder_enabled')))
        .getSingleOrNull();
    return row == null || row.value == 'true'; // default On
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _db.into(_db.localSettings).insert(
          LocalSettingsCompanion.insert(
              key: 'reminder_enabled', value: enabled ? 'true' : 'false'),
          mode: InsertMode.insertOrReplace,
        );
    if (!enabled) await _plugin.cancelAll();
  }
}
