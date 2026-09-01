/// Relative time for inbox/sheet. Null when the calendar date is clearer.
String? notificationRelativePhrase(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(date);

  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} hs';

  final todayMidnight = DateTime(current.year, current.month, current.day);
  final dateMidnight = DateTime(date.year, date.month, date.day);
  final daysDiff = todayMidnight.difference(dateMidnight).inDays;

  if (daysDiff == 1) return 'ayer';
  if (daysDiff > 1 && daysDiff < 7) return 'hace $daysDiff días';
  return null;
}

String notificationAbsoluteStamp(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}

String notificationInboxTime(DateTime date, {DateTime? now}) {
  return notificationRelativePhrase(date, now: now) ??
      notificationAbsoluteStamp(date).split(' ').first;
}

/// Absolute stamp, plus a relative phrase only when it adds information.
String notificationReceivedLabel(DateTime date, {DateTime? now}) {
  final absolute = notificationAbsoluteStamp(date);
  final relative = notificationRelativePhrase(date, now: now);
  if (relative == null) return absolute;
  return '$absolute · $relative';
}
