/// Countdown label for an activity starting at [target], seen at [now].
///
/// Both values must be local times. "Tomorrow"/"N days" use calendar-day
/// difference, not elapsed 24h blocks: Thu 10:15 → Sat 09:00 is 46h but two
/// calendar days, so it reads "En 2 días", not "Mañana". Returns `null` when
/// the activity is a week or more away.
({String key, Map<String, String> args, bool isPast, bool isUrgent})?
    activityCountdown(DateTime target, DateTime now) {
  // UTC midnights avoid DST shifts when counting calendar days.
  final dayDiff = DateTime.utc(target.year, target.month, target.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  final diff = target.difference(now);

  if (diff.isNegative) {
    final past = now.difference(target);
    final daysAgo = -dayDiff;
    if (past.inMinutes < 60) {
      return (
        key: 'activities.widgets.countdown_finished',
        args: const {},
        isPast: true,
        isUrgent: false
      );
    }
    if (daysAgo == 0) {
      return (
        key: 'activities.widgets.countdown_finished_hours',
        args: {'hours': '${past.inHours}'},
        isPast: true,
        isUrgent: false
      );
    }
    if (daysAgo == 1) {
      return (
        key: 'activities.widgets.countdown_finished_yesterday',
        args: const {},
        isPast: true,
        isUrgent: false
      );
    }
    if (daysAgo < 7) {
      return (
        key: 'activities.widgets.countdown_finished_days',
        args: {'days': '$daysAgo'},
        isPast: true,
        isUrgent: false
      );
    }
    return (
      key: 'activities.widgets.countdown_finished',
      args: const {},
      isPast: true,
      isUrgent: false
    );
  }

  if (diff.inMinutes < 60) {
    return (
      key: 'activities.widgets.countdown_minutes',
      args: {'minutes': '${diff.inMinutes.clamp(1, 59)}'},
      isPast: false,
      isUrgent: true
    );
  }
  if (dayDiff == 0) {
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return m > 0
        ? (
            key: 'activities.widgets.countdown_hours_minutes',
            args: {'hours': '$h', 'minutes': '$m'},
            isPast: false,
            isUrgent: false
          )
        : (
            key: 'activities.widgets.countdown_hours',
            args: {'hours': '$h'},
            isPast: false,
            isUrgent: false
          );
  }
  if (dayDiff == 1) {
    return (
      key: 'activities.widgets.countdown_tomorrow',
      args: const {},
      isPast: false,
      isUrgent: false
    );
  }
  if (dayDiff < 7) {
    return (
      key: 'activities.widgets.countdown_days',
      args: {'days': '$dayDiff'},
      isPast: false,
      isUrgent: false
    );
  }
  return null;
}
