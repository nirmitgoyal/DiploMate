import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../theme/tokens.dart';

class ReaderView extends StatefulWidget {
  const ReaderView({
    super.key,
    required this.qna,
    required this.revealed,
    required this.onReveal,
    required this.onRate,
    this.overline,
    this.crumb = const [],
    this.trailingCrumbAction,
    this.onNextInTopic,
    this.belowAnswer,
    this.rated = false,
    this.imageBuilder,
    this.belowCrumb,
    this.sectionSpans,
    this.activeSearchSection,
  });

  final QnaRow qna;
  final bool revealed;
  final bool rated;
  final VoidCallback onReveal;
  final void Function(WireRating) onRate;
  final String? overline;
  final List<({String label, VoidCallback onTap})> crumb;
  final Widget? trailingCrumbAction;
  final VoidCallback? onNextInTopic;
  final Widget? belowAnswer;
  final Widget Function(BuildContext, ImageRow)? imageBuilder;

  /// The search bar slot, rendered under the crumb row.
  final Widget? belowCrumb;

  /// When non-null, renders a section's heading+body via this in place of
  /// plain Text (in-answer search highlighting). Task 14.
  final List<InlineSpan> Function(AnswerSection)? sectionSpans;

  /// The AnswerSection.key of the current active search match (Task 14) -
  /// scrolled into view via the same anchor mechanism as earn-row jumps
  /// whenever this changes. Null / an 'earn:' key (outline row, already
  /// visible above the fold) triggers no scroll.
  final String? activeSearchSection;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final _sectionKeys = <String, GlobalKey>{};
  final _scroll = ScrollController();

