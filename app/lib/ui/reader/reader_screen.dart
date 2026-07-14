import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../providers/study_providers.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';
import 'answer_search.dart';
import 'diagram_viewer.dart';
import 'reader_controller.dart';
import 'reader_view.dart';

final bookmarkedIdsProvider = StreamProvider<Set<String>>(
    (ref) => ref.watch(bookmarkRepositoryProvider).bookmarkedIds());

/// Reader. Queue mode drives due-only suggestions via [ReaderController]
/// (auto-advancing recall gate); browse mode opens one QnA from Syllabus/
/// Bookmarks and rate-then-stays. Both route reveal/rate through the
/// controller so ratings persist local-first before any UI ack (D4).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen.browse({super.key, required this.qnaId, this.chapterId})
      : queueMode = false;
  const ReaderScreen.queue({super.key})
      : qnaId = null,
        chapterId = null,
        queueMode = true;

  final String? qnaId;
  final String? chapterId;
  final bool queueMode;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  ReaderController? _controller;
  QnaRow? _qna;
  List<QnaRow> _chapterQnas = const [];
  String? _chapterTitle;
  bool _rated = false;
  Object? _error;

  // Queue mode resolves each currentQnaId on demand (no up-front chapter list);
  // resolved rows are cached so an auto-advance doesn't re-fetch a seen card.
  final _qnaCache = <String, QnaRow>{};

  bool _searchOpen = false;
  final _searchController = TextEditingController();
  List<SearchMatch> _matches = const [];
  int _activeMatch = 0;

  bool get _revealed => _controller?.revealed ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.queueMode) {
      _controller = ReaderController.queue(
        repo: ref.read(studyRepositoryProvider),
        queue: ref.read(dueQueueProvider),
      )..addListener(_onController);
      _resolveCurrent();
    } else {
      _fetch();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onController);
    _searchController.dispose();
    super.dispose();
  }

  // Controller advanced (auto-advance in queue, or reveal/rate flips): pull the
  // new current card into the cache, then rebuild.
  void _onController() {
    if (widget.queueMode) _resolveCurrent();
    if (mounted) setState(() {});
  }

  /// Queue mode: fetch the controller's current QnA (on-demand, cached). A
  /// null/failed resolve routes into the same retry affordance browse uses.
  Future<void> _resolveCurrent() async {
    // Clear any stale failure up front: without this, a failed resolve on
    // card A leaves _error set, and auto-advancing to an already-cached
    // card B hits the early-return below without ever clearing it - wedging
    // the queue on the retry screen for a card that in fact loaded fine.
    if (_error != null) setState(() => _error = null);
    final id = _controller?.currentQnaId;
    if (id == null || _qnaCache.containsKey(id)) return;
    try {
      final qna = await ref.read(contentRepositoryProvider).qna(id);
      if (!mounted) return;
      setState(() {
        if (qna == null) {
          _error = StateError('qna not found');
        } else {
          _qnaCache[id] = qna;
          _error = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final repo = ref.read(contentRepositoryProvider);
      final chapterId = widget.chapterId;
      // Cache the chapter for deep-linked browse when the ?chapter= param is
      // present (chapter entry now caches via the question-list screen).
      if (chapterId != null) await repo.ensureChapterCached(chapterId);
      final chapterQnas =
          chapterId == null ? const <QnaRow>[] : await repo.qnas(chapterId);
      // Crumb title: find the chapter by id via the spec -> chapters walk.
      String? chapterTitle;
      if (chapterId != null) {
        for (final sp
            in (await repo.specialities()).where((s) => s.hasContent)) {
          for (final c in await repo.chapters(sp.id)) {
            if (c.id == chapterId) chapterTitle = c.title;
          }
        }
      }
      // Browse always opens a specific row; a stale bookmark id resolves to
      // null -> retry, not a crash.
      final qna = await repo.qna(widget.qnaId!);
      setState(() {
        _qna = qna;
        // No error but no row (stale/deleted deep link) must not fall through
        // to the loading spinner forever - route it into the same retry UI.
        _error = qna == null ? StateError('qna not found') : null;
        _chapterQnas = chapterQnas;
        _chapterTitle = chapterTitle;
        // Build the browse controller once the chapter list is known; rate/
        // reveal and "Next in chapter" route through it (rate-then-stay).
        // chapterQnaIds must contain the opened id, so fall back to [qna.id]
        // when there is no chapter context (deep-linked bookmark).
        if (qna != null) {
          _controller?.removeListener(_onController);
          _controller = ReaderController.browse(
            repo: ref.read(studyRepositoryProvider),
            qnaId: qna.id,
            chapterQnaIds: chapterQnas.isEmpty
                ? [qna.id]
                : [for (final q in chapterQnas) q.id],
          )..addListener(_onController);
        }
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  /// The card currently on screen. Queue: from the on-demand cache. Browse:
  /// from the pre-loaded chapter list, tracking the controller's current id.
  QnaRow? get _currentQna {
    final id = _controller?.currentQnaId;
    if (id == null) return widget.queueMode ? null : _qna;
    if (widget.queueMode) return _qnaCache[id];
    return _chapterQnas.firstWhere((q) => q.id == id, orElse: () => _qna!);
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _matches = const [];
      _activeMatch = 0;
    });
  }

  void _onQueryChanged(String query) {
    setState(() {
      _matches = query.isEmpty ? const [] : findMatches(_currentQna!, query);
      _activeMatch = 0;
    });
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _activeMatch = (_activeMatch + delta) % _matches.length);
    if (_activeMatch < 0) _activeMatch += _matches.length;
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    // End-of-queue completion (design F8): currentQnaId is null once complete.
    if (widget.queueMode && (_controller?.complete ?? false)) {
      return _QueueComplete(
        reviewed: _controller!.total,
        onStudyNew: () => context.go('/syllabus'),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Couldn't load this - retry",
                style: DmType.bodyUi.copyWith(color: dm.ink2)),
            TextButton(
                onPressed: widget.queueMode ? _resolveCurrent : _fetch,
                child: const Text('Retry')),
          ]),
        ),
      );
    }
    final qna = _currentQna;
    if (qna == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    final controller = _controller!;
    final online = ref.watch(isOnlineProvider);
    // Queue mode: suggestion overline + reveal/rate, auto-advancing. No crumb/
    // search/bookmark - it is a focused recall gate, not a browse surface -
    // but DESIGN.md item 13 puts the report row in BOTH states (one surface,
    // two states), so it stays wired here too.
    if (widget.queueMode) {
      return ReaderView(
        qna: qna,
        overline: 'Suggestion · ${controller.position} of ${controller.total}',
        revealed: _revealed,
        onReveal: controller.reveal,
        onRate: (r) async {
          await controller.rate(r);
          if (context.mounted) {
            showDmToast(context, '✓ Rated ${uiLabelForWire[r]} - next answer');
          }
        },
        belowAnswer: _ReportRow(
          online: online,
          onSend: (message) async {
            await ref.read(reportErrorProvider)(qna.id, message);
            if (context.mounted) showDmToast(context, '✓ Report sent - thank you');
          },
        ),
      );
    }
    final bookmarked =
        ref.watch(bookmarkedIdsProvider).valueOrNull?.contains(qna.id) ??
            false;
    return ReaderView(
      qna: qna,
      overline: 'Question ${controller.position} of ${controller.total}',
      revealed: _revealed,
      rated: _rated,
      onReveal: controller.reveal,
      onRate: (r) async {
        _closeSearch();
        await controller.rate(r);
        if (!context.mounted) return;
        setState(() => _rated = true);
        showDmToast(context, '✓ Rated ${uiLabelForWire[r]} - next answer');
      },
      onNextInChapter: controller.hasNextInChapter
          ? () {
              controller.nextInChapter();
              setState(() => _rated = false);
            }
          : null,
      // Breadcrumb Chapter / Question N: the chapter crumb goes UP to the
      // question list; the trailing position crumb is the you-are-here marker
      // (ReaderView renders the last crumb non-tappable). Absent for a
      // deep-linked bookmark with no chapter context.
      crumb: [
        if (_chapterTitle != null && widget.chapterId != null) ...[
          (
            label: _chapterTitle!,
            onTap: () => context.go('/reader/chapter/${widget.chapterId}'),
          ),
          (label: 'Question ${controller.position}', onTap: () {}),
        ],
      ],
      trailingCrumbAction: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_revealed)
          IconButton(
            tooltip: 'Search this answer',
            icon: Icon(Icons.search, color: dm.ink2),
            onPressed: () => setState(() => _searchOpen = !_searchOpen),
          ),
        Semantics(
          toggled: bookmarked,
          child: IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: bookmarked ? dm.teal : dm.ink2),
            onPressed: () async {
              await ref.read(bookmarkRepositoryProvider).toggle(qna.id);
              if (context.mounted) {
                showDmToast(
                    context, bookmarked ? 'Bookmark removed' : '✓ Bookmarked');
              }
            },
          ),
        ),
      ]),
      belowCrumb: _searchOpen
          ? _SearchBar(
              controller: _searchController,
              matchCount: _matches.length,
              activeIndex: _activeMatch,
              onChanged: _onQueryChanged,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onClose: _closeSearch,
            )
          : null,
      sectionSpans: _searchOpen
          ? (s) => highlightSpans(
                text: '${s.heading}\n${s.bodyMd}',
                sectionKey: s.key,
                matches: _matches,
                activeIndex: _activeMatch,
                base: DmType.body.copyWith(color: dm.ink),
                highlight: dm.tealSoft,
                activeHighlight: dm.amberSoft,
              )
          : null,
      activeSearchSection:
          _searchOpen && _matches.isNotEmpty ? _matches[_activeMatch].sectionKey : null,
      belowAnswer: _ReportRow(
        online: online,
        onSend: (message) async {
          await ref.read(reportErrorProvider)(qna.id, message);
          if (context.mounted) showDmToast(context, '✓ Report sent - thank you');
        },
      ),
      imageBuilder: (context, img) => DiagramPlate(
        image: img,
        bytesLoader: () => ref.read(contentRepositoryProvider).imageBytes(img.id),
      ),
    );
  }
}

