import 'dart:async';

import '../repos/bookmark_repository.dart';

class FakeBookmarkRepository implements BookmarkRepository {
  final _entries = <String, BookmarkEntry>{};
  final _controller = StreamController<void>.broadcast();

  List<BookmarkEntry> get _list => _entries.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<Set<String>> bookmarkedIds() async* {
    yield _entries.keys.toSet();
    yield* _controller.stream.map((_) => _entries.keys.toSet());
  }

  @override
  Future<void> toggle(String contentId) async {
    if (_entries.containsKey(contentId)) {
      _entries.remove(contentId);
    } else {
      _entries[contentId] =
          BookmarkEntry(contentId: contentId, updatedAt: DateTime.now());
    }
    _controller.add(null);
  }

  @override
  Stream<List<BookmarkEntry>> entries() async* {
    yield _list;
    yield* _controller.stream.map((_) => _list);
  }
}
