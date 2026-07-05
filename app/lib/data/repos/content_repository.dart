import 'dart:typed_data';

import '../../domain/models.dart';

class ContentFetchException implements Exception {
  ContentFetchException(this.chapterId);
  final String chapterId;
}

/// Contract-verbatim (plan-contract.md). Plan 6 provides the dio+drift
/// implementation; this plan ships a fixture-backed one.
abstract class ContentRepository {
  Future<List<SpecialityRow>> specialities();
  Future<List<ChapterRow>> chapters(String specialityId);
  Future<void> ensureChapterCached(String chapterId);
  Future<List<TopicRow>> topics(String chapterId);
  Future<List<QnaRow>> qnas(String topicId);
  Future<QnaRow?> qna(String qnaId);
  Future<Uint8List> imageBytes(String imageId);
}
