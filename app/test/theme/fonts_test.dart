import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('fonts are bundled OFL assets, google_fonts is not a dependency (ENG-T21)', () {
    expect(pubspec.contains('google_fonts'), isFalse,
        reason: 'runtime font fetching is banned (ENG-T21)');
    expect(pubspec, contains('family: SourceSerif4'));
    expect(pubspec, contains('family: Manrope'));
    expect(File('assets/fonts/SourceSerif4[opsz,wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/SourceSerif4-Italic[opsz,wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/Manrope[wght].ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-SourceSerif4.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Manrope.txt').existsSync(), isTrue);
  });

  test('stack locks: only approved packages are declared', () {
    expect(pubspec, contains('flutter_riverpod'));
    expect(pubspec, contains('go_router'));
  });
}
