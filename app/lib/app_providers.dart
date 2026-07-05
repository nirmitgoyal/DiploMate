import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/fixtures/fake_auth_repository.dart';
import 'data/fixtures/fake_sync_service.dart';
import 'data/fixtures/fixture_content_repository.dart';
import 'data/repos/auth_repository.dart';
import 'data/repos/content_repository.dart';
import 'services/sync_service.dart';

/// App-level seams. Plan 6 overrides all three with real implementations
/// (dio + drift + google_sign_in) in main.dart; the widget tree never changes.
final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => FixtureContentRepository());
final authRepositoryProvider = Provider<AuthRepository>((ref) => FakeAuthRepository());
final syncServiceProvider = Provider<SyncService>((ref) => FakeSyncService());
final sessionUserProvider = StateProvider<SessionUser?>((ref) => null);
