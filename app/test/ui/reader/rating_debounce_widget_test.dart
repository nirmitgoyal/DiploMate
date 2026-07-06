import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/repos/study_repository.dart';
import 'package:diplomate/domain/models.dart';
import 'package:diplomate/ui/reader/reader_controller.dart';

/// Minimal harness mirroring the plan-4 tray wiring contract:
/// tray order Easy - Medium - Hard, onPressed = controller.rate,
/// buttons disabled while ratingInFlight.
class _TrayHarness extends StatelessWidget {
  const _TrayHarness(this.controller);
  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            children: [
              Text(controller.complete
                  ? 'complete'
                  : 'Suggestion · ${controller.position} of ${controller.total}'),
              for (final rating in const [
                WireRating.good, // "Easy"
                WireRating.hard, // "Medium"
                WireRating.again, // "Hard"
              ])
                ElevatedButton(
                  onPressed: controller.ratingInFlight
                      ? null
                      : () => controller.rate(rating),
                  child: Text(uiLabelForWire[rating]!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
      'double-tapping a rating yields EXACTLY one review event and one '
      'queue advance (CEO-T5)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = StudyRepository(db);
    final controller =
        ReaderController.queue(repo: repo, queue: ['Q1', 'Q2', 'Q3']);
    await controller.reveal();

    await tester.pumpWidget(_TrayHarness(controller));
    expect(find.text('Suggestion · 1 of 3'), findsOneWidget);

    // Two taps in the same frame - the classic double-tap race.
    await tester.tap(find.text('Easy'));
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1, reason: 'double-tap must not double-count');
    expect(controller.position, 2, reason: 'exactly one queue advance');
    expect(find.text('Suggestion · 2 of 3'), findsOneWidget);
  });

  testWidgets('tapping two DIFFERENT tiers rapidly still yields one event',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = StudyRepository(db);
    final controller = ReaderController.queue(repo: repo, queue: ['Q1', 'Q2']);
    await controller.reveal();

    await tester.pumpWidget(_TrayHarness(controller));
    await tester.tap(find.text('Easy'));
    await tester.tap(find.text('Hard')); // second tap during in-flight persist
    await tester.pumpAndSettle();

    final rows = await db.select(db.pendingReviewEvents).get();
    expect(rows.length, 1);
    expect(rows.single.rating, 'good'); // the FIRST tap won
    expect(controller.position, 2);
  });
}
