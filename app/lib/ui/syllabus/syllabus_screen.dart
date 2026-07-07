import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../data/repos/content_repository.dart';
import '../../domain/models.dart';
import '../../theme/tokens.dart';

/// Syllabus tab: chapter rows for the user's chosen speciality (DESIGN.md
/// "Syllabus row contract"), plus the empty-track (State 9) and catalog
/// loading/error (State 10) variants. No download/offline/lock UI - the
/// feature was removed 2026-07-04; free beta has nothing to unlock.
class SyllabusScreen extends ConsumerStatefulWidget {
  const SyllabusScreen({super.key});

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  bool _loading = true;
  bool _error = false;
  bool _upgrade = false;
  SpecialityRow? _spec;
  List<ChapterRow> _chapters = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ponytail: plain initState().then() + mounted guard, matching
  // SpecialityScreen - no FutureBuilder/reassigned-Future (that combo
  // deadlocked pumpAndSettle when a second widget test ran in the same
  // isolate right after one that also awaited the asset bundle).
  void _fetch() {
    setState(() {
      _loading = true;
      _error = false;
    });
    final repo = ref.read(contentRepositoryProvider);
    final specId = ref.read(sessionUserProvider)?.specialityId;
    repo.specialities().then((specs) async {
      final spec = specs.where((s) => s.id == specId).firstOrNull;
      final chapters = (spec == null || !spec.hasContent)
          ? const <ChapterRow>[]
          : await repo.chapters(spec.id);
      if (!mounted) return;
      setState(() {
        _spec = spec;
        _chapters = chapters;
        _loading = false;
      });
    }).catchError((e) {
      if (!mounted) return;
      if (e is UpgradeRequiredException) {
        setState(() {
          _upgrade = true;
          _loading = false;
        });
        return;
      }
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
              Text('Syllabus', style: DmType.title.copyWith(color: dm.ink)),
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
    if (_upgrade) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DmSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Update DiploMate to continue',
                  style: DmType.bodyUi.copyWith(color: dm.ink)),
              const SizedBox(height: DmSpace.sm),
              Text('This version is too old for the current content format.',
                  style: DmType.meta.copyWith(color: dm.ink2),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_error) {
      return _Retry(onRetry: _fetch);
    }
    if (_chapters.isEmpty) {
      return _EmptyTrack(specialityName: _spec?.name ?? 'Your speciality');
    }
    return ListView(
      children: [
        const SizedBox(height: DmSpace.xs),
        Text(_spec?.name ?? '', style: DmType.meta.copyWith(color: dm.ink3)),
        const SizedBox(height: DmSpace.sm),
        for (final c in _chapters) _ChapterRow(chapter: c),
      ],
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter});
  final ChapterRow chapter;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    final started = chapter.recalledCount > 0;
    final fraction = started ? chapter.recalledCount / chapter.qnaCount : 0.0;
    return InkWell(
      onTap: () => context.go('/reader/chapter/${chapter.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dm.rule))),
        padding: const EdgeInsets.symmetric(vertical: DmSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chapter.title, style: DmType.bodyUi.copyWith(color: dm.ink)),
                      const SizedBox(height: 2),
                      Text('${chapter.qnaCount} questions',
                          style: DmType.meta.copyWith(color: dm.ink3)),
                    ],
                  ),
                ),
                Text('${chapter.recalledCount}/${chapter.qnaCount} recalled',
                    style: DmType.meta.copyWith(
                        color: dm.tealInk, fontFeatures: DmType.tabularNums)),
              ],
            ),
            if (started) ...[
              const SizedBox(height: DmSpace.sm),
              Semantics(
                label:
                    '${chapter.recalledCount} of ${chapter.qnaCount} questions recalled',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DmRadius.sm),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 3,
                      backgroundColor: dm.tealSoft,
                      valueColor: AlwaysStoppedAnimation(dm.teal),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// State 9 (DESIGN.md, amended 2026-07-04): first-class screen, not a
/// dialog or toast. Bottom nav stays live around this.
class _EmptyTrack extends StatelessWidget {
  const _EmptyTrack({required this.specialityName});
  final String specialityName;

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DmSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No answers here yet',
                textAlign: TextAlign.center,
                style: DmType.title.copyWith(color: dm.ink)),
            const SizedBox(height: DmSpace.sm),
            Text(
                '$specialityName answers are being written. Your pick counts - it tells us which speciality we publish next.',
                textAlign: TextAlign.center,
                style: DmType.bodyUi.copyWith(color: dm.ink2)),
            const SizedBox(height: DmSpace.sm),
            Text('You can change your speciality once in Account.',
                textAlign: TextAlign.center,
                style: DmType.meta.copyWith(color: dm.ink3)),
          ],
        ),
      ),
    );
  }
}

/// State 10 / State 1: inline retry, filling the failed region. One string
/// product-wide (DESIGN.md D6 state 1).
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
          Text("Couldn't load this - retry",
              style: DmType.bodyUi.copyWith(color: dm.ink2)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
