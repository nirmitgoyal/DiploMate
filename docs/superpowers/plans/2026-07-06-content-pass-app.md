# Content Pass Lane C: App Rewrites (Drift v3, Flattened Nav, chapter_opened, Upgrade Gate) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the topics nav level from the Flutter app: drift schema v3 (topics table gone, `qnas.chapter_id`), syllabus chapter rows open the Reader directly (one fewer tap), the app emits `chapter_opened` with the chapter ULID on chapter open, stale clients hit an upgrade gate when `min_app_version` outruns them, and recall/queue/bookmark state SURVIVES the migration.

**Architecture:** Content tables in drift are CACHE (eng amendment 15): the v2-to-v3 migration drops `topics`, rebuilds `qnas` in the new shape, and empties the image/cache tables so content refetches on demand; the pending-event, bookmark, and settings tables are untouched and a migration test proves it. Nav flattens by deleting `TopicsScreen` and giving `ReaderScreen` a chapter entry mode that ensures the cache, emits `chapter_opened`, and browses the chapter's qnas. This is eng-review tasks T4 (app half), T6 (drift knob), T11 (app half), and the app slices of T10.

**Tech Stack:** Flutter + Riverpod + go_router + drift (`drift_dev` schema verifier), `flutter test`.

**Source of truth:** design doc `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-claude-jolly-banach-f5aef8-design-20260706-134407.md` - the "ENG REVIEW AMENDMENTS (2026-07-06)" section SUPERSEDES the doc body wherever they conflict.

## Global Constraints

Every task's requirements implicitly include these.

- NEVER use em-dashes or en-dashes in any file, code, comment, UI copy, or doc; plain hyphens only (user convention).
- **Drift version correction:** the design doc says "drift v1 to v2", but main already shipped drift `schemaVersion => 2` (plan 6 `sync_attempts`, [app_db.dart:27](app/lib/data/db/app_db.dart)). This lane bumps **2 to 3**. The amendment SEMANTICS are unchanged: content tables are cache (drop + refetch); review/queue/bookmark state untouched and test-asserted.
- v2 wire contract this lane consumes (defined in lane A - copy exactly):
  - `GET /manifest`: `{schema_version: 2, min_app_version: 2, specialities: [...]}`; with `?speciality=` also `chapters: [{id, title, slug, sort_order, exam_weight, content_version, qna_count}]` - NO `topic_count`, zero-qna chapters excluded server-side.
  - `GET /chapters/:chapterId/qnas`: `{chapter_id, content_version, schema_version: 2, page, pages, items: [{id, chapter_id, question, years, marks, earns_marks, sections, sort_order, images: [...]}]}` - NO `topics` key.
