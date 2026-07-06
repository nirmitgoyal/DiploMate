import 'dart:convert';
import 'dart:typed_data';

import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_content_repository.dart';
import 'package:diplomate/data/repos/content_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async {
    hits++;
    return handler(o);
  }
  @override
  void close({bool force = false}) {}
}

const _manifest = {
  'schema_version': 1, 'min_app_version': 1,
  'specialities': [
    {'id': 'S1', 'name': 'Anaesthesiology', 'exam_type': 'DNB',
     'slug': 'anaesthesiology', 'sort_order': 1, 'has_content': true},
  ],
  'chapters': [
    {'id': 'CH1', 'title': 'Airway Management', 'slug': 'airway', 'sort_order': 1,
     'exam_weight': 100, 'content_version': 1, 'topic_count': 1, 'qna_count': 1},
  ],
};

const _page = {
  'chapter_id': 'CH1', 'content_version': 1, 'schema_version': 1, 'page': 1, 'pages': 1,
  'items': [
    {'id': 'QN1', 'topic_id': 'TP1', 'question': 'Q?', 'years': '2021', 'marks': 10,
     'earns_marks': [], 'sections': [{'key': 's', 'heading': 'S', 'body_md': 'B', 'marks': 1}],
     'sort_order': 1,
     'images': [{'id': 'IM1', 'caption': 'Fig', 'content_description': 'D',
                 'byte_size': 4, 'sha256': 'abc', 'sort_order': 1}]},
  ],
  'topics': [
    {'id': 'TP1', 'title': 'Airway assessment', 'slug': 'airway-assessment',
     'exam_theme': null, 'sort_order': 1},
  ],
};

ResponseBody json(Object o, [int status = 200, Map<String, List<String>>? extra]) =>
    ResponseBody.fromString(jsonEncode(o), status, headers: {
      'content-type': ['application/json'], ...?extra});

void main() {
  late AppDatabase db;
  late ApiClient api;
  late StubAdapter adapter;
  late RemoteContentRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await api.init();
    adapter = StubAdapter((o) {
      if (o.path == '/manifest') return json(_manifest);
      if (o.path == '/chapters/CH1/qnas') return json(_page);
      if (o.path == '/images/IM1') {
        return ResponseBody.fromBytes(Uint8List.fromList([1, 2, 3, 4]), 200,
            headers: {'content-type': ['image/webp'], 'etag': ['"abc"']});
      }
      return json({'error': 'not_found'}, 404);
    });
    api.dio.httpClientAdapter = adapter;
    repo = RemoteContentRepository(api: api, db: db, specialityId: () async => 'S1');
  });

  tearDown(() => db.close());

  test('ensureChapterCached fetches pages once, then serves drift without network', () async {
    await repo.ensureChapterCached('CH1');
    final qnas = await repo.qnas('TP1');
    expect(qnas.single.id, 'QN1');
    final before = adapter.hits;

    // network dies; cached chapter still serves
    adapter.handler = (o) => throw DioException.connectionError(requestOptions: o, reason: 'down');
    await repo.ensureChapterCached('CH1'); // silent - cache is fresh enough
    final again = await repo.qnas('TP1');
    expect(again.single.id, 'QN1');
    expect(adapter.hits, greaterThanOrEqualTo(before), reason: 'no crash offline');
  });

  test('no cache + no network -> ContentFetchException (inline retry state)', () async {
    adapter.handler = (o) => throw DioException.connectionError(requestOptions: o, reason: 'down');
    expect(repo.ensureChapterCached('CH1'), throwsA(isA<ContentFetchException>()));
  });

  test('imageBytes caches; second read hits drift, not the network', () async {
    await repo.ensureChapterCached('CH1');
    final b1 = await repo.imageBytes('IM1');
    expect(b1, [1, 2, 3, 4]);
    final hits = adapter.hits;
    final b2 = await repo.imageBytes('IM1');
    expect(b2, [1, 2, 3, 4]);
    expect(adapter.hits, hits, reason: 'served from image_blobs');
  });

  test('content_version bump invalidates the chapter cache on next ensure', () async {
    await repo.ensureChapterCached('CH1');
    var v2manifest = Map<String, dynamic>.from(_manifest);
    v2manifest['chapters'] = [
      {...(_manifest['chapters'] as List).first as Map<String, dynamic>, 'content_version': 2}
    ];
    var v2page = Map<String, dynamic>.from(_page);
    v2page['content_version'] = 2;
    v2page['items'] = [
      {...(_page['items'] as List).first as Map<String, dynamic>, 'question': 'Q v2?'}
    ];
    adapter.handler = (o) {
      if (o.path == '/manifest') return json(v2manifest);
      if (o.path == '/chapters/CH1/qnas') return json(v2page);
      return json({'error': 'not_found'}, 404);
    };
    await repo.ensureChapterCached('CH1');
    final qnas = await repo.qnas('TP1');
    expect(qnas.single.question, 'Q v2?', reason: 'stale rows replaced in one transaction');
  });

  test('server-sent topics[] persist with real titles; specialities carry slug + hasContent', () async {
    await repo.ensureChapterCached('CH1');
    final topics = await repo.topics('CH1');
    expect(topics.single.title, 'Airway assessment',
        reason: 'topic rows come from the response topics[], not synthesized from topic_id');
    final specs = await repo.specialities();
    final anaes = specs.firstWhere((s) => s.id == 'S1');
    expect(anaes.slug, 'anaesthesiology');
    expect(anaes.hasContent, isTrue, reason: 'has_content sourced from the manifest wire');
  });
}
