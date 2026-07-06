import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/services/study_lifecycle_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resumed fires onResumed (rollover recompute + session_start hook)', () {
    var resumed = 0;
    var paused = 0;
    final obs = StudyLifecycleObserver(
        onResumed: () => resumed++, onPaused: () => paused++);
    obs.didChangeAppLifecycleState(AppLifecycleState.resumed);
    obs.didChangeAppLifecycleState(AppLifecycleState.paused);
    obs.didChangeAppLifecycleState(AppLifecycleState.inactive); // neither
    expect(resumed, 1);
    expect(paused, 1);
  });
}
