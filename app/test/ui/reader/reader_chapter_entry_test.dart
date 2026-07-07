import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/providers/study_providers.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/reader_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapterId = '01J0CHAPAIRWAY000000000001';

void main() {
  testWidgets(
      'opening a chapter records chapter_opened with the chapter ULID and shows question 1',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
          theme: dmLightTheme(),
          home: const ReaderScreen.chapter(chapterId: _chapterId)),
    ));
    await t.pumpAndSettle();

    // Nav regression: chapter entry lands on the reader, first question visible.
    // The overline renders display-uppercased (reader_view.dart), so the finder
    // matches the rendered casing, not the source 'Question i of N'.
    expect(find.text('Airway Management'), findsWidgets);
    expect(find.textContaining('QUESTION 1 OF'), findsOneWidget);

    // Metrics regression (rewrite 4, app half): the activation event exists,
    // renamed, carrying the CHAPTER ULID.
    final events = await db.unsyncedAppEvents();
    final opened = events.where((e) => e.eventType == 'chapter_opened').toList();
    expect(opened, hasLength(1));
    expect(opened.single.contentId, _chapterId);
  });
}
