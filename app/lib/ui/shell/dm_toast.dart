import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/tokens.dart';

/// Transient ack (DESIGN.md: feedback, not content; a named no-cards
/// exception). 1500ms hold, bottom-center, announced to TalkBack.
void showDmToast(BuildContext context, String message) {
  // ignore: deprecated_member_use
  SemanticsService.announce(message, TextDirection.ltr);
  final overlay = Overlay.of(context);
  final dm = Theme.of(context).extension<DmTheme>()!.colors;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: DmSpace.gutter,
      right: DmSpace.gutter,
      bottom: 96,
      child: IgnorePointer(
        child: Material(
          color: dm.elevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DmRadius.sm),
            side: BorderSide(color: dm.ruleStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: DmSpace.lg, vertical: DmSpace.md),
            child: Text(message,
                textAlign: TextAlign.center,
                style: DmType.bodyUi.copyWith(color: dm.ink)),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(DmMotion.toastHold, entry.remove);
}
