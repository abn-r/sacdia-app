import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_info_strip.dart';

void main() {
  // Thursday 15 Oct 2026, 10:15 local.
  final now = DateTime(2026, 10, 15, 10, 15);

  String? keyFor(DateTime target) =>
      activityCountdown(target, now)?.key.split('.').last;

  test('Saturday 09:00 (46h, two calendar days) reads "in 2 days"', () {
    final result = activityCountdown(DateTime(2026, 10, 17, 9), now)!;
    expect(result.key, 'activities.widgets.countdown_days');
    expect(result.args, {'days': '2'});
  });

  test('next calendar day is tomorrow, early or late', () {
    expect(keyFor(DateTime(2026, 10, 16, 8)), 'countdown_tomorrow');
    expect(keyFor(DateTime(2026, 10, 16, 23, 30)), 'countdown_tomorrow');
    expect(
      activityCountdown(
        DateTime(2026, 10, 16, 7),
        DateTime(2026, 10, 15, 22),
      )!
          .key,
      'activities.widgets.countdown_tomorrow',
    );
  });

  test('later today shows hours and minutes', () {
    final result = activityCountdown(DateTime(2026, 10, 15, 13, 45), now)!;
    expect(result.key, 'activities.widgets.countdown_hours_minutes');
    expect(result.args, {'hours': '3', 'minutes': '30'});
    expect(keyFor(DateTime(2026, 10, 15, 12, 15)), 'countdown_hours');
  });

  test('under an hour is urgent minutes', () {
    final result = activityCountdown(DateTime(2026, 10, 15, 10, 45), now)!;
    expect(result.key, 'activities.widgets.countdown_minutes');
    expect(result.isUrgent, isTrue);
  });

  test('a week or more away shows no countdown', () {
    expect(keyFor(DateTime(2026, 10, 21, 9)), 'countdown_days');
    expect(activityCountdown(DateTime(2026, 10, 22, 9), now), isNull);
  });

  test('crosses month boundaries by calendar day', () {
    expect(
      activityCountdown(DateTime(2026, 11, 1, 9), DateTime(2026, 10, 31, 8))!
          .key,
      'activities.widgets.countdown_tomorrow',
    );
  });

  test('past activities use calendar days too', () {
    expect(keyFor(DateTime(2026, 10, 15, 10)), 'countdown_finished');
    final earlier = activityCountdown(DateTime(2026, 10, 15, 7), now)!;
    expect(earlier.key, 'activities.widgets.countdown_finished_hours');
    expect(earlier.args, {'hours': '3'});
    expect(earlier.isPast, isTrue);
    // 34h ago but yesterday on the calendar.
    expect(
        keyFor(DateTime(2026, 10, 14, 0, 15)), 'countdown_finished_yesterday');
    final days = activityCountdown(DateTime(2026, 10, 13, 20), now)!;
    expect(days.key, 'activities.widgets.countdown_finished_days');
    expect(days.args, {'days': '2'});
    expect(keyFor(DateTime(2026, 10, 1, 9)), 'countdown_finished');
  });
}
