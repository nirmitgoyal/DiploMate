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

/// Queue = due-only (dueLocalDay <= today), NO new-card injection (design T4).
/// Order: overdue first -> lowest bucket -> oldest lastRatedDay; 'again'
/// repeats (dueEndOfQueue on today's card) go to the back of today's queue.
/// contentId tie-break keeps the order fully deterministic.
List<String> buildQueue(Map<String, CardState> states, String todayLocalDay) {
  final due = states.values
      .where((s) => s.dueLocalDay.compareTo(todayLocalDay) <= 0)
      .toList();
  bool backOfQueue(CardState s) =>
      s.dueEndOfQueue && s.dueLocalDay == todayLocalDay;
  due.sort((a, b) {
    final aBack = backOfQueue(a) ? 1 : 0;
    final bBack = backOfQueue(b) ? 1 : 0;
    if (aBack != bBack) return aBack - bBack;
    final byDue = a.dueLocalDay.compareTo(b.dueLocalDay);
    if (byDue != 0) return byDue;
    if (a.bucket != b.bucket) return a.bucket - b.bucket;
    final byRated = a.lastRatedDay.compareTo(b.lastRatedDay);
    if (byRated != 0) return byRated;
    return a.contentId.compareTo(b.contentId);
  });
  return [for (final s in due) s.contentId];
}

/// Groups events by contentId, sorts each group by ratedAt, folds.
Map<String, CardState> foldAll(List<ReviewEvent> events) {
  final byContent = <String, List<ReviewEvent>>{};
  for (final e in events) {
    byContent.putIfAbsent(e.contentId, () => []).add(e);
  }
  final states = <String, CardState>{};
  byContent.forEach((contentId, list) {
    list.sort((a, b) => a.ratedAt.compareTo(b.ratedAt));
    final s = foldEvents(contentId, list);
    if (s != null) states[contentId] = s;
  });
  return states;
}

/// Number of cards due on or before [day] ("YYYY-MM-DD"). Feeds the D19
/// notification planner; monotonically nondecreasing in [day].
int dueCountFor(Map<String, CardState> states, String day) =>
    states.values.where((s) => s.dueLocalDay.compareTo(day) <= 0).length;
