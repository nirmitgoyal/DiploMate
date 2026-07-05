# Study Loop + SRS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build DiploMate's local-first study loop: the drift database (schemaVersion 1 + migration-test harness), the 4am local-day rule, the D10 Leitner scheduler with property tests, event writers that persist every rating before the UI acknowledges it, the due-queue providers feeding Home and Reader, Reader queue/browse mode logic with a debounced rating tray, and the daily local notification with fresh-at-fire count and queue deep-link.

**Architecture:** Pure-Dart domain core (local_day, Leitner fold, queue builder, notification planner) with zero Flutter dependencies, tested exhaustively including hand-rolled generative property loops. A drift AppDatabase mirrors the Postgres content shape and holds pending event tables that plan 6's SyncService drains. Riverpod providers fold review events into card states and expose the due queue; a ChangeNotifier ReaderController drives queue/browse modes; a thin NotificationService executes plans produced by the pure planner.

**Tech Stack:** Flutter + Riverpod + drift (drift_flutter, drift_dev schema tooling) + flutter_local_notifications + timezone + intl + uuid. Tests: flutter_test + drift NativeDatabase.memory() + fake_async + hand-rolled seeded generative loops (no glados dependency).

## Global Constraints

Copied from the shared interface contract (2026-07-04, no-downloads revision). Every task's requirements implicitly include this section.

- NEVER use em-dashes or en-dashes in any file, code, comment, UI copy, or doc; plain hyphens only (user convention). The middle dot in "Suggestion · 3 of 12" is a middle dot, not a dash - it is allowed.
- NO offline Downloads feature (founder, 2026-07-04 evening): no download states/rows/copy, no remove-download, no storage UI, no offline promises. Content on demand + transparent cache only. Do not build DownloadService. No `pack_download_*` events anywhere.
- FREE BETA (PG3): no locks, no paywall sheet, no purchase language anywhere in the beta UI.
- Wire rating enum: `'again' | 'hard' | 'good'`. UI labels (display only): again = "Hard" (red --exam-red, frown face), hard = "Medium" (amber, meh face), good = "Easy" (green --ok, smile face). Tray order left-to-right: Easy - Medium - Hard. NO interval/date copy in UI; NO done/due counter; toast = "Rated <tier> - next answer". Enum ownership: sql/ DDL (`sql/0003_users_events.sql`); the Dart constants carry a comment pointing at the owning DDL file.
- event_type enum: `'topic_opened' | 'recall_shown' | 'recall_revealed' | 'recall_rated' | 'session_start'` (session_start = 30-min inactivity window; recall_revealed carries hidden_ms).
- D4: rating event persisted to drift BEFORE the UI acknowledges the rating. Losing network never loses a rating. Sync idempotency via client-generated UUID id.
- D10 Leitner math EXACTLY: again -> B1, due same local day, back of queue; hard -> stay bucket, due +2 days; good -> B1->B2 (interval 1d), B2->B3 (interval 3d), B3 stays (interval = previous interval x 2). New QnA enters B1 on first rating. Day rollover 4am local. Queue order: overdue first -> lowest bucket -> oldest last-rated. Queue = due-only (dueLocalDay <= today), NO new-card injection in v1.
- Recall validity (hidden >= 10s AND rated) is metric-side ONLY (SQL pack, plan 2). NO UI countdown, no hard lock, no elapsed indicator. The client's only job is carrying accurate hidden_ms.
- D19: one daily local notification, "N answers due today" copy, opt-out in Account (default On, 8:00 pm). Count must be fresh at fire (re-schedule on background/rating/post-rollover) or copy must be countless. Tap deep-links into Reader queue mode at the first due QnA. Labels don't lie.
- User copy says "answers", never "QnAs". No day-streaks. No cards. Never expose "checksum/version/cache" in user copy.
- Drift tables mirror the Postgres content shape (same column names, snake_case); image bytes live in a separate `image_blobs` drift table keyed by image id; plus `pending_review_events`, `pending_app_events`, `bookmarks` (local LWW copy), `cached_chapters` (chapter_id, content_version, cached_at).
- Stack locks: Flutter + Riverpod + drift + go_router + google_sign_in + dio + sentry_flutter + flutter_secure_storage + flutter_local_notifications. Nothing else without cause.
- A11y build floor: 48dp targets, >=4.5:1 contrast, icon/shape + label differentiation on rating tiers (never color alone), reduced-motion honored. Motion budget: reveal/rating-ack/queue-transition only, 150-220ms.
- TDD: every task = failing test -> minimal code -> pass -> commit. Conventional-commit messages.
- All commands in this plan run from the repo's `app/` directory (the Flutter project created by plan 4, package name `diplomate`) unless stated otherwise.

Resolved ambiguities (chosen by this plan, stated so neighbors can rely on them):

- `pending_review_events` / `pending_app_events` KEEP rows after sync with a nullable `synced_at` column ("pending" = `synced_at IS NULL`). The Leitner fold needs the full local event log; plan 6's SyncService selects `synced_at IS NULL`, pushes, then sets `synced_at` - it never deletes.
- A small `local_settings(key TEXT PK, value TEXT)` drift table exists for client-only flags (today: `reminder_enabled`). It is not in the wire contract; it never syncs.
- Event writers live in `lib/data/repos/study_repository.dart` (class `StudyRepository`); providers live in `lib/providers/study_providers.dart`. The contract does not name these two files; every other path is contract-verbatim.
- Notification deep-link is delivered as a callback (`onTapOpensQueue`); plan 6 wires it to the router (Reader queue mode starts at `dueQueueProvider.first`), so route strings stay owned by plan 4/6.

---

### Task 1: Drift schema v1 (tables + AppDatabase)

**Files:**

- Modify: `app/pubspec.yaml`
- Create: `app/lib/data/db/tables.dart`
- Create: `app/lib/data/db/app_db.dart`
- Test: `app/test/db/app_db_test.dart`

**Interfaces:**

- Consumes: the Flutter project scaffold from plan 4 (`app/` exists, `flutter test` runs). Nothing else.
- Produces: `class AppDatabase extends _$AppDatabase` in `lib/data/db/app_db.dart` with `AppDatabase(super.e)` constructor and `schemaVersion => 1`. Tables (drift class name -> SQL name): `Specialities -> specialities`, `Chapters -> chapters`, `Topics -> topics`, `Qnas -> qnas`, `Images -> images` (metadata only, no bytes), `ImageBlobs -> image_blobs`, `PendingReviewEvents -> pending_review_events`, `PendingAppEvents -> pending_app_events`, `Bookmarks -> bookmarks`, `CachedChapters -> cached_chapters`, `LocalSettings -> local_settings`. Tasks 6-9 and plans 4/6 open it as `AppDatabase(driftDatabase(name: 'diplomate'))` in production and `AppDatabase(NativeDatabase.memory())` in tests.

- [ ] **Step 1: Add dependencies to `app/pubspec.yaml`**

Add these entries (keep existing entries from plan 4 untouched; skip any line already present):

```yaml
dependencies:
  drift: ^2.20.0
  drift_flutter: ^0.2.0
  uuid: ^4.4.0
  intl: ^0.19.0
  flutter_riverpod: ^2.5.1
  flutter_local_notifications: ^17.2.0
  timezone: ^0.9.4

dev_dependencies:
  drift_dev: ^2.20.0
  build_runner: ^2.4.11
  fake_async: ^1.3.1
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Write the failing test**

Create `app/test/db/app_db_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('content mirror round-trips a qna row with contract column names', () async {
    await db.into(db.specialities).insert(SpecialitiesCompanion.insert(
        id: '01SPEC', name: 'Anaesthesia', examType: 'DNB', slug: 'anaesthesia'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        id: '01CHAP', specialityId: '01SPEC', title: 'Airway Management',
        slug: 'airway-management'));
    await db.into(db.topics).insert(TopicsCompanion.insert(
        id: '01TOPIC', chapterId: '01CHAP', title: 'Difficult airway',
        slug: 'difficult-airway'));
    await db.into(db.qnas).insert(QnasCompanion.insert(
        id: '01QNA', topicId: '01TOPIC', question: 'Define TAP block.',
        earnsMarks: '[]', sections: '[]'));

    final row = await (db.select(db.qnas)
          ..where((q) => q.id.equals('01QNA')))
        .getSingle();
    expect(row.topicId, '01TOPIC');
    expect(row.question, 'Define TAP block.');
  });

  test('pending_review_events stores an event with null synced_at', () async {
    await db.into(db.pendingReviewEvents).insert(
        PendingReviewEventsCompanion.insert(
            id: 'uuid-1',
            contentId: '01QNA',
            rating: 'good',
            shownAt: DateTime.utc(2026, 7, 4, 10, 0, 0),
            revealedAt: DateTime.utc(2026, 7, 4, 10, 0, 15),
            ratedAt: DateTime.utc(2026, 7, 4, 10, 0, 20),
            localDay: '2026-07-04'));
    final row = await db.select(db.pendingReviewEvents).getSingle();
    expect(row.syncedAt, isNull);
    expect(row.rating, 'good');
  });

  test('duplicate review-event id is ignored (idempotent local insert)', () async {
    final e = PendingReviewEventsCompanion.insert(
        id: 'uuid-dup',
        contentId: '01QNA',
        rating: 'again',
        shownAt: DateTime.utc(2026, 7, 4),
        revealedAt: DateTime.utc(2026, 7, 4),
        ratedAt: DateTime.utc(2026, 7, 4),
        localDay: '2026-07-04');
    await db.into(db.pendingReviewEvents).insert(e);
    await db
        .into(db.pendingReviewEvents)
        .insert(e, mode: InsertMode.insertOrIgnore);
    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
  });

  test('cached_chapters and bookmarks and local_settings exist', () async {
    await db.into(db.cachedChapters).insert(CachedChaptersCompanion.insert(
        chapterId: '01CHAP', contentVersion: 3,
        cachedAt: DateTime.utc(2026, 7, 4)));
    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
        contentId: '01QNA', updatedAt: DateTime.utc(2026, 7, 4)));
    await db.into(db.localSettings).insert(LocalSettingsCompanion.insert(
        key: 'reminder_enabled', value: 'true'));
    expect((await db.select(db.bookmarks).getSingle()).deleted, false);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/db/app_db_test.dart`
Expected: FAIL - `Error: Couldn't resolve the package 'diplomate'` / `Target of URI doesn't exist: 'package:diplomate/data/db/app_db.dart'`

- [ ] **Step 4: Write the table definitions**

Create `app/lib/data/db/tables.dart`:

```dart
// Drift mirror of the Postgres content shape (sql/0001_content_v0.sql) plus
// local-first event/bookmark/cache tables. Column names mirror the SQL DDL
// exactly (drift emits snake_case from these camelCase getters).
// Wire enums (rating, event_type) are OWNED by sql/ DDL:
//   rating     -> sql/0003_users_events.sql  review_events_rating_check
//   event_type -> sql/0003_users_events.sql  app_events_event_type_check
import 'package:drift/drift.dart';

