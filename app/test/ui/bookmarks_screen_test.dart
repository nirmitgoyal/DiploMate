import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fake_bookmark_repository.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/bookmarks/bookmarks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget host(FakeBookmarkRepository repo) => ProviderScope(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: dmLightTheme(), home: const BookmarksScreen()),
    );

void main() {
  testWidgets('empty state carries direction + zero crumb', (t) async {
    await t.pumpWidget(host(FakeBookmarkRepository()));
    await t.pumpAndSettle();
    expect(find.text('Nothing saved yet.'), findsOneWidget);
    expect(
        find.text('Bookmark an answer while reading and it will be kept here.'),
        findsOneWidget);
    expect(find.text('Saved · 0 questions'), findsOneWidget);
  });

  testWidgets('bookmarked QnA renders question + Chapter source row + crumb count',
      (t) async {
    final repo = FakeBookmarkRepository();
    await repo.toggle('01J0QNATAPBLOCK00000000001');
    await t.pumpWidget(host(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('transversus abdominis plane'), findsOneWidget);
    expect(find.text('Regional Anaesthesia'), findsOneWidget);
    expect(find.text('Saved · 1 question'), findsOneWidget);
  });

  testWidgets('bookmark row tap opens the reader at ?chapter=<chapterId> (no topic param)',
      (t) async {
    final repo = FakeBookmarkRepository();
    await repo.toggle('01J0QNATAPBLOCK00000000001');
    String? openedQnaId;
    String? openedChapter;
    final router = GoRouter(initialLocation: '/home/bookmarks', routes: [
      GoRoute(path: '/home/bookmarks', builder: (_, __) => const BookmarksScreen()),
      GoRoute(
          path: '/reader/:qnaId',
          builder: (_, s) {
            openedQnaId = s.pathParameters['qnaId'];
            openedChapter = s.uri.queryParameters['chapter'];
            return const SizedBox.shrink();
          }),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: dmLightTheme(), routerConfig: router),
    ));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('transversus abdominis plane'));
    await t.pumpAndSettle();

    expect(openedQnaId, '01J0QNATAPBLOCK00000000001');
    expect(openedChapter, '01J0CHAPREGIONAL0000000001');
  });
}
