import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/home/home_screen.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget host(Widget child,
        {double width = 320,
        double height = 640,
        double scale = 1.0,
        List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [sessionUserProvider.overrideWith((ref) => _user), ...overrides],
      child: MaterialApp(
        theme: dmLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );

void main() {
  testWidgets('Home survives 320dp compact width without overflow', (t) async {
    await t.pumpWidget(host(const HomeScreen(),
        overrides: [dueCountProvider.overrideWithValue(12)]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Home survives textScale 1.3', (t) async {
    await t.pumpWidget(host(const HomeScreen(),
        scale: 1.3, overrides: [dueCountProvider.overrideWithValue(12)]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Reader survives short landscape (640x320) at textScale 1.3', (t) async {
    await t.pumpWidget(host(
        const ReaderScreen.browse(
            qnaId: '01J0QNATAPBLOCK00000000001',
            topicId: '01J0TOPICTAPBLOCK000000001'),
        width: 640, height: 320, scale: 1.3));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Reader answer measure is capped on 600dp+ (centered max-width)', (t) async {
    await t.pumpWidget(host(
        const ReaderScreen.browse(
            qnaId: '01J0QNATAPBLOCK00000000001',
            topicId: '01J0TOPICTAPBLOCK000000001'),
        width: 800, height: 1000));
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    final answer = find.textContaining('fascial plane block');
    expect(t.getSize(answer).width, lessThanOrEqualTo(620),
        reason: 'never full-bleed 17px serif across a tablet width');
  });

  // Flagged gap: Home's pinned resume row is emergent (not previously
  // widget-tested for its own tap-target size or day-zero overline copy).
  testWidgets('Home resume row is a >=48dp target and shows START HERE at day zero',
      (t) async {
    await t.pumpWidget(host(const HomeScreen(), overrides: [
      dueCountProvider.overrideWithValue(0),
      weeklyStatsProvider.overrideWithValue((recalled: 0, easyPct: null)),
    ]));
    await t.pumpAndSettle();
    expect(find.text('START HERE'), findsOneWidget);
    final row = find.ancestor(
        of: find.text('START HERE'), matching: find.byType(InkWell));
    expect(t.getSize(row).height, greaterThanOrEqualTo(48));
  });
}