class Specialities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get examType => text()();
  TextColumn get slug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get specialityId => text()();
  TextColumn get title => text()();
  TextColumn get slug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get examWeight => integer().withDefault(const Constant(0))();
  IntColumn get contentVersion => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Topics extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get title => text()();
  TextColumn get slug => text()();
  TextColumn get examTheme => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Qnas extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get question => text()();
  TextColumn get years => text().nullable()();
  IntColumn get marks => integer().nullable()();
  TextColumn get earnsMarks => text()(); // JSON string, same shape as Postgres JSONB
  TextColumn get sections => text()(); // JSON string, same shape as Postgres JSONB
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// Image METADATA only - bytes live in ImageBlobs (fetched lazily, cached).
class Images extends Table {
  TextColumn get id => text()();
  TextColumn get qnaId => text()();
  TextColumn get caption => text()();
  TextColumn get contentDescription => text()();
  IntColumn get byteSize => integer()();
  TextColumn get sha256 => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class ImageBlobs extends Table {
  TextColumn get imageId => text()();
  BlobColumn get bytes => blob()();
  TextColumn get sha256 => text()();
  @override
  Set<Column> get primaryKey => {imageId};
}

// Full local review-event log. "Pending" = synced_at IS NULL; plan 6 sync
// sets synced_at after a 200, never deletes (the Leitner fold needs history).
class PendingReviewEvents extends Table {
  TextColumn get id => text()(); // client-generated UUID (D4 idempotency key)
  TextColumn get contentId => text()(); // QnA ULID (D14)
  TextColumn get rating => text()(); // wire enum, owned by sql/ DDL
  DateTimeColumn get shownAt => dateTime()();
  DateTimeColumn get revealedAt => dateTime()();
  DateTimeColumn get ratedAt => dateTime()();
  TextColumn get localDay => text()(); // "YYYY-MM-DD", 4am rollover
  DateTimeColumn get syncedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class PendingAppEvents extends Table {
  TextColumn get id => text()(); // client-generated UUID
  TextColumn get eventType => text()(); // wire enum, owned by sql/ DDL
  TextColumn get contentId => text().nullable()();
  IntColumn get hiddenMs => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get localDay => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

// Local LWW copy; user scoping is server-side (one signed-in user per device DB).
class Bookmarks extends Table {
  TextColumn get contentId => text()();
  DateTimeColumn get updatedAt => dateTime()(); // LWW key
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {contentId};
}

class CachedChapters extends Table {
  TextColumn get chapterId => text()();
  IntColumn get contentVersion => integer()();
  DateTimeColumn get cachedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {chapterId};
}

// Client-only flags (never synced). Today: 'reminder_enabled' = 'true'|'false'.
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
```

- [ ] **Step 5: Write the database class**

Create `app/lib/data/db/app_db.dart`:

```dart
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
```

- [ ] **Step 6: Generate drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...` and `lib/data/db/app_db.g.dart` exists.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/db/app_db_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 8: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/data/db/ app/test/db/app_db_test.dart
git commit -m "feat(app): drift AppDatabase schemaVersion 1 with contract tables"
```

---

### Task 2: Drift migration-test harness (from beta build 1)

**Files:**

- Create: `app/drift_schemas/drift_schema_v1.json` (generated)
- Create: `app/test/db/generated/` (generated verifier code)
- Test: `app/test/db/migration_test.dart`

**Interfaces:**

- Consumes: `AppDatabase` from Task 1 (`lib/data/db/app_db.dart`, `AppDatabase(super.e)`, `schemaVersion == 1`).
- Produces: the schema snapshot + verifier harness. RULE for every future schema change (record in the commit message of any version bump): bump `schemaVersion`, run `dart run drift_dev schema dump lib/data/db/app_db.dart drift_schemas/`, regenerate `test/db/generated/`, add a `verifier.migrateAndValidate(db, N)` test starting from EVERY older version.

- [ ] **Step 1: Dump the v1 schema snapshot**

Run: `dart run drift_dev schema dump lib/data/db/app_db.dart drift_schemas/`
Expected: `Wrote drift_schemas/drift_schema_v1.json` (file exists, non-empty).

- [ ] **Step 2: Generate the verifier helper**

Run: `dart run drift_dev schema generate drift_schemas/ test/db/generated/`
Expected: `test/db/generated/schema.dart` and `test/db/generated/schema_v1.dart` created.

- [ ] **Step 3: Write the failing migration test**

Create `app/test/db/migration_test.dart`:

```dart
import 'package:drift_dev/api/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';

import 'generated/schema.dart';

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
}
```

- [ ] **Step 4: Run test to verify it passes (harness proof)**

Run: `flutter test test/db/migration_test.dart`
Expected: PASS. (If it FAILS with a schema mismatch, the snapshot and `app_db.dart` diverged - rerun Steps 1-2 after fixing.)

- [ ] **Step 5: Prove the harness catches drift (temporary mutation)**

Temporarily add `TextColumn get scratch => text().nullable()();` to `LocalSettings` in `lib/data/db/tables.dart`, rerun `dart run build_runner build --delete-conflicting-outputs`, then:

Run: `flutter test test/db/migration_test.dart`
Expected: FAIL with `SchemaMismatch` (the harness detects an undumped change).

Revert the temporary column, rerun build_runner, rerun the test.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/drift_schemas/ app/test/db/generated/ app/test/db/migration_test.dart
git commit -m "test(app): drift schema snapshot v1 + migration verification harness"
```

---

### Task 3: local_day - the 4am rollover rule

**Files:**

- Create: `app/lib/domain/local_day.dart`
- Test: `app/test/domain/local_day_test.dart`

**Interfaces:**

- Consumes: nothing (pure Dart + intl).
- Produces: `String localDay(DateTime deviceNow)` returning `"YYYY-MM-DD"` with the 4am-local rollover, and `String addLocalDays(String day, int n)` for due-date arithmetic. Tasks 4-9 and plan 6 use `localDay(...)` for every `local_day` column value.

- [ ] **Step 1: Write the failing test**

Create `app/test/domain/local_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/local_day.dart';

void main() {
  group('localDay (4am local rollover, Anki convention)', () {
    test('03:59 still belongs to the previous day', () {
      expect(localDay(DateTime(2026, 7, 4, 3, 59)), '2026-07-03');
    });
    test('04:00 starts the new day', () {
      expect(localDay(DateTime(2026, 7, 4, 4, 0)), '2026-07-04');
    });
    test('23:59 is the same calendar day', () {
      expect(localDay(DateTime(2026, 7, 4, 23, 59)), '2026-07-04');
    });
    test('00:01 is still the previous calendar day', () {
      expect(localDay(DateTime(2026, 7, 5, 0, 1)), '2026-07-04');
    });
    test('month boundary: Aug 1 03:00 is Jul 31', () {
      expect(localDay(DateTime(2026, 8, 1, 3, 0)), '2026-07-31');
    });
  });

  group('addLocalDays', () {
    test('adds within a month', () {
      expect(addLocalDays('2026-07-04', 2), '2026-07-06');
    });
    test('crosses month and year boundaries', () {
      expect(addLocalDays('2026-12-30', 3), '2027-01-02');
    });
    test('zero days is identity', () {
      expect(addLocalDays('2026-07-04', 0), '2026-07-04');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/local_day_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/domain/local_day.dart'`

- [ ] **Step 3: Write the implementation (contract code, exact)**

Create `app/lib/domain/local_day.dart`:

```dart
import 'package:intl/intl.dart';

/// Device-local study day with the 4am rollover (Anki convention, D10).
/// This exact expression is the shared contract; do not restate it elsewhere.
String localDay(DateTime deviceNow) =>
    DateFormat('yyyy-MM-dd').format(deviceNow.subtract(const Duration(hours: 4)));

/// Due-date arithmetic on "YYYY-MM-DD" strings (calendar days; the 4am rule
/// is already baked into the day string, so plain date math is correct here).
String addLocalDays(String day, int n) {
  final d = DateTime.parse(day).add(Duration(days: n));
  return DateFormat('yyyy-MM-dd').format(d);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/local_day_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/domain/local_day.dart app/test/domain/local_day_test.dart
git commit -m "feat(app): localDay 4am rollover + local-day arithmetic"
```

---

### Task 4: Leitner fold (D10 math) + models

**Files:**

- Create: `app/lib/domain/models.dart` (create if plan 4 has not; otherwise append the two classes)
- Create: `app/lib/domain/scheduler/leitner.dart`
- Test: `app/test/domain/scheduler/leitner_fold_test.dart`

**Interfaces:**

- Consumes: `addLocalDays` from Task 3 (`package:diplomate/domain/local_day.dart`).
- Produces (contract-verbatim signatures, used by Tasks 5-9 and plan 6):

```dart
enum WireRating { again, hard, good }

class CardState {
  final String contentId;   // QnA ULID
  final int bucket;          // 1, 2, 3
  final int intervalDays;    // last applied interval (B3 doubling base)
  final String dueLocalDay;  // "YYYY-MM-DD"
  final String lastRatedDay; // "YYYY-MM-DD"
  final bool dueEndOfQueue;  // true right after 'again' (same-day, back of queue)
}

CardState? foldEvents(String contentId, List<ReviewEvent> sortedEvents);
CardState? applyRating(String contentId, CardState? prev, ReviewEvent e);
const Map<WireRating, String> wireToUiLabel; // good: 'Easy', hard: 'Medium', again: 'Hard'
```

and `class ReviewEvent { String id; String contentId; String rating; DateTime shownAt; DateTime revealedAt; DateTime ratedAt; String localDay; }` in `lib/domain/models.dart`.

- [ ] **Step 1: Write the failing test**

Create `app/test/domain/scheduler/leitner_fold_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

ReviewEvent ev(String rating, String day, {int seq = 0, String id = ''}) {
  final t = DateTime.parse('${day}T12:00:00').add(Duration(minutes: seq));
  return ReviewEvent(
    id: id.isEmpty ? '$rating-$day-$seq' : id,
    contentId: 'Q1',
    rating: rating,
    shownAt: t.subtract(const Duration(seconds: 30)),
    revealedAt: t.subtract(const Duration(seconds: 10)),
    ratedAt: t,
    localDay: day,
  );
}

void main() {
  test('no events -> null (card unseen, never queued: due-only queue)', () {
    expect(foldEvents('Q1', []), isNull);
  });

  test('first good: enters B1, moves to B2, due +1d, interval 1', () {
    final s = foldEvents('Q1', [ev('good', '2026-07-04')])!;
    expect(s.bucket, 2);
    expect(s.intervalDays, 1);
    expect(s.dueLocalDay, '2026-07-05');
    expect(s.lastRatedDay, '2026-07-04');
    expect(s.dueEndOfQueue, false);
  });

  test('good good: B2 -> B3, due +3d, interval 3', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-04'),
      ev('good', '2026-07-05'),
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 3);
    expect(s.dueLocalDay, '2026-07-08');
  });

  test('good in B3: stays B3, interval doubles (3 -> 6 -> 12)', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'),
      ev('good', '2026-07-02'),
      ev('good', '2026-07-05'),
      ev('good', '2026-07-11'),
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 12);
    expect(s.dueLocalDay, '2026-07-23');
  });

  test('again: back to B1, due SAME local day, end of queue, interval reset', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'),
      ev('again', '2026-07-02'),
    ])!;
    expect(s.bucket, 1);
    expect(s.intervalDays, 0);
    expect(s.dueLocalDay, '2026-07-02');
    expect(s.dueEndOfQueue, true);
  });

  test('hard: stays in bucket, keeps interval, due +2d', () {
    final s = foldEvents('Q1', [
      ev('good', '2026-07-01'), // B2, interval 1
      ev('good', '2026-07-02'), // B3, interval 3
      ev('hard', '2026-07-05'), // stays B3, interval stays 3, due +2
    ])!;
    expect(s.bucket, 3);
    expect(s.intervalDays, 3);
    expect(s.dueLocalDay, '2026-07-07');
    expect(s.dueEndOfQueue, false);
  });

  test('first rating hard: enters B1 and stays there, due +2d', () {
    final s = foldEvents('Q1', [ev('hard', '2026-07-04')])!;
    expect(s.bucket, 1);
    expect(s.dueLocalDay, '2026-07-06');
  });

  test('unknown rating value is skipped, state unchanged (FSRS forward-compat)', () {
    final withUnknown = foldEvents('Q1', [
      ev('good', '2026-07-04'),
      ev('easy', '2026-07-05'), // future FSRS value: skip + log
    ]);
    final without = foldEvents('Q1', [ev('good', '2026-07-04')]);
    expect(withUnknown!.bucket, without!.bucket);
    expect(withUnknown.intervalDays, without.intervalDays);
    expect(withUnknown.dueLocalDay, without.dueLocalDay);
  });

  test('only-unknown events -> null (card still unseen for scheduling)', () {
    expect(foldEvents('Q1', [ev('easy', '2026-07-04')]), isNull);
  });

  test('wireToUiLabel is the 2026-07-04 relabel', () {
    expect(wireToUiLabel[WireRating.good], 'Easy');
    expect(wireToUiLabel[WireRating.hard], 'Medium');
    expect(wireToUiLabel[WireRating.again], 'Hard');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/scheduler/leitner_fold_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/domain/models.dart'`

- [ ] **Step 3: Write the models**

Create `app/lib/domain/models.dart` (if plan 4 already created this file, append these classes; do not modify existing ones):

```dart
/// A single recall rating event. Wire shape of review_events
/// (sql/0003_users_events.sql); rating strings are OWNED by that DDL.
class ReviewEvent {
  const ReviewEvent({
    required this.id,
    required this.contentId,
    required this.rating,
    required this.shownAt,
    required this.revealedAt,
    required this.ratedAt,
    required this.localDay,
  });

  final String id; // client-generated UUID (idempotency key, D4)
  final String contentId; // QnA ULID (D14)
  final String rating; // 'again' | 'hard' | 'good' (raw string: fold must skip unknowns)
  final DateTime shownAt;
  final DateTime revealedAt;
  final DateTime ratedAt;
  final String localDay; // "YYYY-MM-DD", 4am rollover
}

/// App analytics event (D9 amended list - NO pack_download_* events).
class AppEvent {
  const AppEvent({
    required this.id,
    required this.eventType,
    this.contentId,
    this.hiddenMs,
    required this.occurredAt,
    required this.localDay,
  });

  final String id;
  final String eventType; // topic_opened | recall_shown | recall_revealed | recall_rated | session_start
  final String? contentId;
  final int? hiddenMs; // recall_revealed only
  final DateTime occurredAt;
  final String localDay;
}
```

- [ ] **Step 4: Write the scheduler fold**

Create `app/lib/domain/scheduler/leitner.dart`:

```dart
// D10 Leitner scheduler - pure functions, no Flutter imports.
// Wire rating enum {again, hard, good} is OWNED by
// sql/0003_users_events.sql (review_events_rating_check); the UI relabel
// below is display-only (2026-07-04 founder pass).
import 'dart:developer' show log;

import '../local_day.dart';
import '../models.dart';

enum WireRating { again, hard, good }

/// Display labels (2026-07-04 relabel). Never reorder: tray renders
/// Easy - Medium - Hard left to right.
const Map<WireRating, String> wireToUiLabel = {
  WireRating.good: 'Easy',
  WireRating.hard: 'Medium',
  WireRating.again: 'Hard',
};

class CardState {
  const CardState({
    required this.contentId,
    required this.bucket,
    required this.intervalDays,
    required this.dueLocalDay,
    required this.lastRatedDay,
    required this.dueEndOfQueue,
  });

  final String contentId; // QnA ULID
  final int bucket; // 1, 2, 3
  final int intervalDays; // last applied interval (B3 doubling base)
  final String dueLocalDay; // "YYYY-MM-DD"
  final String lastRatedDay; // "YYYY-MM-DD"
  final bool dueEndOfQueue; // true right after 'again' (same-day, back of queue)
}

/// Applies one event to a prior state. Unknown rating -> returns prev
/// unchanged and logs (forward-compat: an FSRS build may write ratings this
/// build does not know; skipping keeps the fold deterministic either way).
CardState? applyRating(String contentId, CardState? prev, ReviewEvent e) {
  final day = e.localDay;
  final bucket = prev?.bucket ?? 1; // new QnA enters B1 on first rating (D10)
  final interval = prev?.intervalDays ?? 0;

  switch (e.rating) {
    case 'again':
      return CardState(
        contentId: contentId,
        bucket: 1,
        intervalDays: 0,
        dueLocalDay: day, // same local day, back of queue
        lastRatedDay: day,
        dueEndOfQueue: true,
      );
    case 'hard':
      return CardState(
        contentId: contentId,
        bucket: bucket, // stays
        intervalDays: interval, // carries (B3 doubling base preserved)
        dueLocalDay: addLocalDays(day, 2),
        lastRatedDay: day,
        dueEndOfQueue: false,
      );
    case 'good':
      final int nextBucket;
      final int nextInterval;
      if (bucket == 1) {
        nextBucket = 2;
        nextInterval = 1;
      } else if (bucket == 2) {
        nextBucket = 3;
        nextInterval = 3;
      } else {
        nextBucket = 3; // B3 stays
        nextInterval = interval * 2; // previous interval x 2
      }
      return CardState(
        contentId: contentId,
        bucket: nextBucket,
        intervalDays: nextInterval,
        dueLocalDay: addLocalDays(day, nextInterval),
        lastRatedDay: day,
        dueEndOfQueue: false,
      );
    default:
      log('leitner: skipping unknown rating "${e.rating}" (event ${e.id})',
          name: 'diplomate.scheduler');
      return prev;
  }
}

/// Pure fold over rating events sorted by rated_at. Deterministic;
/// replay-idempotent. Returns null for a card with no known-rating events
/// (unseen cards are never queued - due-only queue, no new-card injection).
CardState? foldEvents(String contentId, List<ReviewEvent> sortedEvents) {
  CardState? state;
  for (final e in sortedEvents) {
    state = applyRating(contentId, state, e);
  }
  return state;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/scheduler/leitner_fold_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/domain/models.dart app/lib/domain/scheduler/leitner.dart app/test/domain/scheduler/leitner_fold_test.dart
git commit -m "feat(app): Leitner fold with exact D10 math + unknown-rating skip"
```

---

### Task 5: Queue builder + generative property tests

**Files:**

- Modify: `app/lib/domain/scheduler/leitner.dart` (append two functions)
- Test: `app/test/domain/scheduler/leitner_queue_test.dart`
- Test: `app/test/domain/scheduler/leitner_property_test.dart`

**Interfaces:**

- Consumes: `CardState`, `ReviewEvent`, `foldEvents`, `applyRating` from Task 4; `localDay`/`addLocalDays` from Task 3.
- Produces (appended to `lib/domain/scheduler/leitner.dart`, used by Tasks 6-9):

```dart
List<String> buildQueue(Map<String, CardState> states, String todayLocalDay);
Map<String, CardState> foldAll(List<ReviewEvent> events); // groups by contentId, sorts by ratedAt, folds
int dueCountFor(Map<String, CardState> states, String day); // #states with dueLocalDay <= day
```

- [ ] **Step 1: Write the failing queue-order test**

Create `app/test/domain/scheduler/leitner_queue_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

CardState cs(String id,
        {int bucket = 1,
        String due = '2026-07-04',
        String rated = '2026-07-01',
        bool endOfQueue = false,
        int interval = 1}) =>
    CardState(
        contentId: id,
        bucket: bucket,
        intervalDays: interval,
        dueLocalDay: due,
        lastRatedDay: rated,
        dueEndOfQueue: endOfQueue);

void main() {
  const today = '2026-07-04';

  test('queue is due-only: future cards and unseen cards never appear', () {
    final q = buildQueue({
      'A': cs('A', due: '2026-07-04'),
      'B': cs('B', due: '2026-07-05'), // tomorrow: excluded
    }, today);
    expect(q, ['A']);
  });

  test('overdue first, then lowest bucket, then oldest lastRatedDay', () {
    final q = buildQueue({
      'todayB2': cs('todayB2', bucket: 2, due: today, rated: '2026-07-01'),
      'overdue': cs('overdue', bucket: 3, due: '2026-07-02', rated: '2026-07-01'),
      'todayB1old': cs('todayB1old', bucket: 1, due: today, rated: '2026-06-28'),
      'todayB1new': cs('todayB1new', bucket: 1, due: today, rated: '2026-07-03'),
    }, today);
    expect(q, ['overdue', 'todayB1old', 'todayB1new', 'todayB2']);
  });

  test('again repeats (dueEndOfQueue, same day) go to the BACK of today', () {
    final q = buildQueue({
      'againNow': cs('againNow', due: today, endOfQueue: true, rated: today),
      'normal': cs('normal', bucket: 3, due: today, rated: '2026-07-01'),
    }, today);
    expect(q, ['normal', 'againNow']);
  });

  test('an end-of-queue card from YESTERDAY is plain overdue, not back-of-queue', () {
    final q = buildQueue({
      'staleAgain': cs('staleAgain', due: '2026-07-03', endOfQueue: true, rated: '2026-07-03'),
      'todayCard': cs('todayCard', due: today, rated: '2026-07-01'),
    }, today);
    expect(q, ['staleAgain', 'todayCard']);
  });

  test('deterministic tie-break by contentId', () {
    final a = buildQueue({
      'B': cs('B'),
      'A': cs('A'),
    }, today);
    final b = buildQueue({
      'A': cs('A'),
      'B': cs('B'),
    }, today);
    expect(a, b);
    expect(a, ['A', 'B']);
  });

  test('dueCountFor counts dueLocalDay <= day', () {
    final states = {
      'A': cs('A', due: '2026-07-04'),
      'B': cs('B', due: '2026-07-06'),
    };
    expect(dueCountFor(states, '2026-07-04'), 1);
    expect(dueCountFor(states, '2026-07-06'), 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/scheduler/leitner_queue_test.dart`
Expected: FAIL - `The function 'buildQueue' isn't defined`

- [ ] **Step 3: Append the queue functions**

Append to `app/lib/domain/scheduler/leitner.dart`:

```dart
/// Queue = due-only (dueLocalDay <= today), NO new-card injection (design T4).
/// Order: overdue first -> lowest bucket -> oldest lastRatedDay; 'again'
/// repeats (dueEndOfQueue on today's card) go to the back of today's queue.
/// contentId tie-break keeps the order fully deterministic.
List<String> buildQueue(Map<String, CardState> states, String todayLocalDay) {
  final due = states.values
      .where((s) => s.dueLocalDay.compareTo(todayLocalDay) <= 0)
      .toList();
  bool backOfQueue(CardState s) =>
      s.dueEndOfQueue && s.dueLocalDay == todayLocalDay;
  due.sort((a, b) {
    final aBack = backOfQueue(a) ? 1 : 0;
    final bBack = backOfQueue(b) ? 1 : 0;
    if (aBack != bBack) return aBack - bBack;
    final byDue = a.dueLocalDay.compareTo(b.dueLocalDay);
    if (byDue != 0) return byDue;
    if (a.bucket != b.bucket) return a.bucket - b.bucket;
    final byRated = a.lastRatedDay.compareTo(b.lastRatedDay);
    if (byRated != 0) return byRated;
    return a.contentId.compareTo(b.contentId);
  });
  return [for (final s in due) s.contentId];
}

/// Groups events by contentId, sorts each group by ratedAt, folds.
Map<String, CardState> foldAll(List<ReviewEvent> events) {
  final byContent = <String, List<ReviewEvent>>{};
  for (final e in events) {
    byContent.putIfAbsent(e.contentId, () => []).add(e);
  }
  final states = <String, CardState>{};
  byContent.forEach((contentId, list) {
    list.sort((a, b) => a.ratedAt.compareTo(b.ratedAt));
    final s = foldEvents(contentId, list);
    if (s != null) states[contentId] = s;
  });
  return states;
}

/// Number of cards due on or before [day] ("YYYY-MM-DD"). Feeds the D19
/// notification planner; monotonically nondecreasing in [day].
int dueCountFor(Map<String, CardState> states, String day) =>
    states.values.where((s) => s.dueLocalDay.compareTo(day) <= 0).length;
```

- [ ] **Step 4: Run queue test to verify it passes**

Run: `flutter test test/domain/scheduler/leitner_queue_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Write the generative property tests**

Create `app/test/domain/scheduler/leitner_property_test.dart` (hand-rolled seeded loops; no glados dependency - the fixed seed makes failures reproducible):

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/local_day.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

const ratingsWithUnknown = ['again', 'hard', 'good', 'easy']; // 'easy' = unknown

List<ReviewEvent> randomHistory(Random rnd, String contentId, int n) {
  var day = '2026-01-01';
  var t = DateTime.parse('2026-01-01T09:00:00');
  final events = <ReviewEvent>[];
  for (var i = 0; i < n; i++) {
    day = addLocalDays(day, rnd.nextInt(4)); // 0-3 day gaps
    t = t.add(Duration(hours: 6 + rnd.nextInt(48)));
    events.add(ReviewEvent(
      id: '$contentId-$i',
      contentId: contentId,
      rating: ratingsWithUnknown[rnd.nextInt(ratingsWithUnknown.length)],
      shownAt: t.subtract(const Duration(seconds: 40)),
      revealedAt: t.subtract(const Duration(seconds: 12)),
      ratedAt: t,
      localDay: day,
    ));
  }
  return events;
}

bool sameState(CardState? a, CardState? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.contentId == b.contentId &&
      a.bucket == b.bucket &&
      a.intervalDays == b.intervalDays &&
      a.dueLocalDay == b.dueLocalDay &&
      a.lastRatedDay == b.lastRatedDay &&
      a.dueEndOfQueue == b.dueEndOfQueue;
}

void main() {
  test('PROPERTY fold determinism: same event list folds to the same state', () {
    final rnd = Random(42);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      expect(sameState(foldEvents('Q$run', events), foldEvents('Q$run', events)),
          isTrue,
          reason: 'run $run diverged');
    }
  });

  test('PROPERTY replay idempotence: full re-fold == incremental applyRating', () {
    final rnd = Random(7);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      CardState? incremental;
      for (final e in events) {
        incremental = applyRating('Q$run', incremental, e);
      }
      expect(sameState(foldEvents('Q$run', events), incremental), isTrue,
          reason: 'run $run: incremental replay diverged from full fold');
    }
  });

  test('PROPERTY hard carries bucket and interval, due = ratedDay + 2', () {
    final rnd = Random(99);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      CardState? prev;
      for (final e in events) {
        final next = applyRating('Q$run', prev, e);
        if (e.rating == 'hard') {
          expect(next!.bucket, prev?.bucket ?? 1,
              reason: 'run $run: hard changed bucket');
          expect(next.intervalDays, prev?.intervalDays ?? 0,
              reason: 'run $run: hard changed interval');
          expect(next.dueLocalDay, addLocalDays(e.localDay, 2),
              reason: 'run $run: hard due is not +2d');
        }
        prev = next;
      }
    }
  });

  test('PROPERTY unknown ratings are transparent: fold(with) == fold(without)', () {
    final rnd = Random(1234);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      final known = events
          .where((e) => ['again', 'hard', 'good'].contains(e.rating))
          .toList();
      expect(
          sameState(foldEvents('Q$run', events), foldEvents('Q$run', known)),
          isTrue,
          reason: 'run $run: unknown rating leaked into state');
    }
  });

  test('PROPERTY content updates never touch scheduling: fold depends only on '
      'the event list (stable content IDs, A4)', () {
    // A chapter refresh rewrites qnas/topics rows but never review events.
    // Fold input is the event list alone, so state must be identical however
    // often "content metadata" changes around it. Modeled by folding the same
    // events twice with an unrelated mutation between - plus a db-level proof
    // in test/data/study_repository_test.dart (Task 6).
    final rnd = Random(2026);
    for (var run = 0; run < 100; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(30));
      final before = foldEvents('Q$run', events);
      final unrelated = randomHistory(rnd, 'OTHER$run', 5); // "content update" noise
      foldAll(unrelated);
      final after = foldEvents('Q$run', events);
      expect(sameState(before, after), isTrue, reason: 'run $run');
    }
  });

  test('PROPERTY B3 doubling base is always >= 3 (reachability invariant)', () {
    final rnd = Random(555);
    for (var run = 0; run < 200; run++) {
      final events = randomHistory(rnd, 'Q$run', 1 + rnd.nextInt(40));
      CardState? prev;
      for (final e in events) {
        prev = applyRating('Q$run', prev, e);
        if (prev != null && prev.bucket == 3) {
          expect(prev.intervalDays >= 3, isTrue,
              reason: 'run $run: B3 with interval ${prev.intervalDays}');
        }
      }
    }
  });

  test('PROPERTY buildQueue is deterministic and due-only', () {
    final rnd = Random(31337);
    for (var run = 0; run < 100; run++) {
      final all = <ReviewEvent>[];
      for (var c = 0; c < 10; c++) {
        all.addAll(randomHistory(rnd, 'Q$run-$c', 1 + rnd.nextInt(10)));
      }
      final states = foldAll(all);
      const today = '2026-02-15';
      final q1 = buildQueue(states, today);
      final q2 = buildQueue(Map.fromEntries(states.entries.toList().reversed), today);
      expect(q1, q2, reason: 'run $run: map order leaked into queue order');
      for (final id in q1) {
        expect(states[id]!.dueLocalDay.compareTo(today) <= 0, isTrue,
            reason: 'run $run: non-due card $id queued');
      }
    }
  });
}
```

- [ ] **Step 6: Run property tests to verify they pass**

Run: `flutter test test/domain/scheduler/leitner_property_test.dart`
Expected: PASS (7 tests). If any property fails, the seed in the failing test reproduces it exactly - fix the fold, never the test.

- [ ] **Step 7: Commit**

```bash
git add app/lib/domain/scheduler/leitner.dart app/test/domain/scheduler/
git commit -m "feat(app): due-only Leitner queue + generative property tests"
```

---

### Task 6: StudyRepository - event writers (persist BEFORE ack, D4)

**Files:**

- Create: `app/lib/data/repos/study_repository.dart`
- Test: `app/test/data/study_repository_test.dart`

**Interfaces:**

- Consumes: `AppDatabase` (Task 1), `localDay` (Task 3), `ReviewEvent` (Task 4), `WireRating` (Task 4).
- Produces (used by Tasks 7-9 and plan 6):

```dart
class StudyRepository {
  StudyRepository(AppDatabase db, {DateTime Function() now = DateTime.now});
  Future<ReviewEvent> recordRating({required String qnaId, required WireRating rating,
      required DateTime shownAt, required DateTime revealedAt}); // resolves AFTER drift persist (D4)
  Future<void> recordAppEvent({required String eventType, String? contentId, int? hiddenMs});
  Future<void> recordSessionStartIfIdle(); // session_start iff no app event in last 30 min
  Future<List<ReviewEvent>> allReviewEvents(); // sorted by ratedAt
  Stream<List<ReviewEvent>> watchReviewEvents(); // same, reactive
}
```

Plan 6's SyncService drains `pending_review_events`/`pending_app_events` WHERE `synced_at IS NULL` and sets `synced_at` on 200 - it must NOT delete rows (the fold reads them all).

- [ ] **Step 1: Write the failing test**

Create `app/test/data/study_repository_test.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late StudyRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 7, 4, 21, 30); // 9:30 pm local
    repo = StudyRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('recordRating persists a review event row BEFORE resolving (D4)', () async {
    final e = await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 45)),
        revealedAt: now.subtract(const Duration(seconds: 12)));
    // The await IS the ack gate: by the time the future resolves the row is in drift.
    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
    expect(rows.single.id, e.id);
    expect(rows.single.rating, 'good');
    expect(rows.single.localDay, '2026-07-04');
    expect(rows.single.syncedAt, isNull);
  });

  test('recordRating also writes a recall_rated app event (D9 funnel)', () async {
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.again,
        shownAt: now.subtract(const Duration(seconds: 45)),
        revealedAt: now.subtract(const Duration(seconds: 12)));
    final appRows = await db.select(db.pendingAppEvents).get();
    expect(appRows.where((r) => r.eventType == 'recall_rated').length, 1);
    expect(appRows.single.contentId, 'Q1');
  });

  test('rating survives app kill: rows persist across a reopen (file db)', () async {
    final file = File(
        '${Directory.systemTemp.createTempSync('diplomate').path}/kill.db');
    final db1 = AppDatabase(NativeDatabase(file));
    final r1 = StudyRepository(db1, now: () => now);
    await r1.recordRating(
        qnaId: 'Q1',
        rating: WireRating.hard,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    await db1.close(); // "kill" - the ack only ever happens after this insert
    final db2 = AppDatabase(NativeDatabase(file));
    final rows = await db2.select(db2.pendingReviewEvents).get();
    expect(rows.length, 1);
    expect(rows.single.rating, 'hard');
    await db2.close();
  });

  test('recordAppEvent writes recall_revealed with hidden_ms', () async {
    await repo.recordAppEvent(
        eventType: 'recall_revealed', contentId: 'Q1', hiddenMs: 14200);
    final row = await db.select(db.pendingAppEvents).getSingle();
    expect(row.eventType, 'recall_revealed');
    expect(row.hiddenMs, 14200);
    expect(row.localDay, '2026-07-04');
  });

  test('session_start: written when idle > 30 min, skipped when active', () async {
    await repo.recordSessionStartIfIdle(); // no prior events -> session_start
    await repo.recordAppEvent(eventType: 'topic_opened', contentId: 'T1');
    now = now.add(const Duration(minutes: 10));
    await repo.recordSessionStartIfIdle(); // active 10 min ago -> skip
    now = now.add(const Duration(minutes: 31));
    await repo.recordSessionStartIfIdle(); // idle 31 min -> session_start
    final rows = await db.select(db.pendingAppEvents).get();
    expect(rows.where((r) => r.eventType == 'session_start').length, 2);
  });

  test('allReviewEvents returns domain events sorted by ratedAt', () async {
    now = DateTime(2026, 7, 4, 10, 0);
    await repo.recordRating(
        qnaId: 'Q2',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    now = DateTime(2026, 7, 4, 9, 0); // earlier rating recorded second
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    final events = await repo.allReviewEvents();
    expect(events.map((e) => e.contentId).toList(), ['Q1', 'Q2']);
  });

  test('content update (chapter refresh) leaves review events + fold untouched', () async {
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    final before = foldAll(await repo.allReviewEvents());

    // Simulate exactly what plan 6's chapter refresh does: delete + reinsert
    // qnas rows in one transaction. Events are keyed by stable ULIDs (A4).
    await db.transaction(() async {
      await db.delete(db.qnas).go();
      await db.into(db.qnas).insert(QnasCompanion.insert(
          id: 'Q1', topicId: 'T1', question: 'Updated wording',
          earnsMarks: '[]', sections: '[]'));
    });

    final after = foldAll(await repo.allReviewEvents());
    expect(after['Q1']!.bucket, before['Q1']!.bucket);
    expect(after['Q1']!.intervalDays, before['Q1']!.intervalDays);
    expect(after['Q1']!.dueLocalDay, before['Q1']!.dueLocalDay);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/study_repository_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/data/repos/study_repository.dart'`

- [ ] **Step 3: Write the implementation**

Create `app/lib/data/repos/study_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/local_day.dart';
import '../../domain/models.dart';
import '../../domain/scheduler/leitner.dart';
import '../db/app_db.dart';

const _uuid = Uuid();
const _sessionIdleWindow = Duration(minutes: 30); // D9: session_start definition

/// Local-first event writers. Every write completes in drift BEFORE the
/// returned future resolves; callers ack the UI only after awaiting (D4).
class StudyRepository {
  StudyRepository(this._db, {DateTime Function() now = DateTime.now})
      : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Persists the review event (and its recall_rated app event) and returns
  /// the domain event. Resolves only after both rows are in drift.
  Future<ReviewEvent> recordRating({
    required String qnaId,
    required WireRating rating,
    required DateTime shownAt,
    required DateTime revealedAt,
  }) async {
    final ratedAt = _now();
    final event = ReviewEvent(
      id: _uuid.v4(),
      contentId: qnaId,
      rating: rating.name, // wire string; enum owned by sql/0003_users_events.sql
      shownAt: shownAt,
      revealedAt: revealedAt,
      ratedAt: ratedAt,
      localDay: localDay(ratedAt),
    );
    await _db.transaction(() async {
      await _db.into(_db.pendingReviewEvents).insert(
            PendingReviewEventsCompanion.insert(
              id: event.id,
              contentId: event.contentId,
              rating: event.rating,
              shownAt: event.shownAt,
              revealedAt: event.revealedAt,
              ratedAt: event.ratedAt,
              localDay: event.localDay,
            ),
            mode: InsertMode.insertOrIgnore, // idempotent on id (D4)
          );
      await _insertAppEvent(eventType: 'recall_rated', contentId: qnaId);
    });
    return event;
  }

  Future<void> recordAppEvent({
    required String eventType,
    String? contentId,
    int? hiddenMs,
  }) =>
      _insertAppEvent(
          eventType: eventType, contentId: contentId, hiddenMs: hiddenMs);

  /// D9: session_start = first activity after >= 30 min of inactivity.
  Future<void> recordSessionStartIfIdle() async {
    final last = await (_db.select(_db.pendingAppEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .getSingleOrNull();
    final now = _now();
    if (last == null || now.difference(last.occurredAt) >= _sessionIdleWindow) {
      await _insertAppEvent(eventType: 'session_start');
    }
  }

  Future<void> _insertAppEvent({
    required String eventType,
    String? contentId,
    int? hiddenMs,
  }) async {
    final occurredAt = _now();
    await _db.into(_db.pendingAppEvents).insert(
          PendingAppEventsCompanion.insert(
            id: _uuid.v4(),
            eventType: eventType,
            contentId: Value(contentId),
            hiddenMs: Value(hiddenMs),
            occurredAt: occurredAt,
            localDay: localDay(occurredAt),
          ),
        );
  }

  Future<List<ReviewEvent>> allReviewEvents() async {
    final rows = await (_db.select(_db.pendingReviewEvents)
          ..orderBy([(t) => OrderingTerm.asc(t.ratedAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Stream<List<ReviewEvent>> watchReviewEvents() =>
      (_db.select(_db.pendingReviewEvents)
            ..orderBy([(t) => OrderingTerm.asc(t.ratedAt)]))
          .watch()
          .map((rows) => rows.map(_toDomain).toList());

  ReviewEvent _toDomain(PendingReviewEvent row) => ReviewEvent(
        id: row.id,
        contentId: row.contentId,
        rating: row.rating,
        shownAt: row.shownAt,
        revealedAt: row.revealedAt,
        ratedAt: row.ratedAt,
        localDay: row.localDay,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/study_repository_test.dart`
Expected: PASS (7 tests). Note: if the generated row class is named differently (drift names it from the table class, singularized: `PendingReviewEvent`), check `app_db.g.dart` and match it.

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/repos/study_repository.dart app/test/data/study_repository_test.dart
git commit -m "feat(app): StudyRepository persists ratings pre-ack + D9 app events"
```

---

### Task 7: Queue providers + 4am foregrounded rollover

**Files:**

- Create: `app/lib/providers/study_providers.dart`
- Test: `app/test/providers/study_providers_test.dart`

**Interfaces:**

- Consumes: `AppDatabase` (Task 1), `localDay` (Task 3), `foldAll`/`buildQueue` (Task 5), `StudyRepository` (Task 6).
- Produces (Riverpod, used by Task 8/9, plan 4 screens, and plan 6 wiring):

```dart
final clockProvider = Provider<DateTime Function()>;                 // override in tests
final appDatabaseProvider = Provider<AppDatabase>;                   // plan 6 overrides with the real file db
final studyRepositoryProvider = Provider<StudyRepository>;
final localDayProvider = NotifierProvider<LocalDayNotifier, String>; // 4am-aware "YYYY-MM-DD"
final reviewEventsProvider = StreamProvider<List<ReviewEvent>>;
final cardStatesProvider = Provider<Map<String, CardState>>;
final dueQueueProvider = Provider<List<String>>;                     // Reader queue mode order
final dueCountProvider = Provider<int>;                              // Home "View N suggested answers"
```

`LocalDayNotifier` exposes `void recompute()`; Task 9's lifecycle observer calls it on app resume. A `Timer` armed at the next 4am covers the foregrounded rollover.

- [ ] **Step 1: Write the failing test**

Create `app/test/providers/study_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';
import 'package:diplomate/providers/study_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(DateTime Function() clock) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      appDatabaseProvider
          .overrideWithValue(AppDatabase(NativeDatabase.memory())),
    ]);
    addTearDown(() {
      container.read(appDatabaseProvider).close();
      container.dispose();
    });
    return container;
  }

  test('localDayProvider honors the 4am rule at build', () {
    final c = makeContainer(() => DateTime(2026, 7, 4, 3, 30));
    expect(c.read(localDayProvider), '2026-07-03');
  });

  test('4am rollover while foregrounded: timer recomputes the day and the '
      'due queue without restart', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 4, 3, 59);
      final c = makeContainer(() => now);

      // Card rated 'again' on the (pre-4am) day 2026-07-03: due 2026-07-03.
      // Before rollover it is due (overdue path); we assert on the DAY change.
      expect(c.read(localDayProvider), '2026-07-03');

      now = DateTime(2026, 7, 4, 4, 0, 30);
      async.elapse(const Duration(minutes: 2)); // fires the armed 4am timer
      expect(c.read(localDayProvider), '2026-07-04');
    });
  });

  test('recompute() on resume picks up a day change without the timer', () {
    var now = DateTime(2026, 7, 4, 3, 0);
    final c = makeContainer(() => now);
    expect(c.read(localDayProvider), '2026-07-03');
    now = DateTime(2026, 7, 4, 11, 0); // phone slept through 4am
    c.read(localDayProvider.notifier).recompute();
    expect(c.read(localDayProvider), '2026-07-04');
  });

  test('dueQueueProvider and dueCountProvider fold events into a due-only queue',
      () async {
    var now = DateTime(2026, 7, 4, 10, 0);
    final c = makeContainer(() => now);
    final repo = c.read(studyRepositoryProvider);

    // Q1 rated 'again' today -> due today (back of queue).
    await repo.recordRating(
        qnaId: 'Q1',
        rating: WireRating.again,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));
    // Q2 rated 'good' today -> due tomorrow (not in today's queue).
    await repo.recordRating(
        qnaId: 'Q2',
        rating: WireRating.good,
        shownAt: now.subtract(const Duration(seconds: 30)),
        revealedAt: now.subtract(const Duration(seconds: 11)));

    // Let the drift watch stream deliver.
    await c.read(reviewEventsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(dueQueueProvider), ['Q1']);
    expect(c.read(dueCountProvider), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/study_providers_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/providers/study_providers.dart'`

- [ ] **Step 3: Write the providers**

Create `app/lib/providers/study_providers.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_db.dart';
import '../data/repos/study_repository.dart';
import '../domain/local_day.dart';
import '../domain/models.dart';
import '../domain/scheduler/leitner.dart';

/// Injectable clock; tests override, production uses DateTime.now.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Plan 6 overrides this in main.dart with the real on-device database
/// (AppDatabase(driftDatabase(name: 'diplomate'))). The in-memory default
/// keeps widget tests and previews self-contained.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

final studyRepositoryProvider = Provider<StudyRepository>((ref) =>
    StudyRepository(ref.watch(appDatabaseProvider),
        now: ref.watch(clockProvider)));

/// Current study day ("YYYY-MM-DD", 4am rollover). Recomputes via an armed
/// timer at the next 4am (foregrounded rollover, eng E4) and via
/// recompute() on app resume (Task 9 lifecycle observer).
final localDayProvider =
    NotifierProvider<LocalDayNotifier, String>(LocalDayNotifier.new);

class LocalDayNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    _armTimer();
    return localDay(ref.read(clockProvider)());
  }

  void recompute() {
    final day = localDay(ref.read(clockProvider)());
    if (day != state) state = day;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    final now = ref.read(clockProvider)();
    final today4am = DateTime(now.year, now.month, now.day, 4);
    final next4am =
        now.isBefore(today4am) ? today4am : today4am.add(const Duration(days: 1));
    _timer = Timer(next4am.difference(now) + const Duration(seconds: 1),
        recompute);
  }
}

final reviewEventsProvider = StreamProvider<List<ReviewEvent>>(
    (ref) => ref.watch(studyRepositoryProvider).watchReviewEvents());

final cardStatesProvider = Provider<Map<String, CardState>>((ref) =>
    foldAll(ref.watch(reviewEventsProvider).valueOrNull ?? const []));

/// Due-only queue for today (D10 order). Reader queue mode consumes this;
/// the notification deep-link opens Reader at its first element.
final dueQueueProvider = Provider<List<String>>((ref) =>
    buildQueue(ref.watch(cardStatesProvider), ref.watch(localDayProvider)));

/// Home primary CTA count: "View N suggested answers" (hidden at N=0).
final dueCountProvider = Provider<int>((ref) => ref.watch(dueQueueProvider).length);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/study_providers_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/providers/study_providers.dart app/test/providers/study_providers_test.dart
git commit -m "feat(app): due-queue providers + foregrounded 4am rollover recompute"
```

---

### Task 8: ReaderController - queue/browse modes + debounced rating (CEO-T5, DESIGN-T4)

**Files:**

- Create: `app/lib/ui/reader/reader_controller.dart`
- Test: `app/test/ui/reader/reader_controller_test.dart`
- Test: `app/test/ui/reader/rating_debounce_widget_test.dart`

**Interfaces:**

- Consumes: `StudyRepository.recordRating/recordAppEvent` (Task 6), `WireRating`/`wireToUiLabel` (Task 4).
- Produces (bound by plan 4's Reader screen and plan 6's router):

```dart
enum ReaderMode { queue, browse }

class ReaderController extends ChangeNotifier {
  ReaderController.queue({required StudyRepository repo, required List<String> queue,
      DateTime Function() now});
  ReaderController.browse({required StudyRepository repo, required String qnaId,
      required List<String> topicQnaIds, DateTime Function() now});
  ReaderMode get mode;
  String? get currentQnaId;   // null only when complete == true
  int get position;           // 1-based (queue mode overline "Suggestion · N of M")
  int get total;              // M (queue mode); topicQnaIds.length in browse
  bool get revealed;
  bool get ratingInFlight;    // true while a rate() persist+advance is running
  bool get complete;          // queue exhausted -> end-of-queue completion state
  bool get hasNextInTopic;    // browse mode "Next in topic" visibility
  Future<void> reveal();      // records recall_revealed + hidden_ms
  Future<void> rate(WireRating rating); // debounced; persists pre-ack; queue advances, browse stays
  void nextInTopic();         // browse mode only
}
```

Screen contract (plan 4): queue mode shows overline `Suggestion · $position of $total`; browse mode shows crumb only (no overline, no counter); after rating in browse mode show "Next in topic" when `hasNextInTopic`; `complete == true` renders the designed end state ("Today's recall is complete. N reviewed; next due tomorrow." + "Study a new answer"). The screen MUST `await controller.rate(...)` before showing the "Rated <tier> - next answer" toast (D4 pre-ack law). Every screen re-entry constructs a fresh controller (recall gate cannot be bypassed).

- [ ] **Step 1: Write the failing controller unit test**

Create `app/test/ui/reader/reader_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';
import 'package:diplomate/ui/reader/reader_controller.dart';

void main() {
  late AppDatabase db;
  late StudyRepository repo;
  var now = DateTime(2026, 7, 4, 10, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 7, 4, 10, 0);
    repo = StudyRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  group('queue mode', () {
    test('starts unrevealed at position 1 and records recall_shown', () async {
      final c = ReaderController.queue(
          repo: repo, queue: ['Q1', 'Q2'], now: () => now);
      expect(c.mode, ReaderMode.queue);
      expect(c.currentQnaId, 'Q1');
      expect(c.position, 1);
      expect(c.total, 2);
      expect(c.revealed, false);
      await pumpEventQueue();
      final events = await db.select(db.pendingAppEvents).get();
      expect(events.where((e) => e.eventType == 'recall_shown').length, 1);
    });

    test('reveal records recall_revealed with hidden_ms >= elapsed', () async {
      final c = ReaderController.queue(repo: repo, queue: ['Q1'], now: () => now);
      now = now.add(const Duration(seconds: 14));
      await c.reveal();
      expect(c.revealed, true);
      final events = await db.select(db.pendingAppEvents).get();
      final revealed =
          events.singleWhere((e) => e.eventType == 'recall_revealed');
      expect(revealed.hiddenMs, 14000);
      expect(revealed.contentId, 'Q1');
    });

    test('rate persists then auto-advances; queue exhausts to complete', () async {
      final c = ReaderController.queue(
          repo: repo, queue: ['Q1', 'Q2'], now: () => now);
      await c.reveal();
      await c.rate(WireRating.good);
      expect(c.currentQnaId, 'Q2');
      expect(c.position, 2);
      expect(c.revealed, false); // next card starts at the recall gate
      await c.reveal();
      await c.rate(WireRating.again);
      expect(c.complete, true);
      expect(c.currentQnaId, isNull);
      final rows = await db.select(db.pendingReviewEvents).get();
      expect(rows.length, 2);
    });

    test('rate before reveal is a no-op (soft gate)', () async {
      final c = ReaderController.queue(repo: repo, queue: ['Q1'], now: () => now);
      await c.rate(WireRating.good);
      expect((await db.select(db.pendingReviewEvents).get()), isEmpty);
      expect(c.position, 1);
    });
  });

  group('browse mode', () {
    test('rate-then-stay: rating persists but does NOT advance', () async {
      final c = ReaderController.browse(
          repo: repo,
          qnaId: 'Q2',
          topicQnaIds: ['Q1', 'Q2', 'Q3'],
          now: () => now);
      expect(c.mode, ReaderMode.browse);
      expect(c.currentQnaId, 'Q2');
      await c.reveal();
      await c.rate(WireRating.hard);
      expect(c.currentQnaId, 'Q2'); // stays
      expect(c.revealed, true); // still on the revealed answer
      expect(c.hasNextInTopic, true);
      expect((await db.select(db.pendingReviewEvents).get()).length, 1);
    });

    test('nextInTopic advances within the topic and resets the gate', () async {
      final c = ReaderController.browse(
          repo: repo,
          qnaId: 'Q2',
          topicQnaIds: ['Q1', 'Q2', 'Q3'],
          now: () => now);
      await c.reveal();
      c.nextInTopic();
      expect(c.currentQnaId, 'Q3');
      expect(c.revealed, false);
      expect(c.hasNextInTopic, false); // Q3 is last
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/reader/reader_controller_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/ui/reader/reader_controller.dart'`

- [ ] **Step 3: Write the controller**

Create `app/lib/ui/reader/reader_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../data/repos/study_repository.dart';
import '../../domain/scheduler/leitner.dart';

enum ReaderMode { queue, browse }

/// Drives one Reader session. Queue mode: due-only suggestions with
/// auto-advance ("Suggestion · N of M" overline). Browse mode: opened from
/// Topics/Bookmarks - crumb only, rate-then-stay + "Next in topic".
/// Construct fresh on every screen entry (the recall gate resets).
class ReaderController extends ChangeNotifier {
  ReaderController.queue({
    required StudyRepository repo,
    required List<String> queue,
    DateTime Function() now = DateTime.now,
  })  : _repo = repo,
        _now = now,
        mode = ReaderMode.queue,
        _items = List.unmodifiable(queue),
        _index = 0 {
    _startCurrent();
  }

  ReaderController.browse({
    required StudyRepository repo,
    required String qnaId,
    required List<String> topicQnaIds,
    DateTime Function() now = DateTime.now,
  })  : _repo = repo,
        _now = now,
        mode = ReaderMode.browse,
        _items = List.unmodifiable(topicQnaIds),
        _index = topicQnaIds.indexOf(qnaId) {
    assert(_index >= 0, 'qnaId must be in topicQnaIds');
    _startCurrent();
  }

  final StudyRepository _repo;
  final DateTime Function() _now;
  final ReaderMode mode;
  final List<String> _items;

  int _index;
  bool _revealed = false;
  bool _ratingInFlight = false;
  bool _complete = false;
  DateTime? _shownAt;
  DateTime? _revealedAt;

  String? get currentQnaId => _complete ? null : _items[_index];
  int get position => _index + 1; // 1-based for "Suggestion · N of M"
  int get total => _items.length;
  bool get revealed => _revealed;
  bool get ratingInFlight => _ratingInFlight;
  bool get complete => _complete;
  bool get hasNextInTopic =>
      mode == ReaderMode.browse && _index < _items.length - 1;

  void _startCurrent() {
    _revealed = false;
    _revealedAt = null;
    _shownAt = _now();
    // Fire-and-forget analytics: the recall gate must not wait on a write.
    _repo.recordAppEvent(eventType: 'recall_shown', contentId: _items[_index]);
    notifyListeners();
  }

  /// Reveal the model answer. hidden_ms feeds the metric-side validity rule
  /// (hidden >= 10s AND rated) - computed in SQL, never surfaced in UI.
  Future<void> reveal() async {
    if (_revealed || _complete) return;
    _revealedAt = _now();
    _revealed = true;
    final hiddenMs = _revealedAt!.difference(_shownAt!).inMilliseconds;
    notifyListeners();
    await _repo.recordAppEvent(
        eventType: 'recall_revealed',
        contentId: _items[_index],
        hiddenMs: hiddenMs);
  }

  /// Debounced (CEO-T5): re-entrant calls while a rating is in flight are
  /// dropped, so a double-tap yields exactly one review event and exactly
  /// one queue advance. Resolves AFTER the drift persist (D4) - the screen
  /// shows its "Rated <tier> - next answer" toast only after this await.
  Future<void> rate(WireRating rating) async {
    if (!_revealed || _ratingInFlight || _complete) return;
    _ratingInFlight = true;
    notifyListeners();
    try {
      await _repo.recordRating(
        qnaId: _items[_index],
        rating: rating,
        shownAt: _shownAt!,
        revealedAt: _revealedAt!,
      );
      if (mode == ReaderMode.queue) {
        if (_index + 1 < _items.length) {
          _index += 1;
          _ratingInFlight = false;
          _startCurrent(); // auto-advance: next card at the recall gate
        } else {
          _complete = true; // end-of-queue completion state (design F8)
          _ratingInFlight = false;
          notifyListeners();
        }
      } else {
        _ratingInFlight = false; // browse: rate-then-stay
        notifyListeners();
      }
    } catch (_) {
      _ratingInFlight = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Browse mode only: the "Next in topic" action after rate-then-stay.
  void nextInTopic() {
    if (mode != ReaderMode.browse || !hasNextInTopic) return;
    _index += 1;
    _startCurrent();
  }
}
```

- [ ] **Step 4: Run controller test to verify it passes**

Run: `flutter test test/ui/reader/reader_controller_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Write the failing debounce WIDGET test (CEO-T5)**

Create `app/test/ui/reader/rating_debounce_widget_test.dart`. It drives a real tap pipeline through a minimal tray harness wired exactly the way plan 4's tray must be wired (buttons disabled while `ratingInFlight`, onPressed awaits `rate()`):

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';
import 'package:diplomate/ui/reader/reader_controller.dart';

/// Minimal harness mirroring the plan-4 tray wiring contract:
/// tray order Easy - Medium - Hard, onPressed = controller.rate,
/// buttons disabled while ratingInFlight.
class _TrayHarness extends StatelessWidget {
  const _TrayHarness(this.controller);
  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            children: [
              Text(controller.complete
                  ? 'complete'
                  : 'Suggestion · ${controller.position} of ${controller.total}'),
              for (final rating in const [
                WireRating.good, // "Easy"
                WireRating.hard, // "Medium"
                WireRating.again, // "Hard"
              ])
                ElevatedButton(
                  onPressed: controller.ratingInFlight
                      ? null
                      : () => controller.rate(rating),
                  child: Text(wireToUiLabel[rating]!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
      'double-tapping a rating yields EXACTLY one review event and one '
      'queue advance (CEO-T5)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = StudyRepository(db);
    final controller =
        ReaderController.queue(repo: repo, queue: ['Q1', 'Q2', 'Q3']);
    await controller.reveal();

    await tester.pumpWidget(_TrayHarness(controller));
    expect(find.text('Suggestion · 1 of 3'), findsOneWidget);

    // Two taps in the same frame - the classic double-tap race.
    await tester.tap(find.text('Easy'));
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1, reason: 'double-tap must not double-count');
    expect(controller.position, 2, reason: 'exactly one queue advance');
    expect(find.text('Suggestion · 2 of 3'), findsOneWidget);
  });

  testWidgets('tapping two DIFFERENT tiers rapidly still yields one event',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = StudyRepository(db);
    final controller = ReaderController.queue(repo: repo, queue: ['Q1', 'Q2']);
    await controller.reveal();

    await tester.pumpWidget(_TrayHarness(controller));
    await tester.tap(find.text('Easy'));
    await tester.tap(find.text('Hard')); // second tap during in-flight persist
    await tester.pumpAndSettle();

    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
    expect(rows.single.rating, 'good'); // the FIRST tap won
    expect(controller.position, 2);
  });
}
```

- [ ] **Step 6: Run the widget test**

Run: `flutter test test/ui/reader/rating_debounce_widget_test.dart`
Expected: PASS (the Step 3 controller already carries the debounce; if either test fails, the debounce is broken - fix `rate()`, never the test).

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/reader/reader_controller.dart app/test/ui/reader/
git commit -m "feat(app): Reader queue/browse controller with debounced rating tray"
```

---

### Task 9: Daily notification - fresh at fire + queue deep-link (D19)

**Files:**

- Create: `app/lib/services/notification_service.dart`
- Create: `app/lib/services/study_lifecycle_observer.dart`
- Test: `app/test/services/notification_planner_test.dart`
- Test: `app/test/services/study_lifecycle_observer_test.dart`

**Interfaces:**

- Consumes: `CardState`/`dueCountFor` (Tasks 4-5), `localDay`/`addLocalDays` (Task 3), providers (Task 7), `StudyRepository.recordSessionStartIfIdle` (Task 6).
- Produces (plan 6 wires these in `main.dart`):

```dart
class ScheduledReminder {
  final int id;              // 1 = exact-count one-shot, 2 = countless daily repeat
  final DateTime fireAt;     // local wall clock, 20:00
  final String body;         // "N answers due today" | countless copy
  final bool repeatsDaily;
}

List<ScheduledReminder> planReminders(Map<String, CardState> states, DateTime now); // pure

class NotificationService {
  NotificationService(FlutterLocalNotificationsPlugin plugin, AppDatabase db);
  Future<void> init({required void Function() onTapOpensQueue}); // permission + tap handler
  Future<void> reschedule({required Map<String, CardState> states, required DateTime now});
  Future<void> setReminderEnabled(bool enabled); // Account row toggle; persists to local_settings
  Future<bool> reminderEnabled();                // default true ("On · 8:00 pm")
}

class StudyLifecycleObserver extends WidgetsBindingObserver {
  StudyLifecycleObserver({required void Function() onResumed, required void Function() onPaused});
}
```

Plan 6 wiring contract: `init(onTapOpensQueue: ...)` routes to Reader queue mode starting at `dueQueueProvider.first`; a `container.listen(dueQueueProvider, ...)` calls `reschedule` after every rating AND after the 4am rollover (both change `dueQueueProvider`); the observer's `onPaused` also calls `reschedule` (fresh-at-fire on background) and `onResumed` calls `LocalDayNotifier.recompute()` + `recordSessionStartIfIdle()`. Cold-start taps: plan 6 checks `getNotificationAppLaunchDetails()` with the same `'queue'` payload.

- [ ] **Step 1: Write the failing planner test**

The planner is pure; every freshness rule is tested here. Honesty argument encoded in the tests: `dueCountFor(states, day)` for a FIXED day only changes when a rating lands (which triggers reschedule), so the one-shot's exact count is true at fire even if the app stays closed; due counts are monotonically nondecreasing over days, so the countless repeat that starts the day AFTER a nonzero-count day can never fire on a zero-due day.

Create `app/test/services/notification_planner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/domain/scheduler/leitner.dart';
import 'package:diplomate/services/notification_service.dart';

CardState cs(String id, String due) => CardState(
    contentId: id,
    bucket: 1,
    intervalDays: 1,
    dueLocalDay: due,
    lastRatedDay: '2026-07-01',
    dueEndOfQueue: false);

void main() {
  test('no card states -> no notifications (day-zero users get silence)', () {
    expect(planReminders({}, DateTime(2026, 7, 4, 10, 0)), isEmpty);
  });

  test('due today, before 8pm -> exact one-shot tonight + countless repeat '
      'from tomorrow', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-02')},
        DateTime(2026, 7, 4, 10, 0));
    expect(plan.length, 2);
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.id, 1);
    expect(oneShot.fireAt, DateTime(2026, 7, 4, 20, 0));
    expect(oneShot.body, '2 answers due today');
    final repeat = plan.singleWhere((p) => p.repeatsDaily);
    expect(repeat.id, 2);
    expect(repeat.fireAt, DateTime(2026, 7, 5, 20, 0));
    expect(repeat.body, 'Your recall queue has answers due');
  });

  test('after 8pm tonight -> one-shot moves to tomorrow with TOMORROW\'s count', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-05')},
        DateTime(2026, 7, 4, 21, 0)); // 9pm: tonight's slot has passed
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.fireAt, DateTime(2026, 7, 5, 20, 0));
    expect(oneShot.body, '2 answers due today'); // A overdue + B due by the 5th
  });

  test('nothing due today but due in 3 days -> one-shot skips to that day '
      '(never a zero-count or lying notification between)', () {
    final plan = planReminders(
        {'A': cs('A', '2026-07-07')}, DateTime(2026, 7, 4, 10, 0));
    final oneShot = plan.singleWhere((p) => !p.repeatsDaily);
    expect(oneShot.fireAt, DateTime(2026, 7, 7, 20, 0));
    expect(oneShot.body, '1 answer due today'); // singular
    final repeat = plan.singleWhere((p) => p.repeatsDaily);
    expect(repeat.fireAt, DateTime(2026, 7, 8, 20, 0));
  });

  test('FRESHNESS: re-planning after a rating replaces the stale count', () {
    final before = planReminders(
        {'A': cs('A', '2026-07-04'), 'B': cs('B', '2026-07-04')},
        DateTime(2026, 7, 4, 10, 0));
    expect(before.singleWhere((p) => !p.repeatsDaily).body,
        '2 answers due today');
    // User rates A 'good' at 10:05 -> A due tomorrow. Reschedule trigger fires.
    final after = planReminders(
        {'A': cs('A', '2026-07-05'), 'B': cs('B', '2026-07-04')},
        DateTime(2026, 7, 4, 10, 5));
    expect(after.singleWhere((p) => !p.repeatsDaily).body,
        '1 answer due today');
  });

  test('FRESHNESS: post-rollover re-plan uses the new local day', () {
    // 3:59am July 5: study-day is still July 4; card due July 5.
    final before = planReminders(
        {'A': cs('A', '2026-07-05')}, DateTime(2026, 7, 5, 3, 59));
    // fire day chosen by calendar: July 5 8pm has count 1 -> fine either side,
    // but the count must be computed for the FIRE day, not "now"'s study day.
    expect(before.singleWhere((p) => !p.repeatsDaily).fireAt,
        DateTime(2026, 7, 5, 20, 0));
    final after = planReminders(
        {'A': cs('A', '2026-07-05')}, DateTime(2026, 7, 5, 4, 1));
    expect(after.singleWhere((p) => !p.repeatsDaily).body,
        '1 answer due today');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/notification_planner_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/services/notification_service.dart'`

- [ ] **Step 3: Write the notification service**

Create `app/lib/services/notification_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db/app_db.dart';
import '../domain/scheduler/leitner.dart';

const _reminderHour = 20; // 8:00 pm (Account row: "On · 8:00 pm")
const _oneShotId = 1;
const _repeatId = 2;
const queuePayload = 'queue'; // deep-link payload -> Reader queue mode

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.fireAt,
    required this.body,
    required this.repeatsDaily,
  });

  final int id;
  final DateTime fireAt; // local wall clock
  final String body;
  final bool repeatsDaily;
}

/// Pure planner - all D19 honesty rules live here (ENG-T11: fresh count at
/// fire OR countless copy; this plan does both). The next day with a nonzero
/// due count gets an EXACT-count one-shot; that count is true at fire because
/// dueCountFor(states, day) for a fixed day only changes via ratings, and
/// every rating re-plans. Days after it get COUNTLESS copy; due counts never
/// decrease over days without ratings, so countless copy never lies either.
List<ScheduledReminder> planReminders(
    Map<String, CardState> states, DateTime now) {
  if (states.isEmpty) return const [];

  // First candidate fire slot: today 8pm if still ahead, else tomorrow 8pm.
  var fireAt = DateTime(now.year, now.month, now.day, _reminderHour);
  if (!fireAt.isAfter(now)) fireAt = fireAt.add(const Duration(days: 1));

  // Walk forward to the first fire day with a nonzero due count. At 8pm the
  // study day equals the calendar day (8pm > 4am rollover).
  final fmt = DateFormat('yyyy-MM-dd');
  for (var i = 0; i < 366; i++) {
    final day = fmt.format(fireAt);
    final count = dueCountFor(states, day);
    if (count > 0) {
      return [
        ScheduledReminder(
          id: _oneShotId,
          fireAt: fireAt,
          body: count == 1
              ? '1 answer due today'
              : '$count answers due today',
          repeatsDaily: false,
        ),
        ScheduledReminder(
          id: _repeatId,
          fireAt: fireAt.add(const Duration(days: 1)),
          body: 'Your recall queue has answers due',
          repeatsDaily: true,
        ),
      ];
    }
    fireAt = fireAt.add(const Duration(days: 1));
  }
  return const [];
}

/// Thin executor around flutter_local_notifications. All logic is in
/// planReminders; this class is deliberately dumb glue.
/// ponytail: plugin calls untested (method channel); the planner carries the tests.
class NotificationService {
  NotificationService(this._plugin, this._db);

  final FlutterLocalNotificationsPlugin _plugin;
  final AppDatabase _db;

  static const _channel = AndroidNotificationDetails(
    'daily_reminder',
    'Daily recall reminder',
    channelDescription: 'One reminder when answers are due for recall',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init({required void Function() onTapOpensQueue}) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == queuePayload) onTapOpensQueue();
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Cancel-then-schedule from a fresh plan. Callers (plan 6 wiring): after
  /// every rating, on app background, post-4am-rollover, and on app start.
  Future<void> reschedule({
    required Map<String, CardState> states,
    required DateTime now,
  }) async {
    await _plugin.cancelAll();
    if (!await reminderEnabled()) return;
    for (final r in planReminders(states, now)) {
      await _plugin.zonedSchedule(
        r.id,
        'DiploMate',
        r.body,
        tz.TZDateTime.from(r.fireAt, tz.local),
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: r.repeatsDaily ? DateTimeComponents.time : null,
        payload: queuePayload,
      );
    }
  }

  Future<bool> reminderEnabled() async {
    final row = await (_db.select(_db.localSettings)
          ..where((s) => s.key.equals('reminder_enabled')))
        .getSingleOrNull();
    return row == null || row.value == 'true'; // default On
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _db.into(_db.localSettings).insert(
          LocalSettingsCompanion.insert(
              key: 'reminder_enabled', value: enabled ? 'true' : 'false'),
          mode: InsertMode.insertOrReplace,
        );
    if (!enabled) await _plugin.cancelAll();
  }
}
```

- [ ] **Step 4: Run planner test to verify it passes**

Run: `flutter test test/services/notification_planner_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Write the failing lifecycle-observer test**

Create `app/test/services/study_lifecycle_observer_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/services/study_lifecycle_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resumed fires onResumed (rollover recompute + session_start hook)', () {
    var resumed = 0;
    var paused = 0;
    final obs = StudyLifecycleObserver(
        onResumed: () => resumed++, onPaused: () => paused++);
    obs.didChangeAppLifecycleState(AppLifecycleState.resumed);
    obs.didChangeAppLifecycleState(AppLifecycleState.paused);
    obs.didChangeAppLifecycleState(AppLifecycleState.inactive); // neither
    expect(resumed, 1);
    expect(paused, 1);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/services/study_lifecycle_observer_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:diplomate/services/study_lifecycle_observer.dart'`

- [ ] **Step 7: Write the observer**

Create `app/lib/services/study_lifecycle_observer.dart`:

```dart
import 'package:flutter/widgets.dart';

/// One lifecycle hook for the study loop. Plan 6 registers it in main.dart:
///   onResumed: localDayNotifier.recompute() + studyRepository.recordSessionStartIfIdle()
///   onPaused:  notificationService.reschedule(...)   (fresh count at fire, ENG-T11)
class StudyLifecycleObserver extends WidgetsBindingObserver {
  StudyLifecycleObserver({required this.onResumed, required this.onPaused});

  final void Function() onResumed;
  final void Function() onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
    if (state == AppLifecycleState.paused) onPaused();
  }
}
```

- [ ] **Step 8: Run all study-loop tests together**

Run: `flutter test`
Expected: PASS - every test from Tasks 1-9 (db, migration, local_day, fold, queue, properties, repository, providers, reader controller, debounce widget, planner, observer).

- [ ] **Step 9: Commit**

```bash
git add app/lib/services/ app/test/services/
git commit -m "feat(app): D19 daily reminder fresh-at-fire planner + queue deep-link hook"
```

---

## Coverage

| Source task / lock              | What it requires                                                                                                                                                                                                                                                                                                       | Plan task(s)                                   |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| CEO-T5                          | Rating-tray debounce: exactly one review_event + one queue advance per rating, widget test                                                                                                                                                                                                                             | 8                                              |
| ENG-T9 (drift migration)        | schemaVersion migration test harness from beta build 1                                                                                                                                                                                                                                                                 | 1, 2                                           |
| ENG-T9 (Leitner properties)     | Fold determinism, replay idempotence, bucket+interval carry across wire 'hard' ratings and content updates, unknown-rating skip+log (FSRS forward-compat)                                                                                                                                                              | 4, 5, 6 (db-level content-update carry)        |
| ENG-T9 (4am rollover)           | Foregrounded 4am rollover recomputes queue/Home CTA without restart                                                                                                                                                                                                                                                    | 7, 9 (resume hook)                             |
| ENG-T9 (notification freshness) | Notification count fresh at fire                                                                                                                                                                                                                                                                                       | 9                                              |
| ENG-T11                         | D19 amendment: fresh count at fire via re-schedule on background/rating/post-rollover, or countless copy (this plan: exact count for the next nonzero day + countless daily repeat after)                                                                                                                              | 9                                              |
| DESIGN-T9                       | Notification tap deep-links into Reader queue mode at first due QnA                                                                                                                                                                                                                                                    | 9 (payload + callback; route wiring in plan 6) |
| DESIGN-T4                       | Reader queue mode (overline Suggestion · N of M + auto-advance) vs browse mode (crumb only, rate-then-stay + "Next in topic"); queue = due-only, no new-card injection in v1                                                                                                                                           | 5 (due-only queue), 8 (modes)                  |
| D4                              | Rating persisted to drift before UI ack; idempotent client-generated UUID                                                                                                                                                                                                                                              | 6, 8                                           |
| D9 (amended)                    | app_events: topic_opened, recall_shown, recall_revealed + hidden_ms, recall_rated, session_start (30-min window); NO pack_download events; validity rule metric-side only, no UI countdown                                                                                                                             | 6, 8                                           |
| D10 / D14                       | Exact Leitner math; QnA = atomic recall unit; 4am rollover; queue order                                                                                                                                                                                                                                                | 3, 4, 5                                        |
| D19                             | One daily local notification, opt-out in Account (local_settings), 8:00 pm                                                                                                                                                                                                                                             | 1 (settings table), 9                          |
| Eng test plan rows              | "Rate offline -> force-close -> reopen -> persisted" (app-kill file-db test); "kill app mid-rating - no corrupt SR state" (transactional insert); "double-tap rating"; "queue-complete lands on designed end state"; "day boundary 23:59/00:01/4am deterministic local_day"; "device clock skew - persisted local_day" | 3, 6, 7, 8                                     |

Superseded rows NOT implemented (no-downloads revision): download states, airplane-mode chapter drilling, atomic bundle install, storage full, corrupt pack, bundle-install peak-RSS, pack*download*\* events.

**Out of scope (owned by neighboring plans):**

- `2026-07-04-day1-content-ddl.md` (plan 1): sql/0001+0002 DDL, wire-enum CHECK constraints (the DDL this plan's constants point at).
- `2026-07-04-server-api.md` (plan 2): `/sync/review-events` + `/sync/app-events` endpoints, sql/0003 (review_events/app_events server tables), metrics SQL pack computing the hidden>=10s validity rule, timestamp-skew checks.
- `2026-07-04-ingestion-pipeline.md` (plan 3): content publishing, content_version bumps, fixture chapter.
- `2026-07-04-flutter-shell-screens.md` (plan 4): the Flutter project scaffold, theme tokens/fonts, router + 3-tab shell, the Reader/Home/Topics/Account SCREENS (widgets, copy, toasts, a11y) that bind this plan's controller/providers; Account reminder-row UI.
- `2026-07-04-integration-release.md` (plan 6): SyncService (drains pending\_\* WHERE synced_at IS NULL, backoff + jitter), ContentRepository on-demand fetch + cache, auth state machine, main.dart wiring (real db file, notification init + dueQueue listener + lifecycle observer registration, cold-start getNotificationAppLaunchDetails, router deep-link target), Sentry scrub test.
