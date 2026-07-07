import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/models.dart';
import '../db/app_db.dart';
import '../repos/content_repository.dart';
import 'api_client.dart';

class RemoteContentRepository implements ContentRepository {
  RemoteContentRepository(
      {required this.api, required this.db, required this.specialityId});
  final ApiClient api;
  final AppDatabase db;
  final Future<String?> Function() specialityId; // caller's chosen track

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  /// Returns the raw manifest map on success, null on a network failure
  /// (caller falls back to the cache). `has_content`/manifest chapter counts
  /// only ever exist on this fresh response - never persisted - so callers
  /// that need them read this return value, not a second drift round trip.
  Future<Map<String, dynamic>?> _refreshManifest() async {
    final spec = await specialityId();
    final res = await api.dio.get('/manifest',
        queryParameters: spec == null ? null : {'speciality': spec});
    final manifest = res.data as Map<String, dynamic>;
    if ((manifest['min_app_version'] as int? ?? 1) > kSupportedSchemaVersion) {
      throw UpgradeRequiredException();
    }
    // chapters[] carries no speciality_id of its own (the wire scopes the
    // whole array to whatever ?speciality= was requested) - spec is the
    // only place that association is known, so it rides along here.
    await db.upsertManifest(manifest, spec);
    return manifest;
  }

  @override
  Future<List<SpecialityRow>> specialities() async {
    Map<String, dynamic>? manifest;
    try {
      manifest = await _refreshManifest();
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow; // cache serves below on network failure
    }
    final hasContent = {
      for (final s in (manifest?['specialities'] as List? ?? const []))
        (s as Map<String, dynamic>)['id'] as String: s['has_content'] as bool,
    };
    return db.readSpecialities(hasContent);
  }

  @override
  Future<List<ChapterRow>> chapters(String specialityId) async {
    Map<String, dynamic>? manifest;
    try {
      manifest = await _refreshManifest();
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow;
    }
    final manifestChapters =
        (manifest?['chapters'] as List?)?.cast<Map<String, dynamic>>();
    return db.readChapters(specialityId, manifestChapters);
  }

  @override
  Future<void> ensureChapterCached(String chapterId) async {
    final cached = await db.cachedChapterVersion(chapterId);
    int? remote;
    try {
      await _refreshManifest();
      remote = await db.manifestChapterVersion(chapterId);
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow;
      if (cached != null) return; // transparent cache: serve what we have
      throw ContentFetchException(chapterId);
    }
    if (cached != null && cached == remote) return;

    try {
      final items = <Map<String, dynamic>>[];
      var page = 1, pages = 1, version = remote ?? 0;
      do {
        final res = await api.dio
            .get('/chapters/$chapterId/qnas', queryParameters: {'page': page});
        final body = res.data as Map<String, dynamic>;
        pages = body['pages'] as int;
        version = body['content_version'] as int;
        items.addAll((body['items'] as List).cast<Map<String, dynamic>>());
        page++;
      } while (page <= pages);
      // ONE transaction per chapter refresh; an open QnA stays in memory.
      await db.replaceChapterContent(chapterId, version, items);
    } on DioException catch (e) {
      if (_isNetwork(e) && cached != null) return;
      if (_isNetwork(e)) throw ContentFetchException(chapterId);
      rethrow;
    }
  }

  @override
  Future<List<QnaRow>> qnas(String chapterId) => db.readQnasByChapter(chapterId);

  @override
  Future<QnaRow?> qna(String qnaId) => db.readQna(qnaId);

  @override
  Future<Uint8List> imageBytes(String imageId) async {
    final cached = await db.readImageBlob(imageId);
    if (cached != null) return cached;
    final res = await api.dio.get<List<int>>('/images/$imageId',
        options: Options(responseType: ResponseType.bytes));
    final bytes = Uint8List.fromList(res.data!);
    await db.writeImageBlob(imageId, bytes);
    return bytes;
  }
}
