/// Unit scoring week: Sunday 00:00 → Saturday 23:59 in America/Mexico_City.
///
/// Mexico City has been UTC-6 year-round since 2022, matching IANA
/// `America/Mexico_City`. The backend uses that zone via Intl; this helper
/// uses a fixed UTC-6 offset so the app does not need a TZ database.
library;

const Duration kMexicoCityOffsetFromUtc = Duration(hours: -6);

class ScoringWeekPeriod {
  const ScoringWeekPeriod({
    required this.week,
    required this.year,
    required this.startDate,
    required this.endDate,
  });

  final int week;
  final int year;

  /// Sunday of the scoring week (date-only).
  final DateTime startDate;

  /// Saturday of the scoring week (date-only).
  final DateTime endDate;
}

DateTime mexicoCityWallTime([DateTime? now]) {
  return (now ?? DateTime.now()).toUtc().add(kMexicoCityOffsetFromUtc);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime _firstSaturdayOfYear(int year) {
  final jan1 = DateTime(year, 1, 1);
  final daysUntilSaturday = (DateTime.saturday - jan1.weekday) % 7;
  return _addDays(jan1, daysUntilSaturday);
}

int _weekNumberForSaturday(DateTime saturday) {
  final firstSaturday = _firstSaturdayOfYear(saturday.year);
  return 1 + saturday.difference(firstSaturday).inDays ~/ 7;
}

ScoringWeekPeriod getScoringWeekPeriod([DateTime? now]) {
  final today = _dateOnly(mexicoCityWallTime(now));
  final daysFromSunday = today.weekday % DateTime.sunday;
  final startDate = _addDays(today, -daysFromSunday);
  final endDate = _addDays(startDate, 6);

  return ScoringWeekPeriod(
    week: _weekNumberForSaturday(endDate),
    year: endDate.year,
    startDate: startDate,
    endDate: endDate,
  );
}
