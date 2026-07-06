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
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('database created at v1 matches the dumped v1 snapshot', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  // When schemaVersion bumps to 2: add
  //   startAt(1) -> migrateAndValidate(db, 2)
  // so every beta build 1 device has a proven upgrade path.

  test('live onCreate produces the schema the generated code expects',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.validateDatabaseSchema();
    await db.close();
  });
}
