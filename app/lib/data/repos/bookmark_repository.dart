class BookmarkEntry {
  const BookmarkEntry({required this.contentId, required this.updatedAt});
  final String contentId;
  final DateTime updatedAt;
}

/// Local-first; plan 5 persists to drift, plan 6 adds PUT /me/bookmarks
/// LWW sync (tombstones live in the drift row, not here).
abstract class BookmarkRepository {
  Stream<Set<String>> bookmarkedIds();
  Future<void> toggle(String contentId);
  Stream<List<BookmarkEntry>> entries();
}
