class SpecialityRow {
  const SpecialityRow(
      {required this.id,
      required this.name,
      required this.examType,
      required this.slug,
      required this.sortOrder,
      required this.hasContent});
  final String id; // ULID
  final String name;
  final String examType; // 'DNB' | 'DrNB' (sql/0001 CHECK owns this enum)
  final String slug;
  final int sortOrder;
  final bool hasContent;
}

class ChapterRow {
  const ChapterRow(
      {required this.id,
      required this.specialityId,
      required this.title,
      required this.slug,
      required this.sortOrder,
      required this.examWeight,
      required this.contentVersion,
      required this.topicCount,
      required this.qnaCount,
      this.recalledCount = 0});
  final String id, specialityId, title, slug;
  final int sortOrder, examWeight, contentVersion, topicCount, qnaCount;
  final int
      recalledCount; // fixture/UI aggregate; real value derives from plan 5 CardStates
}

class TopicRow {
  const TopicRow(
      {required this.id,
      required this.chapterId,
      required this.title,
      required this.slug,
      this.examTheme,
      required this.sortOrder});
  final String id, chapterId, title, slug;
  final String? examTheme;
  final int sortOrder;
}

class EarnRow {
  const EarnRow({required this.label, required this.sectionKey});
  final String label, sectionKey;
}

class AnswerSection {
  const AnswerSection(
      {required this.key,
      required this.heading,
      required this.bodyMd,
      this.marks});
  final String key, heading, bodyMd;
  final int? marks; // examiner red-margin weight; null = unnumbered (Summary)
}

class ImageRow {
  const ImageRow(
      {required this.id,
      required this.caption,
      required this.contentDescription,
      required this.byteSize,
      required this.sha256,
      required this.sortOrder});
  final String id, caption, contentDescription, sha256;
  final int byteSize, sortOrder;
}

class QnaRow {
  const QnaRow(
      {required this.id,
      required this.topicId,
      required this.question,
      this.years,
      this.marks,
      required this.earnsMarks,
      required this.sections,
      required this.sortOrder,
      required this.images});
  final String id, topicId, question;
  final String? years;
  final int? marks;
  final List<EarnRow> earnsMarks;
  final List<AnswerSection> sections;
  final int sortOrder;
  final List<ImageRow> images;
}

/// Wire enum - values owned by sql/0003 review_events.rating CHECK
/// (sql/ DDL is the enum source of truth; do not re-validate here).
enum WireRating { again, hard, good }

const uiLabelForWire = {
  WireRating.good: 'Easy',
  WireRating.hard: 'Medium',
  WireRating.again: 'Hard',
};

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
