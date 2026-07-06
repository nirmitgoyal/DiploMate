import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'data/db/app_db.dart';
import 'data/remote/api_client.dart';
import 'data/remote/remote_providers.dart';
import 'data/remote/remote_auth_repository.dart';
import 'data/remote/secure_token_store.dart';
import 'providers/study_providers.dart';
import 'router.dart';
import 'services/study_lifecycle_observer.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One ApiClient + one on-device database, shared by every remote provider.
  final api = ApiClient(
    baseUrl: const String.fromEnvironment('API_BASE_URL'),
    tokenStore: const SecureTokenStore(),
  );
  final db = AppDatabase(driftDatabase(name: 'diplomate'));

  final container = ProviderContainer(overrides: [
    ...remoteOverrides(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
      api: api,
      google: RealGoogleSignIn(
          serverClientId:
              const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')),
    ),
    appDatabaseProvider.overrideWithValue(db),
  ]);

  // Init the SAME client before runApp (reads the stored JWT), restore the
  // session, seed sessionUserProvider - the router redirect then lands
  // Sign-in / Speciality / Home correctly.
  await api.init();
  final user = await container.read(authRepositoryProvider).restoreSession();
  container.read(sessionUserProvider.notifier).state = user;

  // Starter funnel: no auto-download. Flush pending events on app start and on
  // every backgrounding (fresh count at fire); the lifecycle observer also
  // recomputes the study day + records a session_start on resume (plan 5).
  final sync = container.read(syncServiceProvider);
  sync.flush();
  WidgetsBinding.instance.addObserver(StudyLifecycleObserver(
    onResumed: () {
      container.read(localDayProvider.notifier).recompute();
      container.read(studyRepositoryProvider).recordSessionStartIfIdle();
    },
    onPaused: sync.flush,
  ));

  // Single runApp call - Task 6 wraps this in SentryFlutter.init(appRunner: ...).
  runApp(UncontrolledProviderScope(
    container: container,
    child: const DiplomateApp(),
  ));
}

class DiplomateApp extends ConsumerWidget {
  const DiplomateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DiploMate',
      theme: dmLightTheme(),
      darkTheme: dmDarkTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
