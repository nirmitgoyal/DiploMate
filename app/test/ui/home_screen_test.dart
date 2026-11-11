import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya Sharma', photoUrl: null,
    specialityId: '01J0SPECANAES0000000000001', specialityChangeCount: 0);

Widget host({int due = 12, List<ReviewEvent> reviews = const []}) => ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => _user),
        dueCountProvider.overrideWithValue(due),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 10, 12)),
        reviewEventsProvider.overrideWith((ref) => Stream.value(reviews)),
      ],
      child: MaterialApp(theme: dmLightTheme(), home: const HomeScreen()),
    );

void main() {
  testWidgets('greeting + suggested CTA + ghost CTA + This Week + pinned resume', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('Ananya'), findsOneWidget);
    expect(find.text('View 12 suggested answers'), findsOneWidget);
    expect(find.text('View your bookmarks'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('answers recalled'), findsOneWidget);
    expect(find.text('rated Easy'), findsNothing);
    expect(find.text('START HERE'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget, reason: 'resume/funnel row');
  });

  testWidgets('N=0 hides the primary CTA entirely and shows day-zero direction', (t) async {
    await t.pumpWidget(host(due: 0));
    await t.pumpAndSettle();
    expect(find.textContaining('suggested answers'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is FilledButton && w.onPressed == null),
        findsNothing, reason: 'no disabled ghost-of-a-button');
    expect(find.text('Nothing scheduled yet. Study one answer to start your recall queue.'),
        findsOneWidget);
  });

  testWidgets('percent stat suppressed below the n>=5 floor', (t) async {
    await t.pumpWidget(host(reviews: [_review(9, 'good'), _review(8, 'hard'), _review(2, 'good')]));
    await t.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('weekly percentage uses only ratings from the last seven days', (t) async {
    await t.pumpWidget(host(reviews: [
      _review(9, 'good'), _review(8, 'good'), _review(7, 'good'),
      _review(6, 'hard'), _review(5, 'again'), _review(2, 'good'),
    ]));
    await t.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('never renders a streak', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('streak'), findsNothing);
  });
}

ReviewEvent _review(int day, String rating) {
  final time = DateTime(2026, 7, day, 12);
  return ReviewEvent(
      id: 'review-$day', contentId: 'q-$day', rating: rating,
      shownAt: time, revealedAt: time, ratedAt: time,
      localDay: '2026-07-${day.toString().padLeft(2, '0')}');
}
