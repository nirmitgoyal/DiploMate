import 'package:intl/intl.dart';

/// Device-local study day with the 4am rollover (Anki convention, D10).
/// This exact expression is the shared contract; do not restate it elsewhere.
String localDay(DateTime deviceNow) =>
    DateFormat('yyyy-MM-dd').format(deviceNow.subtract(const Duration(hours: 4)));

/// Due-date arithmetic on "YYYY-MM-DD" strings (calendar days; the 4am rule
/// is already baked into the day string, so plain date math is correct here).
String addLocalDays(String day, int n) {
  final d = DateTime.parse(day).add(Duration(days: n));
  return DateFormat('yyyy-MM-dd').format(d);
}
