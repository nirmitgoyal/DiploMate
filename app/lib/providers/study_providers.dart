import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../data/db/app_db.dart';
import '../data/repos/study_repository.dart';
import '../domain/local_day.dart';
import '../domain/models.dart';
import '../domain/scheduler/leitner.dart';

/// Injectable clock; tests override, production uses DateTime.now.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Plan 6 overrides this in main.dart with the real on-device database
/// (AppDatabase(driftDatabase(name: 'diplomate'))). The in-memory default
/// keeps widget tests and previews self-contained.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

final studyRepositoryProvider = Provider<StudyRepository>((ref) =>
    StudyRepository(ref.watch(appDatabaseProvider),
        now: ref.watch(clockProvider)));

/// Current study day ("YYYY-MM-DD", 4am rollover). Recomputes via an armed
/// timer at the next 4am (foregrounded rollover, eng E4) and via
/// recompute() on app resume (Task 9 lifecycle observer).
final localDayProvider =
    NotifierProvider<LocalDayNotifier, String>(LocalDayNotifier.new);

class LocalDayNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    _armTimer();
    return localDay(ref.read(clockProvider)());
  }

  void recompute() {
    final day = localDay(ref.read(clockProvider)());
    if (day != state) state = day;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    final now = ref.read(clockProvider)();
    final today4am = DateTime(now.year, now.month, now.day, 4);
    final next4am =
        now.isBefore(today4am) ? today4am : today4am.add(const Duration(days: 1));
    _timer = Timer(next4am.difference(now) + const Duration(seconds: 1),
        recompute);
  }
}

final reviewEventsProvider = StreamProvider<List<ReviewEvent>>(
    (ref) => ref.watch(studyRepositoryProvider).watchReviewEvents());

final cardStatesProvider = Provider<Map<String, CardState>>((ref) =>
    foldAll(ref.watch(reviewEventsProvider).valueOrNull ?? const []));

/// Due-only queue for today (D10 order). Reader queue mode consumes this;
/// the notification deep-link opens Reader at its first element.
final dueQueueProvider = Provider<List<String>>((ref) =>
    buildQueue(ref.watch(cardStatesProvider), ref.watch(localDayProvider)));

/// Home primary CTA count: "View N suggested answers" (hidden at N=0).
final dueCountProvider = Provider<int>((ref) => ref.watch(dueQueueProvider).length);

/// PRESERVED from plan 4's study_providers stub (consumed by home_screen.dart's
/// day-zero resume slot - dropping it breaks Home). Highest-exam-weight chapter
/// is the "Start here" funnel target; content loads on demand when the user
/// enters it (no auto-download).
final resumeChapterProvider = FutureProvider<ChapterRow?>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final specs = await repo.specialities();
  final withContent = specs.where((s) => s.hasContent).toList();
  if (withContent.isEmpty) return null;
  final chapters = await repo.chapters(withContent.first.id);
  if (chapters.isEmpty) return null;
  chapters.sort((a, b) => b.examWeight.compareTo(a.examWeight));
  return chapters.first;
});