- Event rename (amendment 4): the app emits **`chapter_opened`** (content_id = chapter ULID) when a chapter is opened. `topic_opened` is never emitted by this app version; it survives only in the wire-enum mirror comment.
- Identity: `review_events`/bookmarks hang off QnA ULIDs; nothing in this lane may translate, regenerate, or drop a content_id.
- Read `DESIGN.md` before UI edits. The two signature moves (answer-on-white, examiner's red margin) and the color laws are untouched by this lane. DESIGN.md's topic-level clauses are SUPERSEDED by the founder-approved content-pass design; Task 7 syncs DESIGN.md so code and doc agree (per project CLAUDE.md, QA flags any mismatch).
- Upgrade gate (amendment 10): the app pins `kSupportedSchemaVersion = 2`; a manifest with `min_app_version > 2` renders a blocking "update required" state, never a parse error.
- Identifier-level sweep (amendment 14): after this lane, `grep -rniE 'topic_id|topic_count|topicId|topics?\b' app/lib app/test | grep -viE 'topical|topic_opened'` returns zero lines (`topic_opened` may appear ONLY in the wire-enum mirror comment in `models.dart`).
- TDD per task: failing test first, run it (expect FAIL with the stated reason), minimal implementation, run again (expect PASS), commit. Conventional commits.

**Working directory:** all `flutter`/`dart` commands run from `/Users/nirmit/Codebases/DiploMate/app/`. Git commits from the repo root.

**Suite-red window:** Task 1's model change breaks compilation across the app until Tasks 2-6 land. Work on one branch; the suite is required green at Task 7. Do not merge mid-way.

**Execution order across lanes:** lane C runs in parallel with A and B in separate worktrees (superpowers:using-git-worktrees) - it depends only on the WRITTEN v2 wire contract above, not on lane A's code.

---

### Task 1: `models.dart` v2 - QnaRow by chapter, TopicRow deleted

**Files:**

- Modify: `app/lib/domain/models.dart`

**Interfaces:**

- Produces (every later task consumes these): `ChapterRow` WITHOUT `topicCount` (keeps `qnaCount`, `recalledCount` semantics move to question grain); `QnaRow.chapterId` (was `topicId`); `TopicRow` DELETED; `AppEvent.eventType` comment lists `chapter_opened | recall_shown | recall_revealed | recall_rated | session_start` (with a `topic_opened` retained-in-DB-CHECK note).

- [ ] **Step 1: Edit the three model classes**

In `app/lib/domain/models.dart`:

- `ChapterRow` (line ~17): delete the `topicCount` constructor parameter and field; keep `qnaCount` and every other field exactly as they are.
- Delete the whole `TopicRow` class (line ~35).
- `QnaRow` (line ~75): rename the `topicId` parameter and field to `chapterId` (type stays `String`).
- `AppEvent.eventType` comment (line ~139) becomes:

```dart
  final String eventType; // chapter_opened | recall_shown | recall_revealed | recall_rated | session_start
  // (topic_opened stays legal in the sql/0004 CHECK for back-compat; this app never emits it.)
```

- [ ] **Step 2: Observe the compile breakage (the "failing test" for a model change)**

Run: `flutter analyze lib/domain/models.dart`
Expected: models.dart itself analyzes clean. `flutter analyze` on the whole package now reports errors in `app_db.dart`, `tables.dart`, repositories, and screens - the worklist Tasks 2-6 burn down.

- [ ] **Step 3: Commit**

```bash
git add app/lib/domain/models.dart
git commit -m "feat(app): models v2 - QnaRow.chapterId, TopicRow removed, chapter_opened event"
```

---

### Task 2: drift v3 - schema, migration, and the state-survival test

**Files:**

- Modify: `app/lib/data/db/tables.dart`
- Modify: `app/lib/data/db/app_db.dart`
- Regenerate: `app/lib/data/db/app_db.g.dart`, `app/drift_schemas/drift_schema_v3.json`, `app/test/db/generated/*`
- Test: `app/test/db/migration_test.dart`

**Interfaces:**

- Consumes: models v2 (Task 1).
- Produces: `AppDatabase` at `schemaVersion => 3`; drift helpers `readChapters(specialityId, [manifestChapters])` (qnaCount only), `replaceChapterContent(chapterId, version, items)` (no topics param), `readQnasByChapter(chapterId)`, `readQna(qnaId)`; `readTopics`/`readQnas(topicId)` GONE. Tasks 3-6 consume these.

- [ ] **Step 1: Edit `tables.dart`**

- Delete the whole `Topics` table class.
- In `Qnas`, replace `TextColumn get topicId => text()();` with `TextColumn get chapterId => text()();`.

- [ ] **Step 2: Edit `app_db.dart` - table list, version, migration**

- Remove `Topics` from the `@DriftDatabase(tables: [...])` list.
- `schemaVersion` becomes `3`.
- Extend `onUpgrade` (the existing `from < 2` block stays first):

```dart
          if (from < 3) {
            // Content pass 2026-07-06 (sql/0004 on the server): topics layer
            // removed; qnas hang off chapters. Device content tables are
            // CACHE (eng amendment 15) - drop and refetch on demand. Pending
            // review/app events, bookmarks, and local settings are STATE and
            // are untouched (migration_test asserts they survive).
            await m.deleteTable('topics');
            await m.deleteTable('qnas');
            await m.createTable(qnas); // new shape: chapter_id, no topic_id
            await customStatement('DELETE FROM images');
            await customStatement('DELETE FROM image_blobs');
            await customStatement('DELETE FROM cached_chapters');
          }
```

- [ ] **Step 3: Rewrite the drift content helpers in `app_db.dart`**

- `readChapters`: delete the `topicCount:` argument and its fallback subquery entirely; the `qnaCount` fallback becomes a direct chapter query:

```dart
          qnaCount: counts[r.id]?['qna_count'] as int? ??
              await (select(qnas)..where((q) => q.chapterId.equals(r.id)))
                  .get()
                  .then((v) => v.length),
```

- `replaceChapterContent` loses the `topics` parameter and its topic writes; the purge scopes by `chapterId` directly:

```dart
  /// One transaction per chapter refresh: replaces every qna/image scoped to
  /// `chapterId`, then marks the chapter cached at `version`.
  Future<void> replaceChapterContent(
      String chapterId, int version, List<Map<String, dynamic>> items) async {
    await transaction(() async {
      final qnaIds = await (select(qnas)
            ..where((q) => q.chapterId.equals(chapterId)))
          .map((q) => q.id)
          .get();
      if (qnaIds.isNotEmpty) {
        // Purge cached bytes too, not just metadata: under stable ULIDs a
        // reused image id with changed bytes would otherwise serve the OLD
        // blob forever. Same transaction = atomic swap.
        final imageIds = await (select(images)
              ..where((i) => i.qnaId.isIn(qnaIds)))
            .map((i) => i.id)
            .get();
        if (imageIds.isNotEmpty) {
          await (delete(imageBlobs)..where((b) => b.imageId.isIn(imageIds)))
              .go();
        }
        await (delete(images)..where((i) => i.qnaId.isIn(qnaIds))).go();
        await (delete(qnas)..where((q) => q.chapterId.equals(chapterId))).go();
      }

      for (final q in items) {
        await into(qnas).insertOnConflictUpdate(
          QnasCompanion.insert(
            id: q['id'] as String,
            chapterId: q['chapter_id'] as String,
            question: q['question'] as String,
            years: Value(q['years'] as String?),
            marks: Value(q['marks'] as int?),
            earnsMarks: jsonEncode(q['earns_marks']),
            sections: jsonEncode(q['sections']),
            sortOrder: Value(q['sort_order'] as int),
          ),
        );
        for (final i in (q['images'] as List).cast<Map<String, dynamic>>()) {
          await into(images).insertOnConflictUpdate(
            ImagesCompanion.insert(
              id: i['id'] as String,
              qnaId: q['id'] as String,
              caption: i['caption'] as String,
              contentDescription: i['content_description'] as String,
              byteSize: i['byte_size'] as int,
              sha256: i['sha256'] as String,
              sortOrder: Value(i['sort_order'] as int),
            ),
          );
        }
      }

      await into(cachedChapters).insertOnConflictUpdate(
        CachedChaptersCompanion.insert(
          chapterId: chapterId,
          contentVersion: version,
          cachedAt: DateTime.now(),
        ),
      );
    });
  }
```

- Delete `readTopics` entirely; replace `readQnas(String topicId)` with:

```dart
  Future<List<QnaRow>> readQnasByChapter(String chapterId) async {
    final rows = await (select(qnas)
          ..where((q) => q.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .get();
    return [for (final r in rows) await _qnaFromRow(r)];
  }
```

- In `_qnaFromRow`, `topicId: r.topicId` becomes `chapterId: r.chapterId`.

- [ ] **Step 4: Regenerate drift code and dump the v3 schema**

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/data/db/app_db.dart drift_schemas/drift_schema_v3.json
dart run drift_dev schema generate drift_schemas/ test/db/generated/
```

Expected: `app_db.g.dart` regenerates (Topics classes gone, `QnasCompanion.insert` now requires `chapterId`); `drift_schema_v3.json` appears; `test/db/generated/` gains `schema_v3.dart` and `schema.dart` now spans v1-v3.

- [ ] **Step 5: Write the failing migration tests**

Append to `app/test/db/migration_test.dart` (keep the existing v1-to-v2 tests; update the file's stale header comment to mention v3):

```dart
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
```

- [ ] **Step 6: Run the db tests**

Run: `flutter test test/db/`
Expected: PASS (if the raw column list in an INSERT disagrees with the dumped v2 snapshot - e.g. a default you forgot - the sqlite error names the column; fix the INSERT, not the schema).

- [ ] **Step 7: Commit**

```bash
git add app/lib/data/db app/drift_schemas app/test/db
git commit -m "feat(app): drift v3 - topics dropped, qnas by chapter_id, state survives migration"
```

---

### Task 3: ContentRepository v2 - interface, remote, fixture, asset

**Files:**

- Modify: `app/lib/data/repos/content_repository.dart`
- Modify: `app/lib/data/remote/remote_content_repository.dart`
- Modify: `app/lib/data/fixtures/fixture_content_repository.dart`
- Modify: `app/assets/fixtures/chapter_airway.json`
- Test: `app/test/data/fixture_content_repository_test.dart`, `app/test/remote/remote_content_repository_test.dart`

**Interfaces:**

- Consumes: drift v3 helpers (Task 2); v2 wire contract (Global Constraints).
- Produces: `ContentRepository` WITHOUT `topics()`; `qnas(String chapterId)` (by chapter, was by topic). Screens (Tasks 5-6) consume this.

- [ ] **Step 1: Edit the interface**

In `app/lib/data/repos/content_repository.dart`, delete the `topics` method and re-key `qnas`:

```dart
abstract class ContentRepository {
  Future<List<SpecialityRow>> specialities();
  Future<List<ChapterRow>> chapters(String specialityId);
  Future<void> ensureChapterCached(String chapterId);
  Future<List<QnaRow>> qnas(String chapterId);
  Future<QnaRow?> qna(String qnaId);
  Future<Uint8List> imageBytes(String imageId);
}
```

- [ ] **Step 2: Update the remote repository**

In `app/lib/data/remote/remote_content_repository.dart`:

- delete the `topics(...)` override;
- `qnas` becomes `Future<List<QnaRow>> qnas(String chapterId) => db.readQnasByChapter(chapterId);`
- in `ensureChapterCached`, delete the `var topics = ...` accumulator, the `topics = ((body['topics'] ...` line and its comment, and pass three args: `await db.replaceChapterContent(chapterId, version, items);`

- [ ] **Step 3: Update the fixture asset and repository**

`app/assets/fixtures/chapter_airway.json`: delete the top-level `topics` array; on every entry in `qnas`, replace `"topic_id": "<the topic's id>"` with `"chapter_id": "<that topic's chapter_id value>"` (all fixture topics belong to the one airway chapter, so every qna gets that chapter's id). No other key changes.

`app/lib/data/fixtures/fixture_content_repository.dart`: delete the `topics()` override; rewrite `qnas` to filter by chapter (self-contained - adapt the row-building to the file's existing QnaRow mapper):

```dart
  @override
  Future<List<QnaRow>> qnas(String chapterId) async {
    final doc = await _load();
    final rows = (doc['qnas'] as List)
        .cast<Map<String, dynamic>>()
        .where((q) => q['chapter_id'] == chapterId)
        .toList();
    return [for (final q in rows) _qnaRowFrom(q)];
  }
```

where `_qnaRowFrom` is the file's existing qna-map-to-QnaRow conversion (rename/extract it if it is currently inline; set `chapterId: q['chapter_id'] as String`). If the fixture repo computes chapter `topicCount`, delete that; `qnaCount` counts the chapter's qnas.

- [ ] **Step 4: Update the two repository test files**

- `fixture_content_repository_test.dart`: replace `repo.topics(...)`/`repo.qnas(topicId)` calls with `repo.qnas(chapterId)` using the fixture chapter id (`01J0CHAPAIRWAY000000000001` per the old topics test); assert the two airway qnas come back ordered and `qna.chapterId` equals the chapter id; delete topic-count assertions.
- `remote_content_repository_test.dart`: update its fake wire payloads to the v2 shape (no `topics` key, items carry `chapter_id`, `schema_version: 2`) and any `replaceChapterContent`/`topics()` expectations accordingly. The offline-fallback and cache-version tests keep their logic - only payload shapes change.

- [ ] **Step 5: Run the data/remote tests**

Run: `flutter test test/data/ test/remote/`
Expected: PASS. (`test/remote/wiring_test.dart` and others may still fail on screens - later tasks.)

- [ ] **Step 6: Commit**

```bash
git add app/lib/data app/assets/fixtures/chapter_airway.json app/test/data app/test/remote
git commit -m "feat(app): ContentRepository v2 - qnas by chapter, topics gone, v2 fixture asset"
```

---

### Task 4: min_app_version upgrade gate (stale client sees a gate, not a parse error)

**Files:**

- Modify: `app/lib/data/repos/content_repository.dart` (exception + supported-version pin)
- Modify: `app/lib/data/remote/remote_content_repository.dart` (the check)
- Modify: `app/lib/ui/syllabus/syllabus_screen.dart`, `app/lib/ui/speciality/speciality_screen.dart` (blocking state)
- Test: `app/test/remote/remote_content_repository_test.dart`

**Interfaces:**

- Consumes: `_refreshManifest` (Task 3) - the single choke point every manifest read passes through.
- Produces: `UpgradeRequiredException`; `kSupportedSchemaVersion = 2`; screens render "Update DiploMate to continue" on it.

- [ ] **Step 1: Write the failing test**

In `app/test/remote/remote_content_repository_test.dart`, add (mirroring the file's existing fake-dio harness):

```dart
  test('manifest min_app_version above the supported pin throws UpgradeRequiredException', () async {
    // Arrange the fake /manifest response with min_app_version: 3.
    // (Use the file's existing fake adapter; only the body differs.)
    // body: {'schema_version': 2, 'min_app_version': 3, 'specialities': []}
    await expectLater(repo.specialities(), throwsA(isA<UpgradeRequiredException>()));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/remote/remote_content_repository_test.dart`
Expected: FAIL - `UpgradeRequiredException` is undefined.

- [ ] **Step 3: Implement the gate**

In `content_repository.dart`:

```dart
/// The newest wire schema this build understands. The server's
/// min_app_version outrunning it means: block with an upgrade prompt
/// (amendment 10) - never attempt to parse a newer shape.
const kSupportedSchemaVersion = 2;

class UpgradeRequiredException implements Exception {}
```

In `remote_content_repository.dart` `_refreshManifest`, right after `final manifest = res.data as Map<String, dynamic>;`:

```dart
    if ((manifest['min_app_version'] as int? ?? 1) > kSupportedSchemaVersion) {
      throw UpgradeRequiredException();
    }
```

(It is not a `DioException`, so every existing `on DioException` handler lets it propagate to the screen.)

- [ ] **Step 4: Blocking state on the two fetching screens**

In `syllabus_screen.dart` and `speciality_screen.dart`, the fetch `catchError` currently collapses everything to a retry state. Split it: add a `bool _upgrade = false;` field; in the catch, `if (e is UpgradeRequiredException) { setState(() { _upgrade = true; _loading = false; }); return; }` (match each screen's existing catch shape); in `_body`, before the error branch:

```dart
    if (_upgrade) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DmSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Update DiploMate to continue',
                  style: DmType.bodyUi.copyWith(color: context.dm.ink)),
              const SizedBox(height: DmSpace.sm),
              Text('This version is too old for the current content format.',
                  style: DmType.meta.copyWith(color: context.dm.ink2),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
```

(Note: `catchError((_) {...})` swallows the error type - change those closures to `catchError((e) {...})` so the type test works. No retry button: the gate is deliberately blocking.)

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/remote/remote_content_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/data app/lib/ui/syllabus app/lib/ui/speciality app/test/remote
git commit -m "feat(app): min_app_version upgrade gate - stale client blocks, never parse-errors"
```

---

### Task 5: nav flattening - topics screen deleted, syllabus opens the Reader

**Files:**

- Delete: `app/lib/ui/topics/topics_screen.dart`, `app/test/ui/topics_screen_test.dart`
- Modify: `app/lib/router.dart`
- Modify: `app/lib/ui/syllabus/syllabus_screen.dart`
- Modify: `app/lib/ui/home/home_screen.dart`
- Modify: `app/lib/ui/bookmarks/bookmarks_screen.dart`
- Test: `app/test/shell/router_test.dart`, `app/test/ui/syllabus_screen_test.dart`, `app/test/ui/bookmarks_screen_test.dart`

**Interfaces:**

- Consumes: `ContentRepository.qnas(chapterId)` (Task 3).
- Produces: routes `/reader/chapter/:chapterId` (chapter entry) and `/reader/:qnaId?chapter=<id>` (browse); NO `/syllabus/topics/...` route. Task 6 implements the `ReaderScreen.chapter` constructor these routes reference - Tasks 5 and 6 compile together; run their tests at the end of Task 6 (nav regression pass).

- [ ] **Step 1: Router rewrite**

In `app/lib/router.dart`: delete the `topics_screen.dart` import and the nested `topics/:chapterId` route under `/syllabus`; replace the reader routes (ORDER MATTERS - the literal `chapter` segment must be registered before the `:qnaId` parameter route):

```dart
      GoRoute(
          path: '/reader/queue',
          builder: (_, __) => const ReaderScreen.queue()),
      GoRoute(
          path: '/reader/chapter/:chapterId',
          builder: (_, s) => ReaderScreen.chapter(
              chapterId: s.pathParameters['chapterId']!)),
      GoRoute(
          path: '/reader/:qnaId',
          builder: (_, s) => ReaderScreen.browse(
              qnaId: s.pathParameters['qnaId']!,
              chapterId: s.uri.queryParameters['chapter'])),
```

and the syllabus branch loses its nested route:

```dart
          StatefulShellBranch(routes: [
            GoRoute(path: '/syllabus', builder: (_, __) => const SyllabusScreen()),
          ]),
```

- [ ] **Step 2: Syllabus row - one fewer tap + question-count subtitle**

In `syllabus_screen.dart` `_ChapterRow`:

- `onTap: () => context.go('/syllabus/topics/${chapter.id}')` becomes `onTap: () => context.go('/reader/chapter/${chapter.id}')`
- the subtitle `Text('${chapter.topicCount} topics', ...)` becomes `Text('${chapter.qnaCount} questions', ...)`
- the progress fraction `chapter.recalledCount / chapter.topicCount` becomes `chapter.recalledCount / chapter.qnaCount` (recall progress is per-question now - same signal, finer grain).

- [ ] **Step 3: Home resume + bookmarks call sites**

- `home_screen.dart`: `context.go('/syllabus/topics/${resume.id}')` (line ~115) becomes `context.go('/reader/chapter/${resume.id}')`. The resume row renders `resume.title` (the chapter title) only - it carries NO "Topic N of M" copy - so the onTap is the sole change. `resumeChapterProvider` reads only chapter-level fields (`examWeight`, `title`), so it needs no edit.
- `bookmarks_screen.dart`: `context.go('/reader/${row.qna.id}?topic=${row.qna.topicId}')` becomes `context.go('/reader/${row.qna.id}?chapter=${row.qna.chapterId}')`. The row model drops `topicTitle` (constructor + field + the `Chapter · Topic` source line renders the chapter title alone); the title-resolution loop that scanned `repo.topics(c.id)` per chapter is deleted - `row.qna.chapterId` looks the chapter up directly from `repo.chapters(spec.id)`.
- Delete the now-dead `topicPipProvider` if anything besides the deleted screen referenced it (grep; expected: nothing).

- [ ] **Step 4: Delete the topics screen and its test**

```bash
git rm app/lib/ui/topics/topics_screen.dart app/test/ui/topics_screen_test.dart
```

- [ ] **Step 5: Update the nav tests (they run at end of Task 6)**

- `router_test.dart`: delete any `/syllabus/topics/...` expectation; add the two assertions of the nav regression (IRON RULE rewrite 3 of 4):

```dart
  test('no route to a topics screen exists', () {
    final router = /* the file's existing router-under-test construction */;
    expect(
      () => router.configuration.findMatch(Uri.parse('/syllabus/topics/CH1')),
      // go_router resolves unknown paths to the error match - assert no
      // TopicsScreen route is configured rather than a throw if the file's
      // harness prefers; the point is: the path no longer matches a screen.
      returnsNormally,
    );
    expect(
        router.configuration.routes.toString().contains('topics'), isFalse);
  });
```

(adapt to the file's existing harness style - it already builds `buildRouter` through a ProviderContainer; the load-bearing assertion is the second one.)

- `syllabus_screen_test.dart`: subtitle expectation `'N topics'` becomes `'N questions'`; the row-tap test's expected destination becomes `/reader/chapter/<id>`.
- `bookmarks_screen_test.dart`: source-line expectation drops the topic segment; the tap destination gains `?chapter=`.

- [ ] **Step 6: Commit (compile checkpoint)**

Run `flutter analyze` - remaining errors must ONLY be in `reader_*` files (Task 6's worklist). Then:

```bash
git add -A app/lib app/test
git commit -m "feat(app): topics nav level removed - syllabus opens reader, one fewer tap"
```

---

### Task 6: Reader chapter entry + `chapter_opened` emission (IRON RULE rewrites 3+4, app half)

**Files:**

- Modify: `app/lib/ui/reader/reader_screen.dart`
- Modify: `app/lib/ui/reader/reader_controller.dart`
- Modify: `app/lib/ui/reader/reader_view.dart`
- Create: `app/test/ui/reader/reader_chapter_entry_test.dart`
- Modify: `app/test/ui/reader/reader_controller_test.dart`, `app/test/ui/reader_surface_test.dart`, `app/test/ui/reader_actions_test.dart`, `app/test/ui/reader/reader_queue_wiring_test.dart` (rename fallout only)

**Interfaces:**

- Consumes: `qnas(chapterId)`, routes from Task 5, `studyRepositoryProvider` (`app/lib/providers/study_providers.dart:25`).
- Produces: `ReaderScreen.chapter({required String chapterId})`; `ReaderController.browse({repo, qnaId, chapterQnaIds})`; `hasNextInChapter`/`nextInChapter`; UI copy "Next in chapter"; `chapter_opened` app event (content_id = chapter ULID) recorded exactly once per chapter open.

- [ ] **Step 1: Controller renames**

In `reader_controller.dart` (pure renames, logic untouched): constructor param `topicQnaIds` becomes `chapterQnaIds`; `hasNextInTopic` becomes `hasNextInChapter`; `nextInTopic()` becomes `nextInChapter()`; the class docstring's "opened from Topics/Bookmarks" becomes "opened from Syllabus/Bookmarks - crumb only, rate-then-stay + Next in chapter"; the assert message becomes `'qnaId must be in chapterQnaIds'`.

- [ ] **Step 2: Reader screen - chapter entry mode**

In `reader_screen.dart`:

- Constructors: `browse` re-keys to chapter and a new `chapter` entry appears:

```dart
  const ReaderScreen.browse({super.key, required this.qnaId, this.chapterId})
      : mode = ReaderMode.browse,
        entryChapterId = null;

  const ReaderScreen.queue({super.key})
      : mode = ReaderMode.queue,
        qnaId = null,
        chapterId = null,
        entryChapterId = null;

  /// Chapter entry (2026-07-06 content pass): the syllabus row lands HERE -
  /// ensure the chapter is cached, record chapter_opened, browse from the
  /// first question.
  const ReaderScreen.chapter({super.key, required String chapterId})
      : mode = ReaderMode.browse,
        qnaId = null,
        chapterId = chapterId,
        entryChapterId = chapterId;

  final String? qnaId;
  final String? chapterId;
  final String? entryChapterId; // non-null only for chapter entry
```

- The browse `_load()` flow (adapt the existing one; renames `_topicQnas` to `_chapterQnas`, `_topicTitle` deleted):
  1. `await repo.ensureChapterCached(widget.chapterId!)` when `chapterId` is known (chapter entry ALWAYS; deep-linked browse when the query param is present); keep the existing error handling around it.
  2. Chapter entry only - record activation BEFORE building the controller (fire-and-forget, same pattern as `recall_shown`):

```dart
      if (widget.entryChapterId != null) {
        ref.read(studyRepositoryProvider).recordAppEvent(
            eventType: 'chapter_opened', contentId: widget.entryChapterId);
      }
```

3. Load the browse set: `final chapterQnas = widget.chapterId == null ? const <QnaRow>[] : await repo.qnas(widget.chapterId!);` - the OLD ancestor walk over `repo.topics(c.id)` is deleted wholesale.
4. Resolve the crumb title directly: find the chapter in `await repo.chapters(spec.id)` (the screen already resolves `spec` the same way the deleted topics screen did) - `_chapterTitle`/`_chapterId` fields survive, `_topicTitle` dies.
5. Starting qna: `widget.qnaId ?? chapterQnas.first.id`; controller:

```dart
        _controller = ReaderController.browse(
          repo: ref.read(studyRepositoryProvider),
          qnaId: startId,
          chapterQnaIds:
              chapterQnas.isEmpty ? [startId] : [for (final q in chapterQnas) q.id],
        );
```

- Crumb row: the chapter crumb's tap goes to `'/syllabus'` (the topics screen it used to open is gone); delete the `_topicTitle` crumb entirely.
- Every `nextInTopic`/`hasNextInTopic` call site follows the Step 1 renames.

- [ ] **Step 3: Reader view copy**

In `reader_view.dart`: `onNextInTopic` becomes `onNextInChapter` (param + field + call site) and the button label `'Next in topic'` becomes `'Next in chapter'`.

- [ ] **Step 4: Write the chapter-entry regression test (metrics continuity, app half)**

Create `app/test/ui/reader/reader_chapter_entry_test.dart`. Harness: mirror the deleted `topics_screen_test.dart` host pattern (ProviderScope + fixture repo + `MaterialApp`), overriding `appDatabaseProvider` with an in-memory db so the REAL `StudyRepository` records the event:

```dart
import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterId = '01J0CHAPAIRWAY000000000001';

void main() {
  testWidgets('opening a chapter records chapter_opened with the chapter ULID and shows question 1',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ReaderScreen.chapter(chapterId: _chapterId)),
    ));
    await t.pumpAndSettle();

    // Nav regression: chapter entry lands on the reader, first question visible.
    expect(find.text('Airway Management'), findsWidgets);
    expect(find.textContaining('Question 1 of'), findsOneWidget);

    // Metrics regression (rewrite 4, app half): the activation event exists,
    // renamed, carrying the CHAPTER ULID.
    final events = await db.unsyncedAppEvents();
    final opened = events.where((e) => e.eventType == 'chapter_opened').toList();
    expect(opened, hasLength(1));
    expect(opened.single.contentId, _chapterId);
  });
}
```

(If the reader's overline copy for browse mode differs from `Question 1 of N`, align the overline in `reader_view.dart` to `Question i of N` - the design's grain rename - and keep the assertion. If `appDatabaseProvider` lives behind an override the app normally supplies in `main.dart`, this direct override is exactly how `study_repository_test.dart` already does it - copy that harness detail.)

- [ ] **Step 5: Rename fallout in the four existing reader test files**

`reader_controller_test.dart`, `reader_surface_test.dart`, `reader_actions_test.dart`, `reader_queue_wiring_test.dart`: apply the Step 1-3 renames (`topicQnaIds` to `chapterQnaIds`, `nextInTopic` to `nextInChapter`, `'Next in topic'` to `'Next in chapter'`, `?topic=` to `?chapter=`, `repo.qnas(topicId)` to `repo.qnas(chapterId)` with the fixture's chapter id). Behavior assertions stay identical - these are the browse/queue regression suites proving rate-then-stay, debounce, and auto-advance still hold.

- [ ] **Step 6: Run the full UI test set**

Run: `flutter test test/ui/ test/shell/`
Expected: ALL PASS - including the Task 5 test edits (router, syllabus, bookmarks) that could not run before this task compiled.

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui app/test/ui app/test/shell
git commit -m "feat(app): reader chapter entry - chapter_opened emission, Next in chapter, browse by chapter"
```

---

### Task 7: DESIGN.md sync + full suite + sweep

**Files:**

- Modify: `DESIGN.md`

**Interfaces:**

- Consumes: everything above. Per project CLAUDE.md, DESIGN.md is the UI law book and QA flags code that disagrees with it - this task makes the law match the founder-approved structure change.

- [ ] **Step 1: Edit the topic-level clauses (surgical - only clauses the structure change invalidates)**

In `DESIGN.md`:

- Screen anatomy list: delete the `Topics` entry (item 5); the Syllabus entry's description becomes "chapter rows: title, question count in the subtitle, recall progress; tapping a chapter opens the Reader on its first question".
- **Syllabus row contract:** `N topics` subtitle becomes `N questions` (qna_count); everything else (touch target, progress signal) unchanged.
- **Chapter tap contract:** "tapping ANY chapter row navigates to Topics" becomes "tapping ANY chapter row opens the Reader in browse mode on the chapter's first question. Content is fetched on demand on entry; while fetching, the Reader shows its loading state."
- Reader crumb/overline clause: `chapter title + Topic i of N · <topic title>` becomes `chapter title + Question i of N`.
- Bookmarks row source line: `Chapter · Topic` becomes the chapter title alone.
- Any `Next in topic` copy becomes `Next in chapter`.
- Navigation-structure paragraph (stack children): "Topics under Syllabus" is deleted; Bookmarks under Home stays.
- Append a changelog row:

```
| 2026-07-06 | Topics nav level removed (content pass): syllabus chapter rows open the Reader directly (one fewer tap); subtitle = question count; crumb "Question i of N"; "Next in chapter"; activation event = chapter_opened on chapter open | Founder-approved book-grounded content pass (design doc jolly-banach-f5aef8 + eng amendments): chapters mirror Miller's own chapter list, questions hang directly off chapters |
```

- The two signature moves and all color/type/motion laws are NOT touched.

- [ ] **Step 2: Full app suite**

Run: `flutter test`
Expected: ALL PASS. Any straggler failure names a file with a leftover topic reference - fix the reference, not the test.

- [ ] **Step 3: Lane sweep**

```bash
grep -rniE 'topic_id|topic_count|topicId|topics?\b' app/lib app/test | grep -viE 'topical|topic_opened'
```

Expected: zero lines. (`topic_opened` appears only in the `models.dart` mirror comment, which the filter exempts.)

- [ ] **Step 4: Commit**

```bash
git add DESIGN.md
git commit -m "docs(design): sync DESIGN.md to flattened syllabus-to-reader nav (content pass 2026-07-06)"
```

---

## Self-review checklist (run before handing the lane off)

- Drift migration test proves: state rows survive v2-to-v3, content cache empty, topics table absent.
- `chapter_opened` is recorded with the CHAPTER ULID exactly once per chapter open (widget test) - the wire enum matches `sql/0004`'s CHECK and `server/src/lib/constants.js`.
- A stale client against `min_app_version: 3` blocks with copy, no parse attempt.
- `/syllabus/topics/*` matches nothing; syllabus tap reaches the Reader with the fixture's first airway question.
- DESIGN.md changelog row present; no remaining "topic" contract clause.
- `flutter analyze` clean; full `flutter test` green; sweep grep empty.
