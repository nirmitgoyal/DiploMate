import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_db.g.dart';

@DriftDatabase(tables: [
  Specialities,
  Chapters,
  Topics,
  Qnas,
  Images,
  ImageBlobs,
  PendingReviewEvents,
  PendingAppEvents,
  Bookmarks,
  CachedChapters,
  LocalSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // schemaVersion 1 = beta build 1. Future versions add stepwise
          // migrations here; test/db/migration_test.dart verifies each path.
        },
      );
}
