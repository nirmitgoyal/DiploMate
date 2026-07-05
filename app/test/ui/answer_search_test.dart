import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/ui/reader/answer_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('substring + typo-tolerant matching per the spec bands', () async {
    final repo = FixtureContentRepository();
    final qna = (await repo.qna('01J0QNATAPBLOCK00000000001'))!;

    expect(findMatches(qna, 'oblique'), isNotEmpty, reason: 'plain substring');
    expect(findMatches(qna, 'obliqe'), isNotEmpty,
        reason: 'Levenshtein 1 on a >=4-char word');
    expect(findMatches(qna, 'anasthetic'), isNotEmpty,
        reason: 'Levenshtein <=2 on a >=7-char word');
    expect(findMatches(qna, 'xy'), isEmpty, reason: 'short garbage does not fuzz');
    expect(findMatches(qna, 'internal oblique'), isNotEmpty, reason: 'phrase run');
  });

  test('matches carry section keys for scroll targeting', () async {
    final repo = FixtureContentRepository();
    final qna = (await repo.qna('01J0QNATAPBLOCK00000000001'))!;
    final m = findMatches(qna, 'hydrodissect');
    expect(m.single.sectionKey, 'technique');
  });

  group('highlightSpans - reader_view.dart splits the combined text at the '
      "heading/body '\\n' boundary, so offsets into it must stay correct "
      'on both sides and across the join', () {
    const heading = 'Definition';
    const bodyMd = 'A TAP block anaesthetises the anterolateral abdominal wall.';
    const text = '$heading\n$bodyMd'; // same join reader_view.dart feeds in
    const base = TextStyle(color: Color(0xFF000000));
    const highlight = Color(0xFFAAAAAA);
    const active = Color(0xFFFFAA00);

    String renderedText(List<InlineSpan> spans) =>
        spans.map((s) => (s as TextSpan).text ?? '').join();

    test('match entirely in the heading', () {
      const match = SearchMatch(sectionKey: 'def', start: 0, end: heading.length);
      final spans = highlightSpans(
        text: text,
        sectionKey: 'def',
        matches: [match],
        activeIndex: 0,
        base: base,
        highlight: highlight,
        activeHighlight: active,
      );
      expect(renderedText(spans), text, reason: 'no characters lost or duplicated');
      final hit = spans.firstWhere((s) => (s as TextSpan).text == heading) as TextSpan;
      expect(hit.style?.backgroundColor, active);
      // everything after the heading (the '\n' + body) is untouched, plain text
      final rest = spans.last as TextSpan;
      expect(rest.text, '\n$bodyMd');
      expect(rest.style?.backgroundColor, isNull);
    });

    test('match entirely in the body', () {
      const needle = 'anterolateral';
      final start = text.indexOf(needle);
      final match =
          SearchMatch(sectionKey: 'def', start: start, end: start + needle.length);
      final spans = highlightSpans(
        text: text,
        sectionKey: 'def',
        matches: [match],
        activeIndex: 0,
        base: base,
        highlight: highlight,
        activeHighlight: active,
      );
      expect(renderedText(spans), text);
      final hit = spans.firstWhere((s) => (s as TextSpan).text == needle) as TextSpan;
      expect(hit.style?.backgroundColor, active);
      // the heading and the '\n' before the match stay outside the highlight
      final before = spans.first as TextSpan;
      expect(before.text, text.substring(0, start));
      expect(before.text, contains('\n'), reason: 'still carries the boundary char');
      expect(before.style?.backgroundColor, isNull);
    });

    test('match straddles the heading/body newline boundary', () {
      // 'n\nA' - starts inside 'Definition', crosses '\n', ends inside 'A TAP'.
      const start = heading.length - 1;
      const end = heading.length + 1 + 'A'.length;
      final straddling = text.substring(start, end);
      expect(straddling, 'n\nA', reason: 'sanity: this is the boundary-crossing slice');
      const match = SearchMatch(sectionKey: 'def', start: start, end: end);

      final spansAtActive = highlightSpans(
        text: text,
        sectionKey: 'def',
        matches: [match],
        activeIndex: 0,
        base: base,
        highlight: highlight,
        activeHighlight: active,
      );
      expect(renderedText(spansAtActive), text,
          reason: 'the newline must survive inside the highlighted span, not '
              'be dropped or duplicated at the boundary');
      final hit = spansAtActive.firstWhere((s) => (s as TextSpan).text == straddling)
          as TextSpan;
      expect(hit.style?.backgroundColor, active,
          reason: 'the active match keeps its highlight across the join');
      final before = spansAtActive.first as TextSpan;
      expect(before.text, text.substring(0, start));
      final after = spansAtActive.last as TextSpan;
      expect(after.text, text.substring(end));

      // Same match, but rendered as a non-active one (second match is active
      // instead) - the straddling span must carry the plain highlight, a
      // visibly different color/flag from the active one above.
      const other = SearchMatch(sectionKey: 'def', start: end, end: end + 1);
      final spansInactive = highlightSpans(
        text: text,
        sectionKey: 'def',
        matches: [match, other],
        activeIndex: 1,
        base: base,
        highlight: highlight,
        activeHighlight: active,
      );
      final hitInactive =
          spansInactive.firstWhere((s) => (s as TextSpan).text == straddling)
              as TextSpan;
      expect(hitInactive.style?.backgroundColor, highlight);
      expect(hitInactive.style?.backgroundColor, isNot(active),
          reason: 'must be visibly distinct from the active-match highlight');
    });
  });
}
