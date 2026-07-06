import 'package:flutter/widgets.dart';

/// One lifecycle hook for the study loop. Plan 6 registers it in main.dart:
///   onResumed: localDayNotifier.recompute() + studyRepository.recordSessionStartIfIdle()
///   onPaused:  notificationService.reschedule(...)   (fresh count at fire, ENG-T11)
class StudyLifecycleObserver extends WidgetsBindingObserver {
  StudyLifecycleObserver({required this.onResumed, required this.onPaused});

  final void Function() onResumed;
  final void Function() onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
    if (state == AppLifecycleState.paused) onPaused();
  }
}
