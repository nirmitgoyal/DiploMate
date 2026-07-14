import 'package:diplomate/app_providers.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/syllabus/chapter_questions_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterId = '01J0CHAPAIRWAY000000000001';
const _specId = '01J0SPECANAES0000000000001';

SessionUser _user() => const SessionUser(
    id: 'u1', email: 'a@b.c', name: 'Ananya', photoUrl: null,
    specialityId: _specId, specialityChangeCount: 0);

void main() {
  testWidgets(
      'opening a chapter records chapter_opened and lists its questions (not the answer)',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionUserProvider.overrideWith((ref) => _user()),
      ],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ChapterQuestionsScreen(chapterId: _chapterId)),
    ));
    await t.pumpAndSettle();

    // Nav regression (2026-07-14): chapter tap lands on the QUESTION LIST, not
    // the Reader. Breadcrumb walks up (Syllabus / <chapter>), the count line
    // shows, and the Reader's position overline is absent.
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('Airway Management'), findsWidgets);
    expect(find.text('2 questions'), findsOneWidget);
    expect(find.textContaining('QUESTION 1 OF'), findsNothing,
        reason: 'the list, not the Reader');

    // Each row carries the answer's Summary one-liner under the stem so the
    // list reads as a browsable index, not a bare list of stems.
    expect(
        find.text(
            'Declare difficulty early; prioritise oxygenation over intubation at every branch.'),
        findsOneWidget);

    // Metrics regression: the activation event still fires exactly once on
    // chapter open, carrying the CHAPTER ULID (moved off the Reader).
    final events = await db.unsyncedAppEvents();
    final opened = events.where((e) => e.eventType == 'chapter_opened').toList();
    expect(opened, hasLength(1));
    expect(opened.single.contentId, _chapterId);
  });
}
