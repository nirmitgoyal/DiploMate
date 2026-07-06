// D10 Leitner scheduler - pure functions, no Flutter imports.
// Wire rating enum {again, hard, good} is OWNED by
// sql/0003_users_events.sql (review_events_rating_check). WireRating and the
// display-only UI relabel map (uiLabelForWire) already live in models.dart
// (created by plan 4); this file imports them and does NOT redeclare them -
// a redeclaration would be a duplicate/ambiguous symbol against the import.
import 'dart:developer' show log;

import '../local_day.dart';
import '../models.dart';

class CardState {
  const CardState({
    required this.contentId,
    required this.bucket,
    required this.intervalDays,
    required this.dueLocalDay,
    required this.lastRatedDay,
    required this.dueEndOfQueue,
  });

  final String contentId; // QnA ULID
  final int bucket; // 1, 2, 3
  final int intervalDays; // last applied interval (B3 doubling base)
  final String dueLocalDay; // "YYYY-MM-DD"
  final String lastRatedDay; // "YYYY-MM-DD"
  final bool dueEndOfQueue; // true right after 'again' (same-day, back of queue)
}

/// Applies one event to a prior state. Unknown rating -> returns prev
/// unchanged and logs (forward-compat: an FSRS build may write ratings this
/// build does not know; skipping keeps the fold deterministic either way).
CardState? applyRating(String contentId, CardState? prev, ReviewEvent e) {
  final day = e.localDay;
  final bucket = prev?.bucket ?? 1; // new QnA enters B1 on first rating (D10)
  final interval = prev?.intervalDays ?? 0;

  switch (e.rating) {
    case 'again':
      return CardState(
        contentId: contentId,
        bucket: 1,
        intervalDays: 0,
        dueLocalDay: day, // same local day, back of queue
        lastRatedDay: day,
        dueEndOfQueue: true,
      );
    case 'hard':
      return CardState(
        contentId: contentId,
        bucket: bucket, // stays
        intervalDays: interval, // carries (B3 doubling base preserved)
        dueLocalDay: addLocalDays(day, 2),
        lastRatedDay: day,
        dueEndOfQueue: false,
      );
    case 'good':
      final int nextBucket;
      final int nextInterval;
      if (bucket == 1) {
        nextBucket = 2;
        nextInterval = 1;
      } else if (bucket == 2) {
        nextBucket = 3;
        nextInterval = 3;
      } else {
        nextBucket = 3; // B3 stays
        nextInterval = interval * 2; // previous interval x 2
      }
      return CardState(
        contentId: contentId,
        bucket: nextBucket,
        intervalDays: nextInterval,
        dueLocalDay: addLocalDays(day, nextInterval),
        lastRatedDay: day,
        dueEndOfQueue: false,
      );
    default:
      log('leitner: skipping unknown rating "${e.rating}" (event ${e.id})',
          name: 'diplomate.scheduler');
      return prev;
  }
}

/// Pure fold over rating events sorted by rated_at. Deterministic;
/// replay-idempotent. Returns null for a card with no known-rating events
/// (unseen cards are never queued - due-only queue, no new-card injection).
CardState? foldEvents(String contentId, List<ReviewEvent> sortedEvents) {
  CardState? state;
  for (final e in sortedEvents) {
    state = applyRating(contentId, state, e);
  }
  return state;
}
