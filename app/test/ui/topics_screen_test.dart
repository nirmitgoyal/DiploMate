import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/topics/topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterId = '01J0CHAPAIRWAY000000000001';

Widget host({FixtureContentRepository? repo}) => ProviderScope(
      overrides: [
        if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
          theme: dmLightTheme(), home: const TopicsScreen(chapterId: _chapterId)),
    );

void main() {
  testWidgets('crumb, theme groups, topic rows with bare-word pips, no dates', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget);
    expect(find.text('Difficult airway algorithm'), findsOneWidget);
    expect(find.text('Rapid sequence induction'), findsOneWidget);
    expect(find.text('New'), findsNWidgets(2), reason: 'fixture pips default to New');
    expect(find.textContaining('in '), findsNothing, reason: 'no interval copy');
    expect(find.textContaining('day'), findsNothing, reason: 'no date copy');
  });

  testWidgets('fetch failure renders the retry state', (t) async {
    final repo = FixtureContentRepository(failChapterFetch: true);
    await t.pumpWidget(host(repo: repo));
    await t.pumpAndSettle();
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
    repo.failChapterFetch = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Difficult airway algorithm'), findsOneWidget);
  });
}
