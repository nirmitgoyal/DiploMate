import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import 'tables.dart';

part 'app_db.g.dart';

@DriftDatabase(tables: [
  Specialities,
  Chapters,
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // schemaVersion 1 = beta build 1. Future versions add stepwise
          // migrations here; test/db/migration_test.dart verifies each path.
          // v2 (plan 6, Task 4): per-row sync_attempts counter so poison-row
          // drop-after-5 survives restarts (T4). Defaulted 0, so existing rows
          // backfill cleanly.
          if (from < 2) {
            await m.addColumn(
                pendingReviewEvents, pendingReviewEvents.syncAttempts);
            await m.addColumn(pendingAppEvents, pendingAppEvents.syncAttempts);
          }
          // to >= 3 guard: migration_test.dart still pins a historical
          // "migrate to v2" check (to=2) to prove that step in isolation.
          // Without the bound, `from < 3` is also true starting from v1, so
          // this block would run there too and clobber the v2 snapshot that
          // test compares against. Production always requests to ==
          // schemaVersion (3), so the bound never affects a real device.
          if (from < 3 && to >= 3) {
            // Content pass 2026-07-06 (sql/0004 on the server): the pre-v3
            // grouping layer is gone; qnas hang off chapters. Device content
            // tables are CACHE (eng amendment 15) - drop and refetch on demand.
            // Pending review/app events, bookmarks, and local settings are
            // STATE and are untouched (migration_test asserts they survive).
            await m.deleteTable('topics');
            await m.deleteTable('qnas');
            await m.createTable(qnas); // new shape: chapter_id, no legacy group column
            await customStatement('DELETE FROM images');
            await customStatement('DELETE FROM image_blobs');
            await customStatement('DELETE FROM cached_chapters');
          }
        },
      );

  // --- RemoteContentRepository drift helpers (plan 6, Task 3) -------------
  //
  // The wire is the source of truth for display metadata; drift is only the
  // offline read model. `Specialities` has no `hasContent` column - that
  // field is computed server-side (has_content EXISTS query) and is only
  // ever trustworthy fresh off `/manifest`, so `readSpecialities()` takes it
  // as a same-call parameter rather than persisting a column that would go
  // stale the moment a chapter gets content elsewhere.

  /// Upserts `/manifest`'s `specialities[]` (always present) and, when the
  /// caller requested one track (`spec` non-null and the body carries a
  /// scoped `chapters[]`), that track's chapters too. `chapters[]` carries
  /// no `speciality_id` of its own - the wire scopes the whole array to
  /// whichever `?speciality=` was requested, so `spec` supplies it here.
  Future<void> upsertManifest(Map<String, dynamic> manifest, String? spec) async {
    final specialities =
        (manifest['specialities'] as List).cast<Map<String, dynamic>>();
    final chapters = (manifest['chapters'] as List?)?.cast<Map<String, dynamic>>();
    await transaction(() async {
      for (final s in specialities) {
        await into(this.specialities).insertOnConflictUpdate(
          SpecialitiesCompanion.insert(
            id: s['id'] as String,
            name: s['name'] as String,
            examType: s['exam_type'] as String,
            slug: s['slug'] as String,
            sortOrder: Value(s['sort_order'] as int),
          ),
        );
      }
      if (chapters != null && spec != null) {
        for (final c in chapters) {
          await into(this.chapters).insertOnConflictUpdate(
            ChaptersCompanion.insert(
              id: c['id'] as String,
              specialityId: spec,
              title: c['title'] as String,
              slug: c['slug'] as String,
              sortOrder: Value(c['sort_order'] as int),
              examWeight: Value(c['exam_weight'] as int),
              contentVersion: Value(c['content_version'] as int),
            ),
          );
        }
      }
    });
  }

  /// `hasContent` is sourced from the live wire, not persisted - a stale
  /// cached row defaults it false (matches the online-only onboarding step
  /// the brief describes; no schema change, no `schemaVersion` bump).
  Future<List<SpecialityRow>> readSpecialities(
      [Map<String, bool> hasContentBySpecialityId = const {}]) async {
    final rows = await (select(specialities)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return [
      for (final r in rows)
        SpecialityRow(
          id: r.id,
          name: r.name,
          examType: r.examType,
          slug: r.slug,
          sortOrder: r.sortOrder,
          hasContent: hasContentBySpecialityId[r.id] ?? false,
        ),
    ];
  }

  /// `qnaCount` is a manifest-only count (not a drift column); pass the
  /// just-fetched `chapters[]` through so it rides along without a second
  /// round trip. Falls back to a drift `COUNT(*)` when no manifest snapshot
  /// is available (offline read of a previously cached chapter).
  Future<List<ChapterRow>> readChapters(String specialityId,
      [List<Map<String, dynamic>>? manifestChapters]) async {
    final rows = await (select(chapters)
          ..where((t) => t.specialityId.equals(specialityId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final counts = {
      for (final c in manifestChapters ?? const <Map<String, dynamic>>[])
        c['id'] as String: c,
    };
    return [
      for (final r in rows)
        ChapterRow(
          id: r.id,
          specialityId: r.specialityId,
          title: r.title,
          slug: r.slug,
          sortOrder: r.sortOrder,
          examWeight: r.examWeight,
          contentVersion: r.contentVersion,
          qnaCount: counts[r.id]?['qna_count'] as int? ??
              await (select(qnas)..where((q) => q.chapterId.equals(r.id)))
                  .get()
                  .then((v) => v.length),
        ),
    ];
  }

  Future<int?> cachedChapterVersion(String chapterId) async {
    final row = await (select(cachedChapters)
          ..where((t) => t.chapterId.equals(chapterId)))
        .getSingleOrNull();
    return row?.contentVersion;
  }

  Future<int?> manifestChapterVersion(String chapterId) async {
    final row =
        await (select(chapters)..where((t) => t.id.equals(chapterId)))
            .getSingleOrNull();
    return row?.contentVersion;
  }

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

  Future<List<QnaRow>> readQnasByChapter(String chapterId) async {
    final rows = await (select(qnas)
          ..where((q) => q.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .get();
    return [for (final r in rows) await _qnaFromRow(r)];
  }

  Future<QnaRow?> readQna(String qnaId) async {
    final row =
        await (select(qnas)..where((q) => q.id.equals(qnaId))).getSingleOrNull();
    return row == null ? null : _qnaFromRow(row);
  }

  Future<QnaRow> _qnaFromRow(Qna r) async {
    final imgRows = await (select(images)
          ..where((i) => i.qnaId.equals(r.id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return QnaRow(
      id: r.id,
      chapterId: r.chapterId,
      question: r.question,
      years: r.years,
      marks: r.marks,
      earnsMarks: [
        for (final e in (jsonDecode(r.earnsMarks) as List).cast<Map<String, dynamic>>())
          EarnRow(label: e['label'] as String, sectionKey: e['section_key'] as String),
      ],
      sections: [
        for (final s in (jsonDecode(r.sections) as List).cast<Map<String, dynamic>>())
          AnswerSection(
            key: s['key'] as String,
            heading: s['heading'] as String,
            bodyMd: s['body_md'] as String,
            marks: s['marks'] as int?,
          ),
      ],
      sortOrder: r.sortOrder,
      images: [
        for (final i in imgRows)
          ImageRow(
            id: i.id,
            caption: i.caption,
            contentDescription: i.contentDescription,
            byteSize: i.byteSize,
            sha256: i.sha256,
            sortOrder: i.sortOrder,
          ),
      ],
    );
  }

  Future<Uint8List?> readImageBlob(String imageId) async {
    final row = await (select(imageBlobs)
          ..where((t) => t.imageId.equals(imageId)))
        .getSingleOrNull();
    return row?.bytes;
  }

  Future<void> writeImageBlob(String imageId, Uint8List bytes,
      [String sha256 = '']) async {
    await into(imageBlobs).insertOnConflictUpdate(
      ImageBlobsCompanion.insert(imageId: imageId, bytes: bytes, sha256: sha256),
    );
  }

  // --- RemoteSyncService drift helpers (plan 6, Task 4) ------------------
  //
  // Pending = synced_at IS NULL (never deleted on ack today - the Leitner fold
  // reads history - but the flush drain DOES delete on inserted, since a synced
  // row's history lives server-side once accepted). sync_attempts is the
  // durable poison counter: bumped per rejection, the row dropped once it hits
  // the ceiling so a persistently-invalid row can never wedge the queue (T4).

  static const _poisonCeilingAttempts = 5;

  Future<List<PendingReviewEvent>> unsyncedReviewEvents() =>
      (select(pendingReviewEvents)
            ..where((t) => t.syncedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.ratedAt)]))
          .get();

  Future<List<PendingAppEvent>> unsyncedAppEvents() =>
      (select(pendingAppEvents)
            ..where((t) => t.syncedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
          .get();

  Future<void> deleteReviewEventsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(pendingReviewEvents)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> deleteAppEventsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(pendingAppEvents)..where((t) => t.id.isIn(ids))).go();
  }

  /// Bumps sync_attempts on each rejected id, then drops any row that has now
  /// reached the poison ceiling (dropped AFTER the 5th rejection). One
  /// transaction so a crash mid-drain never double-counts.
  Future<void> recordReviewRejections(List<String> ids) =>
      _recordRejections(pendingReviewEvents, ids);

  Future<void> recordAppRejections(List<String> ids) =>
      _recordRejections(pendingAppEvents, ids);

  Future<void> _recordRejections<T extends Table, R>(
      TableInfo<T, R> table, List<String> ids) async {
    if (ids.isEmpty) return;
    await transaction(() async {
      // Drift has no bulk expression-UPDATE across the manager here; per-id is
      // fine at beta scale (a flush rejects a handful of rows at most).
      // ponytail: row-at-a-time, batch if a flush ever rejects thousands.
      for (final id in ids) {
        await customStatement(
          'UPDATE ${table.actualTableName} '
          'SET sync_attempts = sync_attempts + 1 WHERE id = ?',
          [id],
        );
      }
      await customStatement(
        'DELETE FROM ${table.actualTableName} '
        'WHERE id IN (${List.filled(ids.length, '?').join(',')}) '
        'AND sync_attempts >= ?',
        [...ids, _poisonCeilingAttempts],
      );
    });
  }

  /// LWW upsert by content_id (last-writer-wins is enforced by the caller: the
  /// sync merge-back only calls this for rows the server declares newer).
  Future<void> upsertBookmark(
          String contentId, DateTime updatedAt, bool deleted) =>
      into(bookmarks).insertOnConflictUpdate(BookmarksCompanion.insert(
        contentId: contentId,
        updatedAt: updatedAt,
        deleted: Value(deleted),
      ));

  Future<List<Bookmark>> readBookmarkRows() => select(bookmarks).get();

  Future<String?> readSetting(String key) async {
    final row = await (select(localSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) =>
      (select(localSettings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> writeSetting(String key, String value) =>
      into(localSettings).insert(
        LocalSettingsCompanion.insert(key: key, value: value),
        mode: InsertMode.insertOrReplace,
      );
}
