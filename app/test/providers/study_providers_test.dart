import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/providers/study_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(DateTime Function() clock) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      appDatabaseProvider
          .overrideWithValue(AppDatabase(NativeDatabase.memory())),
    ]);
    addTearDown(() {
      container.read(appDatabaseProvider).close();
      container.dispose();
    });
    return container;
  }

  test('localDayProvider honors the 4am rule at build', () {
    final c = makeContainer(() => DateTime(2026, 7, 4, 3, 30));
    expect(c.read(localDayProvider), '2026-07-03');
  });

  test('4am rollover while foregrounded: timer recomputes the day and the '
      'due queue without restart', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 4, 3, 59);
      final c = makeContainer(() => now);

      // Card rated 'again' on the (pre-4am) day 2026-07-03: due 2026-07-03.
      // Before rollover it is due (overdue path); we assert on the DAY change.
      expect(c.read(localDayProvider), '2026-07-03');

      now = DateTime(2026, 7, 4, 4, 0, 30);
      async.elapse(const Duration(minutes: 2)); // fires the armed 4am timer
      expect(c.read(localDayProvider), '2026-07-04');
    });
  });

  test('recompute() on resume picks up a day change without the timer', () {
    var now = DateTime(2026, 7, 4, 3, 0);
    final c = makeContainer(() => now);
    expect(c.read(localDayProvider), '2026-07-03');
    now = DateTime(2026, 7, 4, 11, 0); // phone slept through 4am
    c.read(localDayProvider.notifier).recompute();
    expect(c.read(localDayProvider), '2026-07-04');
  });

  test('dueQueueProvider and dueCountProvider fold events into a due-only queue',
      () async {
    var now = DateTime(2026, 7, 4, 10, 0);
    final c = makeContainer(() => now);
    final repo = c.read(studyRepositoryProvider);

    // Q1 rated 'again' today -> due today (back of queue).
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.again,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    // Q2 rated 'good' today -> due tomorrow (not in today's queue).
    await repo.recordRating(
        qnaId: 'Q2',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));

    // Let the drift watch stream deliver.
    await c.read(reviewEventsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(dueQueueProvider), ['Q1']);
    expect(c.read(dueCountProvider), 1);
  });
}
