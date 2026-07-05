import 'package:flutter/painting.dart';

import '../../domain/models.dart';

class SearchMatch {
  const SearchMatch({required this.sectionKey, required this.start, required this.end});
  final String sectionKey; // 'earn:<label>' for outline rows, else AnswerSection.key
  final int start, end;    // character offsets within that section's searched text
}

int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (j) => j);
  final curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = List.of(curr);
  }
  return prev[n];
}

bool _wordMatches(String word, String qword) {
  final w = word.toLowerCase(), q = qword.toLowerCase();
  if (w.contains(q)) return true;
  if (q.length >= 7) return _levenshtein(w, q) <= 2;
  if (q.length >= 4) return _levenshtein(w, q) <= 1;
  return false; // short words: substring only (checked above)
}

final _wordRe = RegExp(r"[A-Za-z0-9']+");

/// Spec: per-word substring or Levenshtein (<=1 for >=4 chars, <=2 for >=7);
/// multi-word queries match as consecutive word runs. Scope: earns_marks
/// labels + section headings + section bodies. Never diagram captions.
List<SearchMatch> findMatches(QnaRow qna, String query) {
  final qwords = _wordRe.allMatches(query).map((m) => m.group(0)!).toList();
  if (qwords.isEmpty) return const [];
  final out = <SearchMatch>[];

  void scan(String key, String text) {
    final words = _wordRe.allMatches(text).toList();
    for (var i = 0; i + qwords.length <= words.length; i++) {
      var ok = true;
      for (var j = 0; j < qwords.length; j++) {
        if (!_wordMatches(words[i + j].group(0)!, qwords[j])) {
          ok = false;
          break;
        }
      }
      if (ok) {
        out.add(SearchMatch(
            sectionKey: key,
            start: words[i].start,
            end: words[i + qwords.length - 1].end));
      }
    }
  }

  for (final e in qna.earnsMarks) {
    scan('earn:${e.label}', e.label);
  }
  for (final s in qna.sections) {
    scan(s.key, '${s.heading}\n${s.bodyMd}');
  }
  return out;
}

List<InlineSpan> highlightSpans({
  required String text,
  required String sectionKey,
  required List<SearchMatch> matches,
  required int activeIndex,
  required TextStyle base,
  required Color highlight,
  required Color activeHighlight,
}) {
  final own = [
    for (var i = 0; i < matches.length; i++)
      if (matches[i].sectionKey == sectionKey) (i, matches[i])
  ];
  if (own.isEmpty) return [TextSpan(text: text, style: base)];
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final (i, m) in own) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
    }
    spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: base.copyWith(
            backgroundColor: i == activeIndex ? activeHighlight : highlight)));
    cursor = m.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}
