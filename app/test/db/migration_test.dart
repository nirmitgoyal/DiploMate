import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';

import 'generated/schema.dart';

// v1 limitation, read before trusting this file as drift protection:
// A same-version verifier check (startAt(1) -> migrateAndValidate(db, 1))
// cannot detect drift between tables.dart and the frozen v1 snapshot, because
// startAt builds the DB from the snapshot and migrateAndValidate at the same
// version never runs the live onCreate. The first real drift-catching
// cross-version assertion lands when schemaVersion bumps to 2
// (startAt(1) -> migrateAndValidate(db, 2)). Until then, the second test below
// (validateDatabaseSchema on a normally-opened DB) is what actually asserts
// createAll produces the declared schema, catching a botched onCreate or a
// hand-edited app_db.g.dart.
//
// v3 (content pass, Task 2) adds two more below: a straight startAt(2) ->
// migrateAndValidate(db, 3) drift check, and a state-survival test that seeds
// STATE + old-shape CONTENT at v2 via schemaAt(2).rawDatabase before
// migrating, proving the drop-and-refetch content tables never touch STATE.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('database created at v1 matches the dumped v1 snapshot', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  // schemaVersion 2 (plan 6, Task 4): the first cross-version drift catch.
  // startAt(1) builds a real v1 DB, then migrateAndValidate(db, 2) runs the
  // live onUpgrade (addColumn sync_attempts x2) and asserts the result matches
  // the frozen v2 snapshot - proving every beta build 1 device upgrades cleanly.
  test('v1 database migrates to v2 and matches the dumped v2 snapshot',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('live onCreate produces the schema the generated code expects',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.validateDatabaseSchema();
    await db.close();
  });

  test('v2 database migrates to v3 and matches the dumped v3 snapshot',
      () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  // Amendment 15: content tables are CACHE (dropped + refetched); pending
  // review/app events, bookmarks, and settings are STATE and must survive.
  //
  // API note: `schemaAt(version)` -> InitializedSchema{ rawDatabase, newConnection() }
  // is drift's standard generated-migration seeding surface (drift docs:
  // "Testing migrations" -> "Verifying data integrity"). The repo has not used
  // it before (the existing tests only startAt + migrateAndValidate), so this
  // is the first use; `rawDatabase.execute` writes OLD-shape rows at v2 before
  // the migration runs. If the installed drift_dev version names these
  // differently, check `SchemaVerifier` in the drift_dev api/migrations.dart.
  test('v2 -> v3 keeps review/queue/bookmark state, wipes content cache',
      () async {
    final schema = await verifier.schemaAt(2);

    // Seed STATE + old-shape CONTENT directly at v2 (raw SQL - the v2 tables
    // still have topics/topic_id).
    schema.rawDatabase.execute('''
      INSERT INTO pending_review_events
        (id, content_id, rating, shown_at, revealed_at, rated_at, local_day, sync_attempts)
      VALUES ('rev1', 'QNA1', 'good', 1751760000, 1751760015, 1751760020, '2026-07-06', 0);
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO pending_app_events
        (id, event_type, content_id, occurred_at, local_day, sync_attempts)
      VALUES ('app1', 'recall_shown', 'QNA1', 1751760000, '2026-07-06', 0);
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO bookmarks (content_id, updated_at, deleted)
      VALUES ('QNA1', 1751760000, 0);
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO local_settings ("key", value) VALUES ('reminder_enabled', 'true');
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO topics (id, chapter_id, title, slug, sort_order)
      VALUES ('TOP1', 'CH1', 'Old topic', 'old-topic', 1);
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO qnas (id, topic_id, question, earns_marks, sections, sort_order)
      VALUES ('QNA1', 'TOP1', 'Old question?', '[]', '[]', 1);
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO cached_chapters (chapter_id, content_version, cached_at)
      VALUES ('CH1', 1, 1751760000);
    ''');

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);

    // STATE survives.
    final reviews = await db.select(db.pendingReviewEvents).get();
    expect(reviews.single.contentId, 'QNA1');
    final appEvents = await db.select(db.pendingAppEvents).get();
    expect(appEvents.single.id, 'app1');
    final marks = await db.select(db.bookmarks).get();
    expect(marks.single.contentId, 'QNA1');
    expect(await db.readSetting('reminder_enabled'), 'true');

    // CONTENT cache is empty and topics is gone.
    expect(await db.select(db.qnas).get(), isEmpty);
    expect(await db.select(db.cachedChapters).get(), isEmpty);
    final topicsTable = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'topics'")
        .get();
    expect(topicsTable, isEmpty);

    await db.close();
  });
}
