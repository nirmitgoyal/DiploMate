import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = FixtureContentRepository();

  test('fixture speciality is Anaesthesiology with content', () async {
    final specs = await repo.specialities();
    expect(specs.length, 61);
    final anaes = specs.singleWhere((s) => s.hasContent);
    expect(anaes.name, 'Anaesthesiology');
    expect(anaes.examType, 'DNB');
  });

  test('fixture chapter tree matches the DDL shape', () async {
    final specs = await repo.specialities();
    final anaes = specs.singleWhere((s) => s.hasContent);
    final chapters = await repo.chapters(anaes.id);
    expect(chapters, isNotEmpty);
    final airway = chapters.first;
    expect(airway.title, 'Airway Management');
    expect(airway.contentVersion, 1);
    final qnas = await repo.qnas(airway.id);
    expect(qnas.map((q) => q.id).toList(),
        ['01J0QNADIFFAIR000000000001', '01J0QNARSI0000000000000001']);
    expect(qnas.every((q) => q.chapterId == airway.id), isTrue);
    expect(qnas.first.earnsMarks.first.sectionKey, isNotEmpty);
    expect(qnas.first.sections.first.key, qnas.first.earnsMarks.first.sectionKey);
  });

  test('imageBytes returns bundled bytes', () async {
    final specs = await repo.specialities();
    final anaes = specs.singleWhere((s) => s.hasContent);
    final chapters = await repo.chapters(anaes.id);
    // The image lives on the Truncal blocks QnA (Regional Anaesthesia
    // chapter), not necessarily the first chapter - walk all of them.
    final allQnas = <QnaRow>[];
    for (final chapter in chapters) {
      allQnas.addAll(await repo.qnas(chapter.id));
    }
    final img = allQnas.expand((q) => q.images).first;
    final bytes = await repo.imageBytes(img.id);
    expect(bytes, isNotEmpty);
  });
}
