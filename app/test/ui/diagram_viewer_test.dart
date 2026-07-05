import 'package:diplomate/domain/models.dart';
import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/ui/reader/diagram_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _img = ImageRow(
    id: 'i1',
    caption: 'Fig 1 - TAP block: needle in the plane',
    contentDescription: 'Ultrasound cross-section of the abdominal wall',
    byteSize: 44,
    sha256: 'x',
    sortOrder: 1);

// 1x1 white WebP
final _bytes = Uint8List.fromList(const [
  0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
  0x56, 0x50, 0x38, 0x20, 0x18, 0x00, 0x00, 0x00, 0x30, 0x01, 0x00, 0x9D,
  0x01, 0x2A, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x1C, 0x25, 0xA4, 0x00,
  0x03, 0x70, 0x00, 0xFE, 0xFD, 0xC0, 0x80, 0x00
]);

Widget host() => MaterialApp(
    theme: dmLightTheme(),
    home: Scaffold(
        body: DiagramPlate(image: _img, bytesLoader: () async => _bytes)));

void main() {
  testWidgets('plate shows caption + single Tap to enlarge affordance', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('Fig 1'), findsOneWidget);
    expect(find.text('Tap to enlarge'), findsOneWidget);
    expect(find.textContaining('Pinch'), findsNothing,
        reason: 'labels do not lie: inline has no pinch gesture');
  });

  testWidgets('viewer opens with rotate pill + gesture hint, Escape closes', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Tap to enlarge'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Rotate for a larger view'), findsOneWidget);
    expect(find.text('Pinch or double-tap to zoom · drag to pan'), findsOneWidget);

    await t.tap(find.text('Rotate for a larger view'));
    await t.pumpAndSettle();
    expect(find.text('Back to portrait'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
