import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../domain/models.dart';

/// STUB - plan 5 (study-loop-srs) Task 7 REPLACES this whole file with the
/// drift-backed providers, keeping these exact public names. Screens import
/// only from this file, so the swap is invisible to the widget tree.
final dueCountProvider = Provider<int>((ref) => 12);

/// Highest-exam-weight chapter = the "Start here" funnel target (no
/// auto-download - content loads on demand when the user enters it).
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
