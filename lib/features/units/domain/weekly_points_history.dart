import 'package:sacdia_app/core/utils/scoring_week.dart';

import 'entities/weekly_record.dart';

/// Puntos de una semana de scoring, ya filtrados al rango pedido.
class WeekPointsSnapshot {
  const WeekPointsSnapshot({
    required this.year,
    required this.week,
    required this.startDate,
    required this.endDate,
    required this.records,
  });

  final int year;
  final int week;
  final DateTime startDate;
  final DateTime endDate;

  /// Miembros de esa semana, de mayor a menor puntaje.
  final List<WeeklyRecord> records;
}

/// Agrupa registros que cruzan [rangeStart]–[rangeEnd].
///
/// Las semanas sin registros no aparecen. El orden es de la más reciente
/// a la más antigua.
List<WeekPointsSnapshot> weeklyPointsInRange({
  required List<WeeklyRecord> records,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final grouped = <String, List<WeeklyRecord>>{};

  for (final record in records) {
    if (!scoringWeekOverlapsRange(
      record.week,
      record.year,
      rangeStart,
      rangeEnd,
    )) {
      continue;
    }
    grouped.putIfAbsent('${record.year}-${record.week}', () => []).add(record);
  }

  final snapshots = grouped.values.map((weekRecords) {
    final sample = weekRecords.first;
    final period = scoringWeekPeriodFor(sample.year, sample.week);
    final sorted = [...weekRecords]..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        return a.fullName.compareTo(b.fullName);
      });
    return WeekPointsSnapshot(
      year: sample.year,
      week: sample.week,
      startDate: period.startDate,
      endDate: period.endDate,
      records: sorted,
    );
  }).toList()
    ..sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      if (byYear != 0) return byYear;
      return b.endDate.compareTo(a.endDate);
    });

  return snapshots;
}
