import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/ui/reader/answer_search.dart';
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
}
