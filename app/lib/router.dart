import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_providers.dart';
import 'ui/account/account_screen.dart';
import 'ui/bookmarks/bookmarks_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/reader/reader_screen.dart';
import 'ui/shell/app_shell.dart';
import 'ui/signin/signin_screen.dart';
import 'ui/speciality/speciality_screen.dart';
import 'ui/syllabus/syllabus_screen.dart';
import 'ui/topics/topics_screen.dart';

/// GoRouter only reruns `redirect` on navigation events, not on Riverpod
/// state changes - this bridges sessionUserProvider changes (sign-in,
/// sign-out, delete) into a re-run so live auth transitions navigate.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionUserProvider, (_, __) => notifyListeners());
  }
}

GoRouter buildRouter(Ref ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/signin',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(sessionUserProvider);
      final loc = state.matchedLocation;
      if (user == null) return loc == '/signin' ? null : '/signin';
      final changing = state.uri.queryParameters['mode'] == 'change';
      if (user.specialityId == null) {
        // Unskippable onboarding gate: every route except the gate itself
        // bounces to /speciality until a track is committed.
        return loc == '/speciality' ? null : '/speciality';
      }
      if (loc == '/signin' || (loc == '/speciality' && !changing)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: '/speciality',
          builder: (_, s) => SpecialityScreen(
              changeMode: s.uri.queryParameters['mode'] == 'change')),
      GoRoute(
          path: '/reader/queue',
          builder: (_, __) => const ReaderScreen.queue()),
      GoRoute(
          path: '/reader/:qnaId',
          builder: (_, s) => ReaderScreen.browse(
              qnaId: s.pathParameters['qnaId']!,
              topicId: s.uri.queryParameters['topic'])),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen(), routes: [
              GoRoute(path: 'bookmarks', builder: (_, __) => const BookmarksScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/syllabus', builder: (_, __) => const SyllabusScreen(), routes: [
              GoRoute(
                  path: 'topics/:chapterId',
                  builder: (_, s) =>
                      TopicsScreen(chapterId: s.pathParameters['chapterId']!)),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          ]),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>(buildRouter);
