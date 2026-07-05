import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';
import '../shell/dm_toast.dart';
import 'reader_view.dart';

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

  @override
  void initState() {
    super.initState();
    if (!widget.queueMode) _fetch();
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
    return ReaderView(
      qna: qna,
      revealed: _revealed,
      rated: _rated,
      onReveal: () => setState(() => _revealed = true),
      onRate: (r) {
        setState(() => _rated = true);
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
    );
  }
}
