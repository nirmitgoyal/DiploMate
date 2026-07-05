import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

enum TopicPipStatus { recalled, due, fresh }

/// Plan 5 re-points this at CardState folds (due = any member QnA due today,
/// recalled = all member QnAs rated at least once). Same name, same shape.
final topicPipProvider =
    Provider.family<TopicPipStatus, String>((ref, topicId) => TopicPipStatus.fresh);

/// Topics screen: fetches the chapter's content on demand when opened
/// (DESIGN.md Free-Beta chapter-tap contract - no download/lock UI, no
/// prep-percentage copy). Groups topics under their exam_theme; each row's
/// recall pip is a bare status word (never color alone).
class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key, required this.chapterId});
  final String chapterId;

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  bool _loading = true;
  bool _error = false;
  String _specName = '';
  ChapterRow? _chapter;
  List<TopicRow> _topics = const [];
  Map<String, String> _firstQna = const {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ponytail: plain initState().then() + mounted guard, matching
  // SyllabusScreen/SpecialityScreen - no FutureBuilder/reassigned-Future.
  void _fetch() {
    setState(() {
      _loading = true;
      _error = false;
    });
    final repo = ref.read(contentRepositoryProvider);
    repo.ensureChapterCached(widget.chapterId).then((_) async {
      final specs = await repo.specialities();
      final spec = specs.where((s) => s.hasContent).firstOrNull;
      final chapters = spec == null ? const <ChapterRow>[] : await repo.chapters(spec.id);
      final chapter = chapters.where((c) => c.id == widget.chapterId).firstOrNull;
      final topics = await repo.topics(widget.chapterId);
      final firstQna = <String, String>{};
      for (final t in topics) {
        final qs = await repo.qnas(t.id);
        if (qs.isNotEmpty) firstQna[t.id] = qs.first.id;
      }
      if (!mounted) return;
      setState(() {
        _specName = spec?.name ?? '';
        _chapter = chapter;
        _topics = topics;
        _firstQna = firstQna;
        _loading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
          child: _body(dm),
        ),
      ),
    );
  }

  Widget _body(DmColors dm) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error) {
      return _Retry(onRetry: _fetch);
    }
    final chapter = _chapter;
    final recalled = _topics
        .where((t) => ref.read(topicPipProvider(t.id)) == TopicPipStatus.recalled)
        .length;
    final themes = <String?, List<TopicRow>>{};
    for (final t in _topics) {
      themes.putIfAbsent(t.examTheme, () => []).add(t);
    }
    return ListView(
      children: [
        const SizedBox(height: DmSpace.sm),
        Row(children: [
          InkWell(
            onTap: () => context.go('/syllabus'),
            child: Text(_specName, style: DmType.meta.copyWith(color: dm.tealInk)),
          ),
          Text(' / ', style: DmType.meta.copyWith(color: dm.ink3)),
          Text(chapter?.title ?? '', style: DmType.meta.copyWith(color: dm.ink2)),
        ]),
        const SizedBox(height: DmSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(DmRadius.sm),
          child: LinearProgressIndicator(
            value: _topics.isEmpty ? 0 : recalled / _topics.length,
            minHeight: 4,
            backgroundColor: dm.tealSoft,
            valueColor: AlwaysStoppedAnimation(dm.teal),
          ),
        ),
        const SizedBox(height: DmSpace.lg),
        for (final entry in themes.entries) ...[
          if (entry.key != null)
            Container(
              width: double.infinity,
              color: dm.sunk,
              padding:
                  const EdgeInsets.symmetric(horizontal: DmSpace.sm, vertical: DmSpace.xs),
              child: Text(entry.key!.toUpperCase(),
                  style: DmType.label.copyWith(color: dm.ink3)),
            ),
          for (final t in entry.value) _TopicRow(topic: t, qnaId: _firstQna[t.id]),
        ],
      ],
    );
  }
}

class _TopicRow extends ConsumerWidget {
  const _TopicRow({required this.topic, required this.qnaId});
  final TopicRow topic;
  final String? qnaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = context.dm;
    return InkWell(
      onTap: qnaId == null
          ? null
          : () => context.go('/reader/$qnaId?topic=${topic.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Row(
          children: [
            Expanded(child: Text(topic.title, style: DmType.bodyUi.copyWith(color: dm.ink))),
            _Pip(status: ref.watch(topicPipProvider(topic.id))),
          ],
        ),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.status});
  final TopicPipStatus status;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    final (color, word) = switch (status) {
      TopicPipStatus.recalled => (dm.ok, 'Recalled'),
      TopicPipStatus.due => (dm.amber, 'Due'),
      TopicPipStatus.fresh => (dm.ink3, 'New'),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(word, style: DmType.meta.copyWith(color: color)),
    ]);
  }
}

/// Inline retry, filling the failed region. One string product-wide
/// (DESIGN.md D6 state 1). Copied from SyllabusScreen's _Retry - not
/// imported across screen folders (stack lock).
class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't load this - retry", style: DmType.bodyUi.copyWith(color: dm.ink2)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
