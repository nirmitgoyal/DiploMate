import 'package:flutter/foundation.dart';

import '../../data/repos/study_repository.dart';
import '../../domain/models.dart';

enum ReaderMode { queue, browse }

/// Drives one Reader session. Queue mode: due-only suggestions with
/// auto-advance ("Suggestion · N of M" overline). Browse mode: opened from
/// Topics/Bookmarks - crumb only, rate-then-stay + "Next in topic".
/// Construct fresh on every screen entry (the recall gate resets).
class ReaderController extends ChangeNotifier {
  ReaderController.queue({
    required StudyRepository repo,
    required List<String> queue,
    DateTime Function() now = DateTime.now,
  })  : _repo = repo,
        _now = now,
        mode = ReaderMode.queue,
        _items = List.unmodifiable(queue),
        _index = 0 {
    _startCurrent();
  }

  ReaderController.browse({
    required StudyRepository repo,
    required String qnaId,
    required List<String> topicQnaIds,
    DateTime Function() now = DateTime.now,
  })  : _repo = repo,
        _now = now,
        mode = ReaderMode.browse,
        _items = List.unmodifiable(topicQnaIds),
        _index = topicQnaIds.indexOf(qnaId) {
    assert(_index >= 0, 'qnaId must be in topicQnaIds');
    _startCurrent();
  }

  final StudyRepository _repo;
  final DateTime Function() _now;
  final ReaderMode mode;
  final List<String> _items;

  int _index;
  bool _revealed = false;
  bool _ratingInFlight = false;
  bool _complete = false;
  DateTime? _shownAt;
  DateTime? _revealedAt;

  String? get currentQnaId => _complete ? null : _items[_index];
  int get position => _index + 1; // 1-based for "Suggestion · N of M"
  int get total => _items.length;
  bool get revealed => _revealed;
  bool get ratingInFlight => _ratingInFlight;
  bool get complete => _complete;
  bool get hasNextInTopic =>
      mode == ReaderMode.browse && _index < _items.length - 1;

  void _startCurrent() {
    _revealed = false;
    _revealedAt = null;
    _shownAt = _now();
    // Fire-and-forget analytics: the recall gate must not wait on a write.
    _repo.recordAppEvent(eventType: 'recall_shown', contentId: _items[_index]);
    notifyListeners();
  }

  /// Reveal the model answer. hidden_ms feeds the metric-side validity rule
  /// (hidden >= 10s AND rated) - computed in SQL, never surfaced in UI.
  Future<void> reveal() async {
    if (_revealed || _complete) return;
    _revealedAt = _now();
    _revealed = true;
    final hiddenMs = _revealedAt!.difference(_shownAt!).inMilliseconds;
    notifyListeners();
    await _repo.recordAppEvent(
        eventType: 'recall_revealed',
        contentId: _items[_index],
        hiddenMs: hiddenMs);
  }

  /// Debounced (CEO-T5): re-entrant calls while a rating is in flight are
  /// dropped, so a double-tap yields exactly one review event and exactly
  /// one queue advance. Resolves AFTER the drift persist (D4) - the screen
  /// shows its "Rated <tier> - next answer" toast only after this await.
  Future<void> rate(WireRating rating) async {
    if (!_revealed || _ratingInFlight || _complete) return;
    _ratingInFlight = true;
    notifyListeners();
    try {
      await _repo.recordRating(
        qnaId: _items[_index],
        rating: rating,
        shownAt: _shownAt!,
        revealedAt: _revealedAt!,
      );
      if (mode == ReaderMode.queue) {
        if (_index + 1 < _items.length) {
          _index += 1;
          _ratingInFlight = false;
          _startCurrent(); // auto-advance: next card at the recall gate
        } else {
          _complete = true; // end-of-queue completion state (design F8)
          _ratingInFlight = false;
          notifyListeners();
        }
      } else {
        _ratingInFlight = false; // browse: rate-then-stay
        notifyListeners();
      }
    } catch (_) {
      _ratingInFlight = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Browse mode only: the "Next in topic" action after rate-then-stay.
  void nextInTopic() {
    if (mode != ReaderMode.browse || !hasNextInTopic) return;
    _index += 1;
    _startCurrent();
  }
}
