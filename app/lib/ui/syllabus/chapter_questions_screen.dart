import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/models.dart';
import '../../providers/study_providers.dart';
import '../../theme/tokens.dart';

/// Chapter question list (2026-07-14): the syllabus / resume chapter tap lands
/// HERE, not on the Reader (reverses the 2026-07-06 "one fewer tap" removal).
/// Ensures the chapter is cached, records `chapter_opened`, and lists the
/// chapter's questions; tapping a row opens the Reader in browse mode on that
/// question (`?chapter=` gives it crumb + next-in-chapter context). Breadcrumb
/// walks back up: Syllabus / <chapter>.
class ChapterQuestionsScreen extends ConsumerStatefulWidget {
  const ChapterQuestionsScreen({super.key, required this.chapterId});
  final String chapterId;

  @override
  ConsumerState<ChapterQuestionsScreen> createState() =>
      _ChapterQuestionsScreenState();
}

class _ChapterQuestionsScreenState
    extends ConsumerState<ChapterQuestionsScreen> {
  bool _loading = true;
  bool _error = false;
  bool _opened = false; // chapter_opened fired once, survives a Retry
  String? _title;
  List<QnaRow> _qnas = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ponytail: initState().then() + mounted guard, matching SyllabusScreen -
  // no FutureBuilder/reassigned-Future (that combo deadlocked pumpAndSettle
  // across back-to-back widget tests in one isolate).
  void _fetch() {
    setState(() {
      _loading = true;
      _error = false;
    });
    final repo = ref.read(contentRepositoryProvider);
    final specId = ref.read(sessionUserProvider)?.specialityId;
    () async {
      await repo.ensureChapterCached(widget.chapterId);
      // Activation event = chapter open (moved off the Reader 2026-07-14).
      // Fire once, fire-and-forget - the list must not wait on an analytics
      // write, and a Retry must not double-count.
      if (!_opened) {
        _opened = true;
        ref.read(studyRepositoryProvider).recordAppEvent(
            eventType: 'chapter_opened', contentId: widget.chapterId);
      }
      // Crumb title comes from the user's own speciality (the only place a
      // chapter tap originates); one chapters() call, not a full walk.
      final chapters =
          specId == null ? const <ChapterRow>[] : await repo.chapters(specId);
      final title =
          chapters.where((c) => c.id == widget.chapterId).firstOrNull?.title;
      final qnas = await repo.qnas(widget.chapterId);
      if (!mounted) return;
      setState(() {
        _title = title;
        _qnas = qnas;
        _loading = false;
      });
    }().catchError((_) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DmSpace.sm),
              _Crumb(title: _title),
              const SizedBox(height: DmSpace.sm),
              Expanded(child: _body(dm)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DmColors dm) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Couldn't load this - retry",
              style: DmType.bodyUi.copyWith(color: dm.ink2)),
          TextButton(onPressed: _fetch, child: const Text('Retry')),
        ]),
      );
    }
    if (_qnas.isEmpty) {
      return Center(
        child: Text('No questions in this chapter yet.',
            style: DmType.bodyUi.copyWith(color: dm.ink2)),
      );
    }
    return ListView(
      children: [
        Text(
            '${_qnas.length} ${_qnas.length == 1 ? 'question' : 'questions'}',
            style: DmType.meta.copyWith(color: dm.ink3)),
        const SizedBox(height: DmSpace.sm),
        for (final q in _qnas) _QuestionRow(qna: q),
      ],
    );
  }
}

/// Breadcrumb: Syllabus (back to the chapter list) / <chapter> (current).
/// Mirrors the Reader crumb styling (meta type, teal-ink tappable, ink2
/// current) so both surfaces read as one breadcrumb system.
class _Crumb extends StatelessWidget {
  const _Crumb({this.title});
  final String? title;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Row(children: [
      InkWell(
        onTap: () => context.go('/syllabus'),
        child:
            Text('Syllabus', style: DmType.meta.copyWith(color: dm.tealInk)),
      ),
      Text(' / ', style: DmType.meta.copyWith(color: dm.ink3)),
      Flexible(
        child: Text(title ?? 'Chapter',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DmType.meta.copyWith(color: dm.ink2)),
      ),
    ]);
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.qna});
  final QnaRow qna;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    final meta = [
      if (qna.years != null && qna.years!.isNotEmpty) qna.years!,
      if (qna.marks != null) '${qna.marks} marks',
    ].join(' · ');
    return InkWell(
      onTap: () => context.go('/reader/${qna.id}?chapter=${qna.chapterId}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qna.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DmType.bodyUi.copyWith(color: dm.ink)),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(meta, style: DmType.meta.copyWith(color: dm.ink3)),
            ],
          ],
        ),
      ),
    );
  }
}
