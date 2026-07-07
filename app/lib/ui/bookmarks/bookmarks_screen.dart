import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

class _BookmarkRowData {
  const _BookmarkRowData({required this.qna, required this.chapterTitle});
  final QnaRow qna;
  final String chapterTitle;
}

/// Joins bookmark entries (Task 14) to their QnA + Chapter titles (Task 5).
/// Fixture-scale only (one speciality's chapters) - plan 6's real content
/// repo will index qna->chapter directly server-side.
final _bookmarkRowsProvider = StreamProvider<List<_BookmarkRowData>>((ref) {
  final repo = ref.watch(contentRepositoryProvider);
  return ref.watch(bookmarkRepositoryProvider).entries().asyncMap((entries) async {
    final rows = <_BookmarkRowData>[];
    final specs = await repo.specialities();
    final withContent = specs.where((s) => s.hasContent).toList();
    final chapters = withContent.isEmpty
        ? <ChapterRow>[]
        : await repo.chapters(withContent.first.id);
    for (final e in entries) {
      final qna = await repo.qna(e.contentId);
      if (qna == null) continue;
      final chapterTitle =
          chapters.where((c) => c.id == qna.chapterId).firstOrNull?.title ?? '';
      rows.add(_BookmarkRowData(qna: qna, chapterTitle: chapterTitle));
    }
    return rows;
  });
});

/// Bookmarks screen (DESIGN.md anatomy item 8): saved-answer rows reached
/// from Home, lights the Home tab. Empty/populated crumb copy is State
/// Spec 11 verbatim.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = context.dm;
    final rows = ref.watch(_bookmarkRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmarks', style: DmType.title.copyWith(color: dm.ink)),
        backgroundColor: dm.paper,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
        child: rows.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => Center(
              child: Text("Couldn't load this - retry",
                  style: DmType.bodyUi.copyWith(color: dm.ink2))),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DmSpace.sm),
              Text(
                  'Saved · ${list.length} ${list.length == 1 ? 'question' : 'questions'}',
                  style: DmType.meta.copyWith(color: dm.ink3)),
              const SizedBox(height: DmSpace.sm),
              Expanded(
                child: list.isEmpty
                    ? const _EmptyBookmarks()
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => _BookmarkRow(row: list[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// State Spec 11 (DESIGN.md, amended 2026-07-04): exact copy, centered in
/// the list region.
class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nothing saved yet.',
              textAlign: TextAlign.center, style: DmType.section.copyWith(color: dm.ink)),
          const SizedBox(height: DmSpace.sm),
          Text('Bookmark an answer while reading and it will be kept here.',
              textAlign: TextAlign.center, style: DmType.bodyUi.copyWith(color: dm.ink2)),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({required this.row});
  final _BookmarkRowData row;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return InkWell(
      onTap: () => context.go('/reader/${row.qna.id}?chapter=${row.qna.chapterId}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.qna.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DmType.bodyUi.copyWith(color: dm.ink)),
            const SizedBox(height: 2),
            Text(row.chapterTitle, style: DmType.meta.copyWith(color: dm.ink3)),
          ],
        ),
      ),
    );
  }
}
