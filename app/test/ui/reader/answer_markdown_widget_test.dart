import 'dart:typed_data';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/content_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OneQnaContentRepository implements ContentRepository {
  _OneQnaContentRepository(this._qna);
  final QnaRow _qna;

  @override
  Future<QnaRow?> qna(String qnaId) async => qnaId == _qna.id ? _qna : null;
  @override
  Future<List<SpecialityRow>> specialities() async => const [];
  @override
  Future<List<ChapterRow>> chapters(String specialityId) async => const [];
  @override
  Future<void> ensureChapterCached(String chapterId) async {}
  @override
  Future<List<QnaRow>> qnas(String chapterId) async => const [];
  @override
  Future<Uint8List> imageBytes(String imageId) async => Uint8List(0);
}

QnaRow _seedQna() => const QnaRow(
      id: 'QN1',
      chapterId: 'T1',
      question: 'Define the stress response to surgery.',
      years: '2022 Paper I',
      marks: 10,
      earnsMarks: [EarnRow(label: 'Definition', sectionKey: 'definition')],
      sections: [
        AnswerSection(
            key: 'definition',
            heading: 'Definition',
            bodyMd: 'A **bold** point:\n\n- first\n- second',
            marks: 4),
      ],
      sortOrder: 0,
      images: [],
    );

void main() {
  testWidgets('revealed answer renders body_md as markdown (bold stripped)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider
            .overrideWithValue(_OneQnaContentRepository(_seedQna())),
        dueQueueProvider.overrideWithValue(const ['QN1']),
      ],
      child: MaterialApp(
          theme: dmLightTheme(), home: const ReaderScreen.queue()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reveal model answer'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);

    // The parsed spans carry the text WITHOUT the '**' markers - proof the
    // markdown was rendered, not printed literally.
    final rendered = tester
        .widgetList<RichText>(find.descendant(
            of: find.byType(MarkdownBody), matching: find.byType(RichText)))
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(rendered, contains('bold'));
    expect(rendered, contains('first'));
    expect(rendered, isNot(contains('**')));
    expect(rendered, isNot(contains('- first')));
  });
}
