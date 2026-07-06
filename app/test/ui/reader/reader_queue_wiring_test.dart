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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves exactly one seeded QnaRow by id; every other read is empty.
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
  Future<List<TopicRow>> topics(String chapterId) async => const [];
  @override
  Future<List<QnaRow>> qnas(String topicId) async => const [];
  @override
  Future<Uint8List> imageBytes(String imageId) async => Uint8List(0);
}

QnaRow _seedQna() => const QnaRow(
      id: 'QN1',
      topicId: 'T1',
      question: 'Define the stress response to surgery.',
      years: '2022 Paper I',
      marks: 10,
      earnsMarks: [EarnRow(label: 'Definition', sectionKey: 'definition')],
      sections: [
        AnswerSection(
            key: 'definition',
            heading: 'Definition',
            bodyMd: 'The neuroendocrine and metabolic response to tissue injury.',
            marks: 4),
      ],
      sortOrder: 0,
      images: [],
    );

void main() {
  testWidgets(
      'queue mode: reveal -> Easy persists EXACTLY one pending_review_events row '
      'via ReaderController.rate, and the toast follows the awaited persist',
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

    // The queued card loads and shows the reveal CTA + the "Suggestion" overline.
    expect(find.text('SUGGESTION · 1 OF 1'), findsOneWidget);
    expect(find.text('Reveal model answer'), findsOneWidget);

    await tester.tap(find.text('Reveal model answer'));
    await tester.pumpAndSettle();
    expect(find.text('Easy'), findsOneWidget);

    // Rate -> the persist is awaited BEFORE the toast fires.
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1,
        reason: 'onRate routed ReaderController.rate -> recordRating, not a flag');
    expect(rows.single.contentId, 'QN1');
    expect(rows.single.rating, 'good');

    expect(find.text('✓ Rated Easy - next answer'), findsOneWidget);
    // Let the 1500ms toast timer expire so no Timer outlives the tree.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'queue mode: report row is absent pre-reveal, present post-reveal under '
      'the rating tray, and tapping it routes to reportErrorProvider (DESIGN '
      'item 13 - one surface, two states)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    String? reportedQnaId;
    String? reportedMessage;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider
            .overrideWithValue(_OneQnaContentRepository(_seedQna())),
        dueQueueProvider.overrideWithValue(const ['QN1']),
        reportErrorProvider.overrideWithValue((qnaId, message) async {
          reportedQnaId = qnaId;
          reportedMessage = message;
        }),
      ],
      child: MaterialApp(
          theme: dmLightTheme(), home: const ReaderScreen.queue()),
    ));
    await tester.pumpAndSettle();

    // Pre-reveal: no report row.
    expect(find.text('Report an answer error'), findsNothing);

    await tester.tap(find.text('Reveal model answer'));
    await tester.pumpAndSettle();

    // Post-reveal: the report row is present, under the rating tray.
    expect(find.text('Report an answer error'), findsOneWidget);

    await tester.tap(find.text('Report an answer error'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Stale marks total');
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(reportedQnaId, 'QN1');
    expect(reportedMessage, 'Stale marks total');
    expect(find.text('✓ Report sent - thank you'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
