import 'dart:typed_data';

import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/fixtures/fixture_content_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/data/repos/content_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/syllabus/syllabus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessionUser userWith(String specId) => SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: specId, specialityChangeCount: 0);

Widget host(String specId, {ContentRepository? repo}) => ProviderScope(
      overrides: [
        sessionUserProvider.overrideWith((ref) => userWith(specId)),
        if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(theme: dmLightTheme(), home: const SyllabusScreen()),
    );

/// Throws from chapters() to exercise the inline retry state - the shipped
/// fixture never fails chapters()/specialities(), only ensureChapterCached().
class _ThrowingContentRepository implements ContentRepository {
  int chapterCalls = 0;

  @override
  Future<List<SpecialityRow>> specialities() async => const [
        SpecialityRow(id: 's1', name: 'Anaesthesiology', examType: 'DNB',
            slug: 'anaesthesiology', sortOrder: 1, hasContent: true),
      ];

  @override
  Future<List<ChapterRow>> chapters(String specialityId) async {
    chapterCalls++;
    throw ContentFetchException(specialityId);
  }

  @override
  Future<void> ensureChapterCached(String chapterId) async {}

  @override
  Future<List<TopicRow>> topics(String chapterId) async => const [];

  @override
  Future<List<QnaRow>> qnas(String topicId) async => const [];

  @override
  Future<QnaRow?> qna(String qnaId) async => null;

  @override
  Future<Uint8List> imageBytes(String imageId) async => Uint8List(0);
}

void main() {
  testWidgets('chapter rows: title, topic count, recall progress; no locks, no download UI',
      (t) async {
    await t.pumpWidget(host('01J0SPECANAES0000000000001'));
    await t.pumpAndSettle();
    expect(find.text('Anaesthesiology'), findsOneWidget);
    expect(find.text('Airway Management'), findsOneWidget);
    expect(find.text('2 topics'), findsOneWidget);
    expect(find.text('0/2 recalled'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.textContaining('ffline'), findsNothing, reason: 'no offline copy');
    expect(find.textContaining('ownload'), findsNothing, reason: 'no download copy');
  });

  testWidgets('empty track renders the first-class no-content state (DESIGN.md State 9)',
      (t) async {
    // any non-Anaesthesiology fixture id has no content
    final repo = FixtureContentRepository();
    final specs = await repo.specialities();
    final empty = specs.firstWhere((s) => !s.hasContent);

    await t.pumpWidget(host(empty.id));
    await t.pumpAndSettle();
    expect(find.text('No answers here yet'), findsOneWidget);
    expect(
        find.text(
            '${empty.name} answers are being written. Your pick counts - it tells us which speciality we publish next.'),
        findsOneWidget);
    expect(find.text('You can change your speciality once in Account.'),
        findsOneWidget);
    expect(find.textContaining('ffline'), findsNothing);
    expect(find.textContaining('ownload'), findsNothing);
  });

  testWidgets('catalog fetch failure renders the inline retry state (DESIGN.md State 10)',
      (t) async {
    final repo = _ThrowingContentRepository();
    await t.pumpWidget(host('s1', repo: repo));
    await t.pumpAndSettle();
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pumpAndSettle();
    expect(repo.chapterCalls, 2, reason: 'Retry re-invokes the load');
    expect(find.text("Couldn't load this - retry"), findsOneWidget);
  });
}
