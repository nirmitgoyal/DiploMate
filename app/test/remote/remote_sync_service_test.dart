import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_sync_service.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors Task 3's stub pattern (remote_content_repository_test.dart).
class MemoryTokenStore implements TokenStore {
  String? value = 'jwt';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  ResponseBody Function(RequestOptions) handler;
  int hits = 0;
  final List<String> paths = [];
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async {
    hits++;
    paths.add(o.path);
    return handler(o);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object o, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(o), status,
        headers: {
          'content-type': ['application/json']
        });

// Bookmarks are otherwise never fetched in these tests; a bare empty set keeps
// the PUT /me/bookmarks leg quiet unless a test overrides the handler.
ResponseBody _emptyBookmarks() => json({'bookmarks': []});

void main() {
  late AppDatabase db;
  late ApiClient api;
  late StubAdapter adapter;
  late StudyRepository study;
  final now = DateTime(2026, 7, 6, 10);

  RemoteSyncService service({void Function()? onAuthExpired}) =>
      RemoteSyncService(
        api: api,
        db: db,
        now: () => now,
        random: Random(1),
        onAuthExpired: onAuthExpired ?? () {},
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await api.init();
    adapter = StubAdapter((o) {
      if (o.path == '/sync/review-events') return json({'inserted': 1, 'rejected': []});
      if (o.path == '/sync/app-events') return json({'inserted': 1, 'rejected': []});
      if (o.path == '/me/bookmarks') return _emptyBookmarks();
      return json({'error': 'not_found'}, 404);
    });
    api.dio.httpClientAdapter = adapter;
    study = StudyRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  // (a) happy flush drains both pending tables + stamps last_synced_at.
  test('happy flush drains both pending tables and stamps last_synced_at',
      () async {
    await study.recordRating(
      qnaId: 'QN1',
      rating: WireRating.good,
      shownAt: now.subtract(const Duration(seconds: 20)),
      revealedAt: now.subtract(const Duration(seconds: 10)),
    ); // writes 1 review event + 1 recall_rated app event

    expect((await db.unsyncedReviewEvents()).length, 1);
    expect((await db.unsyncedAppEvents()).length, 1);

    await service().flush();

    expect(await db.unsyncedReviewEvents(), isEmpty, reason: 'inserted:1 -> deleted');
    expect(await db.unsyncedAppEvents(), isEmpty);
    expect(adapter.paths, containsAll(['/sync/review-events', '/sync/app-events', '/me/bookmarks']));
    expect(await db.readSetting('last_synced_at'), now.toIso8601String());
  });

  // (b) rejected poison row increments sync_attempts and is DROPPED after 5.
  // Asserts persistence across a fresh RemoteSyncService instance - the whole
  // reason the counter lives in drift (Part A).
  test('poison row increments sync_attempts, dropped after the 5th rejection, '
      'counter persists across service instances', () async {
    final ev = await study.recordRating(
      qnaId: 'QN1',
      rating: WireRating.good,
      shownAt: now.subtract(const Duration(seconds: 20)),
      revealedAt: now.subtract(const Duration(seconds: 10)),
    );
    // Server always rejects THIS row; app events flush fine so only the review
    // event's poison counter is under test.
    adapter.handler = (o) {
      if (o.path == '/sync/review-events') {
        return json({
          'inserted': 0,
          'rejected': [
            {'id': ev.id, 'error': 'review_events_rating_check'}
          ]
        });
      }
      if (o.path == '/sync/app-events') return json({'inserted': 1, 'rejected': []});
      if (o.path == '/me/bookmarks') return _emptyBookmarks();
      return json({'error': 'not_found'}, 404);
    };

    // 4 flushes across TWO service instances: still present, attempts == 4.
    await service().flush();
    await service().flush();
    final fresh = service(); // brand-new instance, no in-memory attempt state
    await fresh.flush();
    await fresh.flush();

    final row = await db.unsyncedReviewEvents();
    expect(row.length, 1, reason: 'survives 4 rejections (local-first)');
    expect(row.single.syncAttempts, 4,
        reason: 'counter persisted in drift across the instance swap');

    // 5th rejection drops it as poison.
    await service().flush();
    expect(await db.unsyncedReviewEvents(), isEmpty,
        reason: 'dropped after the 5th rejection - poison never wedges');
  });

  // (c) a 500 arms the backoff window: a 2nd flush() inside the window does
  // ZERO HTTP (assert adapter hit count).
  test('a 500 arms the backoff window; a second flush inside it does no HTTP',
      () async {
    await study.recordRating(
      qnaId: 'QN1',
      rating: WireRating.good,
      shownAt: now.subtract(const Duration(seconds: 20)),
      revealedAt: now.subtract(const Duration(seconds: 10)),
    );
    adapter.handler = (o) => json({'error': 'boom'}, 500);

    final s = service();
    await s.flush(); // fails, arms window
    final hitsAfterFirst = adapter.hits;
    expect(hitsAfterFirst, greaterThan(0), reason: 'first flush did hit the wire');

    await s.flush(); // inside the window -> returns immediately
    expect(adapter.hits, hitsAfterFirst, reason: 'no retry storm inside the backoff window');
  });

  // (d) a bookmark tombstone from /me/bookmarks overwrites a stale local
  // un-delete.
  test('a server bookmark tombstone overwrites a stale local un-delete',
      () async {
    // Local row: QN1 bookmarked (deleted=false), updated more recently locally.
    await db.upsertBookmark('QN1', now, false);
    expect((await db.readBookmarkRows()).single.deleted, isFalse);

    adapter.handler = (o) {
      if (o.path == '/sync/review-events') return json({'inserted': 0, 'rejected': []});
      if (o.path == '/sync/app-events') return json({'inserted': 0, 'rejected': []});
      if (o.path == '/me/bookmarks') {
        return json({
          'bookmarks': [
            {'content_id': 'QN1', 'updated_at': '2026-07-04T11:00:00Z', 'deleted': true}
          ]
        });
      }
      return json({'error': 'not_found'}, 404);
    };

    await service().flush();

    final row = (await db.readBookmarkRows()).single;
    expect(row.deleted, isTrue, reason: 'server truth (tombstone) wins on merge-back');
    expect(row.updatedAt.isAtSameMomentAs(DateTime.parse('2026-07-04T11:00:00Z')),
        isTrue,
        reason: 'server updated_at kept (drift round-trips DateTimes in local zone)');
  });
}
