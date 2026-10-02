import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/scoring_week.dart';
import 'package:sacdia_app/features/units/domain/entities/weekly_record.dart';
import 'package:sacdia_app/features/units/domain/weekly_points_history.dart';

void main() {
  test('keeps weeks inside the ecclesiastical year, newest first', () {
    final inside = scoringWeekPeriodFor(2026, 10);
    final later = scoringWeekPeriodFor(2026, 12);
    final outside = scoringWeekPeriodFor(2024, 10);

    final groups = weeklyPointsInRange(
      records: [
        _record(week: inside.week, year: 2026, points: 8, name: 'Ana'),
        _record(week: outside.week, year: 2024, points: 40, name: 'Luis'),
        _record(week: inside.week, year: 2026, points: 15, name: 'Bea'),
        _record(week: later.week, year: 2026, points: 4, name: 'Ana'),
      ],
      rangeStart: DateTime(2025, 9, 1),
      rangeEnd: DateTime(2026, 8, 31),
    );

    expect(groups.map((group) => group.week), [12, 10]);
    expect(groups.first.records.single.points, 4);
    expect(groups.last.records.map((record) => record.points), [15, 8]);
    expect(groups.last.startDate, inside.startDate);
  });
}

WeeklyRecord _record({
  required int week,
  required int year,
  required int points,
  required String name,
}) {
  return WeeklyRecord(
    recordId: week * 10 + points,
    userId: name,
    week: week,
    year: year,
    attendance: 0,
    punctuality: 0,
    points: points,
    userName: name,
  );
}
