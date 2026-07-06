import 'package:flutter_test/flutter_test.dart';
import 'package:diplomate/domain/local_day.dart';

void main() {
  group('localDay (4am local rollover, Anki convention)', () {
    test('03:59 still belongs to the previous day', () {
      expect(localDay(DateTime(2026, 7, 4, 3, 59)), '2026-07-03');
    });
    test('04:00 starts the new day', () {
      expect(localDay(DateTime(2026, 7, 4, 4, 0)), '2026-07-04');
    });
    test('23:59 is the same calendar day', () {
      expect(localDay(DateTime(2026, 7, 4, 23, 59)), '2026-07-04');
    });
    test('00:01 is still the previous calendar day', () {
      expect(localDay(DateTime(2026, 7, 5, 0, 1)), '2026-07-04');
    });
    test('month boundary: Aug 1 03:00 is Jul 31', () {
      expect(localDay(DateTime(2026, 8, 1, 3, 0)), '2026-07-31');
    });
  });

  group('addLocalDays', () {
    test('adds within a month', () {
      expect(addLocalDays('2026-07-04', 2), '2026-07-06');
    });
    test('crosses month and year boundaries', () {
      expect(addLocalDays('2026-12-30', 3), '2027-01-02');
    });
    test('zero days is identity', () {
      expect(addLocalDays('2026-07-04', 0), '2026-07-04');
    });
  });
}
