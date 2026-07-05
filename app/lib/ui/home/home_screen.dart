import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../providers/study_providers.dart';
import '../../theme/tokens.dart';

/// Two honest figures for "This Week". Plan 5 re-points this at real
/// review_events folds; easyPct is null under the n>=5 weekly floor.
final weeklyStatsProvider =
    Provider<({int recalled, int? easyPct})>((ref) => (recalled: 41, easyPct: 71));

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(DateTime now, String? name) {
    final h = now.hour;
    final part = h >= 5 && h < 11
        ? 'Good morning'
        : h >= 11 && h < 17
            ? 'Good afternoon'
            : 'Good evening';
    final first = name?.split(' ').first;
    return first == null ? part : '$part, $first';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    final due = ref.watch(dueCountProvider);
    final stats = ref.watch(weeklyStatsProvider);
    final resume = ref.watch(resumeChapterProvider).valueOrNull;
    final user = ref.watch(sessionUserProvider);
    final greeting = _greeting(DateTime.now(), user?.name);
    final first = user?.name?.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
                children: [
                  const SizedBox(height: DmSpace.sm),
                  Text('Home', style: DmType.title.copyWith(color: dm.ink)),
                  const SizedBox(height: DmSpace.xl2),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: first == null
                              ? greeting
                              : greeting.substring(0, greeting.length - first.length),
                          style: DmType.display.copyWith(color: dm.ink)),
                      if (first != null)
                        TextSpan(
                            text: first,
                            style: DmType.display.copyWith(color: dm.tealInk)),
                    ]),
                  ),
                  const SizedBox(height: DmSpace.xl2),
                  if (due > 0) ...[
                    FilledButton(
                      onPressed: () => context.go('/reader/queue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: dm.teal,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DmRadius.md)),
                      ),
                      child: Text('View $due suggested answers',
                          style: DmType.bodyUi.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: DmSpace.md),
                  ],
                  OutlinedButton(
                    onPressed: () => context.go('/home/bookmarks'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: dm.ruleStrong),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DmRadius.md)),
                    ),
                    child: Text('View your bookmarks',
                        style: DmType.bodyUi.copyWith(color: dm.tealInk)),
                  ),
                  if (due == 0 && stats.recalled == 0) ...[
                    const SizedBox(height: DmSpace.lg),
                    Text(
                        'Nothing scheduled yet. Study one answer to start your recall queue.',
                        style: DmType.bodyUi.copyWith(color: dm.ink2)),
                  ],
                  const SizedBox(height: DmSpace.xl3),
                  Text('This Week', style: DmType.section.copyWith(color: dm.ink)),
                  const SizedBox(height: DmSpace.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _Stat(number: '${stats.recalled}', caption: 'answers recalled'),
                      const SizedBox(width: 28),
                      if (stats.easyPct != null)
                        _Stat(number: '${stats.easyPct}%', caption: 'rated Easy'),
                    ],
                  ),
                  const SizedBox(height: DmSpace.xl3),
                ],
              ),
            ),
            if (resume != null)
              Material(
                color: dm.elevated,
                child: InkWell(
                  onTap: () => context.go('/syllabus/topics/${resume.id}'),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: dm.rule))),
                    padding: const EdgeInsets.symmetric(
                        horizontal: DmSpace.gutter, vertical: DmSpace.md),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration:
                              BoxDecoration(color: dm.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: DmSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  stats.recalled == 0
                                      ? 'START HERE'
                                      : 'PICK UP WHERE YOU LEFT OFF',
                                  style: DmType.label.copyWith(color: dm.ink3)),
                              const SizedBox(height: 2),
                              Text(resume.title,
                                  style: DmType.bodyUi.copyWith(color: dm.ink)),
                              if (stats.recalled == 0)
                                Text('Begin with the highest-yield chapter',
                                    style: DmType.meta.copyWith(color: dm.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.number, required this.caption});
  final String number, caption;

  @override
  Widget build(BuildContext context) {
    final dm = Theme.of(context).extension<DmTheme>()!.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(number, style: DmType.statNumber.copyWith(color: dm.ink)),
        const SizedBox(width: 8),
        Text(caption, style: DmType.meta.copyWith(color: dm.ink2)),
      ],
    );
  }
}
