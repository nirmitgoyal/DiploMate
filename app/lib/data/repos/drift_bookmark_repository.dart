import 'package:drift/drift.dart';

import '../db/app_db.dart';
import 'bookmark_repository.dart';

class DriftBookmarkRepository implements BookmarkRepository {
  DriftBookmarkRepository(this._db, {required DateTime Function() now})
      : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<List<BookmarkEntry>> entries() => (_db.select(_db.bookmarks)
        ..where((row) => row.deleted.equals(false))
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
      .watch()
      .map((rows) => [
            for (final row in rows)
              BookmarkEntry(contentId: row.contentId, updatedAt: row.updatedAt),
          ]);

  @override
  Stream<Set<String>> bookmarkedIds() =>
      entries().map((rows) => rows.map((row) => row.contentId).toSet());

  @override
  Future<void> toggle(String contentId) => _db.transaction(() async {
        final previous = await (_db.select(_db.bookmarks)
              ..where((row) => row.contentId.equals(contentId)))
            .getSingleOrNull();
        var updatedAt = _now();
        if (previous != null) {
          // Drift stores seconds; even two toggles in one second need a strict
          // timestamp order for the server's last-writer-wins merge.
          final next = previous.updatedAt.add(const Duration(seconds: 1));
          if (updatedAt.isBefore(next)) updatedAt = next;
        }
        await _db.upsertBookmark(
            contentId, updatedAt, previous != null && !previous.deleted);
      });
}
