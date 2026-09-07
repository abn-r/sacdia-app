import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/core/utils/scoring_week.dart';

bool activityBelongsToSection(Activity activity, int? sectionId) {
  if (sectionId == null) return false;
  final instances = activity.instances;
  if (instances != null && instances.isNotEmpty) {
    return instances.any((instance) => instance.clubSectionId == sectionId);
  }
  return activity.clubSectionId == sectionId;
}

bool activityOverlapsScoringWeek(Activity activity, ScoringWeekPeriod period) {
  final start = activity.activityDate;
  if (start == null) return false;
  final end = activity.activityEndDate ?? start;
  return !end.isBefore(period.startDate) && !start.isAfter(period.endDate);
}

List<Activity> activitiesForScoringWeek({
  required List<Activity> activities,
  required ScoringWeekPeriod period,
  required int? sectionId,
}) {
  final matched = activities
      .where(
        (activity) =>
            activity.active &&
            activityBelongsToSection(activity, sectionId) &&
            activityOverlapsScoringWeek(activity, period),
      )
      .toList()
    ..sort((a, b) {
      final aDate = a.activityDate ?? DateTime(1970);
      final bDate = b.activityDate ?? DateTime(1970);
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) return byDate;
      return (a.activityTime ?? '').compareTo(b.activityTime ?? '');
    });
  return matched;
}