/// Design F8: after the last due answer the queue shows a completion state,
/// not a bounce. Ghost CTA routes to Syllabus ("study a new answer").
class _QueueComplete extends StatelessWidget {
  const _QueueComplete({required this.reviewed, required this.onStudyNew});
  final int reviewed;
  final VoidCallback onStudyNew;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DmSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "Today's recall is complete. $reviewed reviewed; "
                    'next due tomorrow.',
                    textAlign: TextAlign.center,
                    style: DmType.body.copyWith(color: dm.ink)),
                const SizedBox(height: DmSpace.lg),
                OutlinedButton(
                  onPressed: onStudyNew,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: dm.ruleStrong)),
                  child: Text('Study a new answer',
                      style: DmType.bodyUi.copyWith(color: dm.tealInk)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.matchCount,
    required this.activeIndex,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final int matchCount;
  final int activeIndex;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DmSpace.gutter, vertical: DmSpace.xs),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: DmType.bodyUi.copyWith(color: dm.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search...',
              hintStyle: DmType.bodyUi.copyWith(color: dm.ink3),
            ),
          ),
        ),
        const SizedBox(width: DmSpace.sm),
        Text(matchCount == 0 ? '0/0' : '${activeIndex + 1}/$matchCount',
            style: DmType.meta.copyWith(color: dm.ink3)),
        IconButton(
          tooltip: 'Previous match',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: matchCount == 0 ? null : onPrev,
        ),
        IconButton(
          tooltip: 'Next match',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: matchCount == 0 ? null : onNext,
        ),
        IconButton(
          tooltip: 'Close search',
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ]),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.online, required this.onSend});
  final bool online;
  final Future<void> Function(String message) onSend;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return InkWell(
      onTap: !online
          ? null
          : () async {
              final controller = TextEditingController();
              final send = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Report an answer error'),
                  content: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: "What's wrong? (optional)"),
                    maxLines: 3,
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Send')),
                  ],
                ),
              );
              if (send == true) await onSend(controller.text.trim());
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(top: DmSpace.lg),
        child: Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 16, color: dm.ink3.withValues(alpha: online ? 1 : 0.5)),
            const SizedBox(width: DmSpace.xs),
            Text('Report an answer error',
                style: DmType.meta.copyWith(
                    color: dm.ink3.withValues(alpha: online ? 1 : 0.5))),
            const Spacer(),
            if (!online)
              Flexible(
                child: Text('Connect to the internet to report an error.',
                    textAlign: TextAlign.right,
                    style: DmType.meta.copyWith(color: dm.ink3)),
              ),
          ],
        ),
      ),
    );
  }
}
