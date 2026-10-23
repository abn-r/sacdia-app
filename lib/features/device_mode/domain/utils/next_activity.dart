import '../../../activities/domain/entities/activity.dart';

/// La próxima actividad (hoy o más adelante) de [activities], o `null`.
///
/// Compara por día de calendario: una actividad de hoy cuenta aunque su hora ya
/// haya pasado.
Activity? nextUpcomingActivity(List<Activity> activities, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  Activity? best;
  for (final activity in activities) {
    final date = activity.activityDate;
    if (date == null || !activity.active) continue;
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) continue;
    final bestDate = best?.activityDate;
    if (bestDate == null || date.isBefore(bestDate)) best = activity;
  }
  return best;
}
