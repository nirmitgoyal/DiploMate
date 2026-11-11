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

/// Cached questions have the chapter association needed to count each
/// rated question once. Progress never triggers a chapter download.
final recalledByChapterProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final recalled = ref.watch(cardStatesProvider);
  final counts = <String, int>{};
  for (final id in recalled.keys) {
    final question = await repo.qna(id);
    if (question != null) {
      counts.update(question.chapterId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return counts;
});

/// Resume the most recently rated question in this track. Without history,
/// direct the user to the highest exam weight chapter.
final resumeChapterProvider =
    FutureProvider<({ChapterRow chapter, int? questionIndex})?>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final specId =
      ref.watch(sessionUserProvider.select((user) => user?.specialityId));
  final reviews = ref.watch(reviewEventsProvider).valueOrNull ?? const [];
  if (specId == null) return null;
  final chapters = await repo.chapters(specId);
  if (chapters.isEmpty) return null;
  final byId = {for (final chapter in chapters) chapter.id: chapter};
  for (final review in reviews.reversed) {
    final question = await repo.qna(review.contentId);
    if (question == null) continue;
    final chapter = byId[question.chapterId];
    if (chapter == null) continue;
    final questions = await repo.qnas(chapter.id);
    final index = questions.indexWhere((q) => q.id == question.id);
    if (index >= 0) return (chapter: chapter, questionIndex: index);
  }
  final highest = chapters.reduce((a, b) => a.examWeight >= b.examWeight ? a : b);
  return (chapter: highest, questionIndex: null);
});
