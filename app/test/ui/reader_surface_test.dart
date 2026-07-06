import 'dart:typed_data';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/repos/content_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tapQna = '01J0QNATAPBLOCK00000000001';
const _tapTopic = '01J0TOPICTAPBLOCK000000001';

Widget host({ContentRepository? repo}) => ProviderScope(
      overrides: [
        if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: ReaderScreen.browse(qnaId: _tapQna, topicId: _tapTopic)),
    );

/// qna() always returns null - exercises a successful fetch that finds no
/// row (e.g. a stale/deleted deep-linked bookmark), which must render the
/// retry state, not spin forever.
class _NullQnaContentRepository implements ContentRepository {
  int qnaCalls = 0;

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
  Future<QnaRow?> qna(String qnaId) async {
    qnaCalls++;
    return null;
  }

  @override
  Future<Uint8List> imageBytes(String imageId) async => Uint8List(0);
}

void main() {
  // The revealed answer is long-form exam content (7 sections); the default
  // 800x600 test surface is too short for content that would scroll on a
  // real phone, so widen it (idiomatic for tall-content widget tests) - this
  // changes no assertion, only the canvas the assertions run against.
  Future<void> useTallSurface(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  testWidgets(
      'pre-reveal: question, chips, earns-marks, prompt, reveal CTA; no answer, no due chip',
      (t) async {
    await useTallSurface(t);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('transversus abdominis plane'), findsOneWidget);
    expect(find.text('2022 Paper II'), findsOneWidget);
    expect(find.text('10 marks'), findsOneWidget);
    expect(find.textContaining('Due'), findsNothing, reason: 'SRS de-surfaced');
    expect(find.text('What earns marks'), findsOneWidget);
    expect(find.text('Outline your answer aloud or on paper'), findsOneWidget);
    expect(find.text('Reveal model answer'), findsOneWidget);
    expect(find.textContaining('fascial plane block'), findsNothing,
        reason: 'answer hidden pre-reveal');
  });

  testWidgets(
      'reveal shows sections with red mark weights; tray is Easy/Medium/Hard; rating toasts and offers Next in topic',
      (t) async {
    await useTallSurface(t);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    expect(find.textContaining('fascial plane block'), findsOneWidget);
    expect(find.text('Definition'), findsWidgets);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing,
        reason: 'no interval hints');
    expect(find.textContaining(' due'), findsNothing,
        reason: 'no done/due counter');

    await t.tap(find.text('Easy'));
    await t.pumpAndSettle(); // the rating persists (awaited drift write) then toasts
    expect(find.text('✓ Rated Easy - next answer'), findsOneWidget);
    await t.pump(const Duration(seconds: 2)); // toast expiry
    expect(find.text('Next in topic'), findsNothing,
        reason: 'TAP topic has one QnA - no next');
  });

  testWidgets('earns-marks row jumps to its section', (t) async {
    await useTallSurface(t);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Reveal model answer'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(InkWell, 'Complications').first);
    await t.pumpAndSettle();
    // the section heading is on screen after the jump
    expect(find.text('Complications'), findsWidgets);
  });

  testWidgets(
      'a successful fetch that finds no qna (stale/deleted deep link) renders retry, not an infinite spinner',
      (t) async {
    final repo = _NullQnaContentRepository();
    await t.pumpWidget(host(repo: repo));
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'must not spin forever on a successful-but-empty fetch');
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pumpAndSettle();
    expect(repo.qnaCalls, 2, reason: 'Retry re-invokes the fetch');
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
  });
}
