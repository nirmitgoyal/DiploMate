import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';
import 'answer_search.dart';
import 'diagram_viewer.dart';
import 'reader_view.dart';

final bookmarkedIdsProvider = StreamProvider<Set<String>>(
    (ref) => ref.watch(bookmarkRepositoryProvider).bookmarkedIds());

/// Browse-mode Reader. Plan 5 Task 8 replaces the fixture state below with
/// its ReaderController binding (same ReaderView API); the route stays.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen.browse({super.key, required this.qnaId, this.topicId})
      : queueMode = false;
  const ReaderScreen.queuePlaceholder({super.key})
      : qnaId = null,
        topicId = null,
        queueMode = true;

  final String? qnaId;
  final String? topicId;
  final bool queueMode;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  QnaRow? _qna;
  List<QnaRow> _topicQnas = const [];
  String? _topicTitle;
  String? _chapterTitle;
  String? _chapterId;
  bool _revealed = false;
  bool _rated = false;
  Object? _error;

  bool _searchOpen = false;
  final _searchController = TextEditingController();
  List<SearchMatch> _matches = const [];
  int _activeMatch = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.queueMode) _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final repo = ref.read(contentRepositoryProvider);
      final qna = await repo.qna(widget.qnaId!);
      final topicQnas = widget.topicId == null
          ? <QnaRow>[]
          : await repo.qnas(widget.topicId!);
      String? topicTitle, chapterTitle, chapterId;
      if (widget.topicId != null) {
        // repo.topics() is keyed by chapterId, not topicId, so the ancestor
        // walk scans every chapter's topics for a match (fixture-sized data).
        final specialities = await repo.specialities();
        for (final sp in specialities.where((s) => s.hasContent)) {
          for (final c in await repo.chapters(sp.id)) {
            for (final t in await repo.topics(c.id)) {
              if (t.id == widget.topicId) {
                topicTitle = t.title;
                chapterId = t.chapterId;
                chapterTitle = c.title;
              }
            }
          }
        }
      }
      setState(() {
        _qna = qna;
        // A fetch that completes with no error but no qna (id not found -
        // e.g. a stale/deleted deep-linked bookmark) must not fall through
        // to the loading spinner forever - route it into the same retry UI.
        _error = qna == null ? StateError('qna not found') : null;
        _topicQnas = topicQnas;
        _topicTitle = topicTitle;
        _chapterTitle = chapterTitle;
        _chapterId = chapterId;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  QnaRow? get _next {
    final i = _topicQnas.indexWhere((q) => q.id == _qna?.id);
    return i >= 0 && i + 1 < _topicQnas.length ? _topicQnas[i + 1] : null;
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
      _matches = query.isEmpty ? const [] : findMatches(_qna!, query);
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
    if (widget.queueMode) {
      return Scaffold(
        body: Center(
            child: Text('Recall queue arrives with the study loop.',
                style: DmType.bodyUi.copyWith(color: dm.ink2))),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Couldn't load this - retry",
                style: DmType.bodyUi.copyWith(color: dm.ink2)),
            TextButton(onPressed: _fetch, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final qna = _qna;
    if (qna == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    final bookmarked =
        ref.watch(bookmarkedIdsProvider).valueOrNull?.contains(qna.id) ??
            false;
    final online = ref.watch(isOnlineProvider);
    return ReaderView(
      qna: qna,
      revealed: _revealed,
      rated: _rated,
      onReveal: () => setState(() => _revealed = true),
      onRate: (r) {
        setState(() => _rated = true);
        _closeSearch();
        showDmToast(context, '✓ Rated ${uiLabelForWire[r]} · next answer');
      },
      onNextInTopic: _next == null
          ? null
          : () => context.go('/reader/${_next!.id}?topic=${widget.topicId}'),
      crumb: [
        if (_chapterTitle != null)
          (
            label: _chapterTitle!,
            onTap: () => context.go('/syllabus/topics/$_chapterId'),
          ),
        if (_topicTitle != null) (label: _topicTitle!, onTap: () {}),
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
