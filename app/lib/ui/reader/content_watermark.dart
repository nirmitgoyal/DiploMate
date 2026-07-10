import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../theme/tokens.dart';

/// Deterrence overlay (capture-protection spec 2026-07-10). Screenshot
/// BLOCKING is native (FLAG_SECURE / iOS secure layer); this covers the
/// analog hole: an external-camera photo of the screen carries the signed-in
/// user's email, so a leak identifies the leaking account.
///
/// Must be a direct child of a [Stack] (it is a [Positioned.fill]).
class ContentWatermark extends ConsumerWidget {
  const ContentWatermark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fallback keeps the reader usable if the session is ever null here;
    // the watermark degrades, reading never blocks.
    final text = ref.watch(sessionUserProvider)?.email ?? 'DiploMate';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          // Isolates the watermark's paint layer so a sibling in the Stack
          // (the scrolling reader content) invalidating its own layer does
          // not force this CustomPaint to re-run TextPainter layout.
          child: RepaintBoundary(
            child: CustomPaint(
              painter: WatermarkPainter(
                text: text,
                // Whisper-faint: body contrast must stay >= 4.5:1 (DESIGN.md).
                color: context.dm.ink.withValues(alpha: dark ? 0.07 : 0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a content surface with the watermark overlay. StackFit.expand keeps
/// the child filling exactly the space it filled before wrapping.
class WatermarkedContent extends StatelessWidget {
  const WatermarkedContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [child, const ContentWatermark()],
      );
}

class WatermarkPainter extends CustomPainter {
  WatermarkPainter({required this.text, required this.color});

  final String text;
  final Color color;

  static const double _hSpacing = 180;
  static const double _vSpacing = 120;
  static const double _angle = -30 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      // DmType.meta verbatim: the type scale is fixed (DESIGN.md law).
      text: TextSpan(text: text, style: DmType.meta.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.rotate(_angle);
    // Rotated corners extend past (0,0)..(w,h) in rotated coordinates;
    // overscan by the bounding diagonal so tiles reach every corner.
    final diag = size.width + size.height;
    var row = 0;
    for (var y = -diag; y < diag; y += _vSpacing) {
      // ponytail: half-step stagger on odd rows so a cropped photo still
      // catches at least one full email.
      final xOffset = row.isOdd ? _hSpacing / 2 : 0.0;
      for (var x = -diag; x < diag; x += _hSpacing) {
        tp.paint(canvas, Offset(x + xOffset, y));
      }
      row++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WatermarkPainter old) =>
      old.text != text || old.color != color;
}
