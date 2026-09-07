import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/scoring_week.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity_instance.dart';
import 'package:sacdia_app/features/units/domain/week_activities.dart';

Activity _activity({
  required int id,
  required DateTime date,
  int clubSectionId = 8,
  bool active = true,
  bool isJoint = false,
  List<ActivityInstance>? instances,
  DateTime? endDate,
  String? time,
}) {
  return Activity(
    id: id,
    name: 'Actividad $id',
    activityPlace: 'Sede',
    activityType: 1,
    platform: 0,
    active: active,
    clubSectionId: clubSectionId,
    clubTypeId: 2,
    activityDate: date,
    activityEndDate: endDate,
    activityTime: time,
    isJoint: isJoint,
    instances: instances,
  );
}

void main() {
  group('getScoringWeekPeriod', () {
    test('keeps Monday 2026-06-29 UTC in week 27', () {
      final period = getScoringWeekPeriod(
        DateTime.utc(2026, 6, 29, 12),
      );

      expect(period.week, 27);
      expect(period.year, 2026);
      expect(period.startDate, DateTime(2026, 6, 28));
      expect(period.endDate, DateTime(2026, 7, 4));
    });

    test('stays on the same week at Saturday 23:59 Mexico', () {
      final period = getScoringWeekPeriod(
        DateTime.utc(2026, 7, 5, 5, 59),
      );

      expect(period.week, 27);
      expect(period.endDate, DateTime(2026, 7, 4));
    });

    test('opens a new week at Sunday 00:00 Mexico', () {
      final period = getScoringWeekPeriod(
        DateTime.utc(2026, 7, 5, 6),
      );

      expect(period.week, 28);
      expect(period.startDate, DateTime(2026, 7, 5));
      expect(period.endDate, DateTime(2026, 7, 11));
    });
  });

  group('activitiesForScoringWeek', () {
    final period = ScoringWeekPeriod(
      week: 27,
      year: 2026,
      startDate: DateTime(2026, 6, 28),
      endDate: DateTime(2026, 7, 4),
    );

    test('keeps section activities that fall in the week', () {
      final activities = [
        _activity(id: 1, date: DateTime(2026, 7, 4), time: '16:00'),
        _activity(id: 2, date: DateTime(2026, 7, 5)),
        _activity(
          id: 3,
          date: DateTime(2026, 7, 4),
          clubSectionId: 9,
        ),
        _activity(
          id: 4,
          date: DateTime(2026, 7, 4),
          active: false,
        ),
      ];

      final matched = activitiesForScoringWeek(
        activities: activities,
        period: period,
        sectionId: 8,
      );

      expect(matched.map((activity) => activity.id), [1]);
    });

    test('includes joint activities via instances', () {
      final matched = activitiesForScoringWeek(
        activities: [
          _activity(
            id: 10,
            date: DateTime(2026, 7, 4),
            clubSectionId: 1,
            isJoint: true,
            instances: const [
              ActivityInstance(clubSectionId: 8),
            ],
          ),
        ],
        period: period,
        sectionId: 8,
      );

      expect(matched, hasLength(1));
    });
  });
}