  void _jumpTo(String sectionKey) {
    final key = _sectionKeys[sectionKey];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: DmMotion.reveal, alignment: 0.05);
    }
  }

  @override
  void didUpdateWidget(ReaderView old) {
    super.didUpdateWidget(old);
    final target = widget.activeSearchSection;
    if (target != null &&
        target != old.activeSearchSection &&
        !target.startsWith('earn:')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(target));
    }
  }

  /// Heading + body for one section, either plain (default) or highlighted
  /// via [ReaderView.sectionSpans] (Task 14 search). The spans function is
  /// fed the same 'heading\nbody' string search offsets are computed
  /// against, then split at the first newline so heading/body render from
  /// that shared source and offsets stay honest.
  List<Widget> _sectionText(AnswerSection s, DmColors dm) {
    final spans = widget.sectionSpans;
    if (spans == null) {
      return [
        Text(s.heading, style: DmType.section.copyWith(color: dm.ink)),
        const SizedBox(height: DmSpace.xs),
        if (s.bodyMd.isNotEmpty)
          Text(s.bodyMd, style: DmType.body.copyWith(color: dm.ink)),
      ];
    }
    final combined = spans(s);
    final splitAt = s.heading.length;
    final headingSpans = <InlineSpan>[];
    final bodySpans = <InlineSpan>[];
    var consumed = 0;
    for (final span in combined) {
      final text = (span as TextSpan).text ?? '';
      final start = consumed;
      final end = consumed + text.length;
      consumed = end;
      if (end <= splitAt) {
        headingSpans.add(span);
      } else if (start >= splitAt + 1) {
        bodySpans.add(TextSpan(text: text, style: span.style));
      } else {
        // straddles the '\n' boundary: split this span in two.
        final headingPart = text.substring(0, (splitAt - start).clamp(0, text.length));
        final bodyStart = (splitAt + 1 - start).clamp(0, text.length);
        final bodyPart = text.substring(bodyStart);
        if (headingPart.isNotEmpty) {
          headingSpans.add(TextSpan(text: headingPart, style: span.style));
        }
        if (bodyPart.isNotEmpty) {
          bodySpans.add(TextSpan(text: bodyPart, style: span.style));
        }
      }
    }
    return [
      Text.rich(TextSpan(children: headingSpans)),
      const SizedBox(height: DmSpace.xs),
      if (s.bodyMd.isNotEmpty) Text.rich(TextSpan(children: bodySpans)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    final q = widget.qna;
    for (final s in q.sections) {
      _sectionKeys.putIfAbsent(s.key, GlobalKey.new);
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DmSpace.gutter, DmSpace.sm, DmSpace.gutter, DmSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < widget.crumb.length; i++) ...[
                          if (i > 0)
                            Text(' / ',
                                style: DmType.meta.copyWith(color: dm.ink3)),
                          i < widget.crumb.length - 1
                              ? InkWell(
                                  onTap: widget.crumb[i].onTap,
                                  child: Text(widget.crumb[i].label,
                                      style: DmType.meta
                                          .copyWith(color: dm.tealInk)))
                              : Text(widget.crumb[i].label,
                                  style: DmType.meta.copyWith(color: dm.ink2)),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailingCrumbAction != null)
                    widget.trailingCrumbAction!,
                ],
              ),
            ),
            if (widget.belowCrumb != null) widget.belowCrumb!,
            if (widget.overline != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DmSpace.gutter),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.overline!.toUpperCase(),
                      style: DmType.label.copyWith(color: dm.ink3)),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: DmReader.maxMeasure),
                        child: Padding(
                          padding: const EdgeInsets.all(DmSpace.gutter),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.question,
                                  style: DmType.body.copyWith(
                                      fontSize: 19,
                                      color: dm.ink,
                                      height: 1.45)),
                              const SizedBox(height: DmSpace.sm),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (q.years != null)
                                    Text(q.years!,
                                        style: DmType.meta
                                            .copyWith(color: dm.ink3)),
                                  if (q.years != null && q.marks != null)
                                    Text(' · ',
                                        style: DmType.meta
                                            .copyWith(color: dm.ink3)),
                                  if (q.marks != null)
                                    Text('${q.marks} marks',
                                        style: DmType.meta
                                            .copyWith(color: dm.ink3)),
                                ],
                              ),
                              const SizedBox(height: DmSpace.lg),
                              Text('What earns marks',
                                  style: DmType.label.copyWith(color: dm.ink3)),
                              const SizedBox(height: DmSpace.xs),
                              for (final e in q.earnsMarks)
                                Semantics(
                                  button: true,
                                  label: 'Jump to ${e.label}',
                                  child: InkWell(
                                    onTap: widget.revealed
                                        ? () => _jumpTo(e.sectionKey)
                                        : null,
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 48),
                                      decoration: BoxDecoration(
                                          border: Border(
                                              bottom:
                                                  BorderSide(color: dm.rule))),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text(e.label,
                                                style: DmType.bodyUi
                                                    .copyWith(color: dm.ink))),
                                        Icon(Icons.chevron_right,
                                            size: 18, color: dm.ink3),
                                      ]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!widget.revealed)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: DmReader.maxMeasure),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: DmSpace.gutter,
                                vertical: DmSpace.xl2),
                            child: Text('Outline your answer aloud or on paper',
                                style: DmType.body.copyWith(
                                    color: dm.ink2,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ),
                      )
                    else
                      AnimatedSize(
                        duration:
                            reduceMotion ? Duration.zero : DmMotion.reveal,
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: Container(
                          // Signature move: the model answer renders on white.
                          width: double.infinity,
                          color: dm.elevated,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: DmReader.maxMeasure),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: DmSpace.gutter,
                                    vertical: DmSpace.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Signature move: examiner's red margin -
                                    // one continuous rail spans the whole
                                    // answer block; per-section mark weights
                                    // sit in the margin next to their section.
                                    Stack(
                                      children: [
                                        Positioned(
                                          left: DmReader.examinerRail,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                              width: 1, color: dm.examRed),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (final s in q.sections) ...[
                                              Row(
                                                key: _sectionKeys[s.key],
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width:
                                                        DmReader.examinerIndent,
                                                    child: s.marks != null
                                                        ? Text('${s.marks}',
                                                            style: DmType.meta
                                                                .copyWith(
                                                                    color: dm
                                                                        .examRed))
                                                        : null,
                                                  ),
                                                  const SizedBox(
                                                      width: DmSpace.sm),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        ..._sectionText(s, dm),
                                                        if (s.key ==
                                                                'diagram' &&
                                                            widget.imageBuilder !=
                                                                null)
                                                          for (final img
                                                              in q.images)
                                                            widget
                                                                .imageBuilder!(
                                                                    context,
                                                                    img),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(
                                                  height: DmSpace.lg),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (!widget.rated) ...[
                                      const SizedBox(height: DmSpace.sm),
                                      Row(children: [
                                        _RateButton(
                                            word: 'Easy',
                                            icon: Icons
                                                .sentiment_satisfied_outlined,
                                            color: dm.ok,
                                            onTap: () =>
                                                widget.onRate(WireRating.good)),
                                        const SizedBox(width: DmSpace.sm),
                                        _RateButton(
                                            word: 'Medium',
                                            icon: Icons
                                                .sentiment_neutral_outlined,
                                            color: dm.amber,
                                            onTap: () =>
                                                widget.onRate(WireRating.hard)),
                                        const SizedBox(width: DmSpace.sm),
                                        _RateButton(
                                            word: 'Hard',
                                            icon: Icons
                                                .sentiment_dissatisfied_outlined,
                                            color: dm.examRed,
                                            onTap: () => widget
                                                .onRate(WireRating.again)),
                                      ]),
                                    ] else if (widget.onNextInTopic !=
                                        null) ...[
                                      OutlinedButton(
                                        onPressed: widget.onNextInTopic,
                                        style: OutlinedButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(48),
                                            side: BorderSide(
                                                color: dm.ruleStrong)),
                                        child: Text('Next in topic',
                                            style: DmType.bodyUi
                                                .copyWith(color: dm.tealInk)),
                                      ),
                                    ],
                                    if (widget.belowAnswer != null)
                                      widget.belowAnswer!,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: DmSpace.xl3),
                  ],
                ),
              ),
            ),
            if (!widget.revealed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(DmSpace.gutter),
                  child: FilledButton(
                    onPressed: widget.onReveal,
                    style: FilledButton.styleFrom(
                      backgroundColor: dm.teal,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DmRadius.md)),
                    ),
                    child: Text('Reveal model answer',
                        style: DmType.bodyUi.copyWith(color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton(
      {required this.word,
      required this.icon,
      required this.color,
      required this.onTap});
  final String word;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Rate $word',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DmRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(DmRadius.sm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(word, style: DmType.meta.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
