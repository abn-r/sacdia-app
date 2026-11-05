import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/notification_item.dart';

/// Which day bucket an inbox group covers.
enum NotificationDayBucket { today, yesterday, thisWeek, month }

/// Consecutive notifications of the same day bucket (or calendar month for
/// anything older than a week), in the order the inbox received them.
class NotificationDayGroup {
  NotificationDayGroup({required this.bucket, this.month});

  final NotificationDayBucket bucket;

  /// First day of the month for [NotificationDayBucket.month] groups.
  final DateTime? month;

  final List<NotificationItem> items = [];

  int get unreadCount => items.where((n) => !n.isRead).length;

  /// «Hoy», «Ayer», «Esta semana» or the month («Octubre de 2026»).
  String get label {
    switch (bucket) {
      case NotificationDayBucket.today:
        return 'notifications.inbox.group_today'.tr();
      case NotificationDayBucket.yesterday:
        return 'notifications.inbox.group_yesterday'.tr();
      case NotificationDayBucket.thisWeek:
        return 'notifications.inbox.group_this_week'.tr();
      case NotificationDayBucket.month:
        final text = DateFormat.yMMMM().format(month!);
        return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    }
  }
}

/// Groups [items] (newest first) by local calendar day: today, yesterday, the
/// rest of the last 7 days, then one group per month.
List<NotificationDayGroup> groupNotificationsByDay(
  List<NotificationItem> items, {
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final groups = <NotificationDayGroup>[];

  for (final item in items) {
    final local = item.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(day).inDays;

    final NotificationDayBucket bucket;
    DateTime? month;
    if (daysAgo <= 0) {
      bucket = NotificationDayBucket.today;
    } else if (daysAgo == 1) {
      bucket = NotificationDayBucket.yesterday;
    } else if (daysAgo < 7) {
      bucket = NotificationDayBucket.thisWeek;
    } else {
      bucket = NotificationDayBucket.month;
      month = DateTime(local.year, local.month);
    }

    final last = groups.isEmpty ? null : groups.last;
    if (last != null && last.bucket == bucket && last.month == month) {
      last.items.add(item);
    } else {
      groups.add(
        NotificationDayGroup(bucket: bucket, month: month)..items.add(item),
      );
    }
  }
  return groups;
}

/// Time shown on a row inside its day group: relative today, the clock time
/// yesterday, the weekday this week and the day of the month for older ones.
String notificationGroupedTime(
  NotificationItem item,
  NotificationDayBucket bucket, {
  DateTime? now,
}) {
  final local = item.createdAt.toLocal();
  final current = now ?? DateTime.now();
  switch (bucket) {
    case NotificationDayBucket.today:
      final diff = current.difference(item.createdAt);
      if (diff.inMinutes < 1) return 'notifications.inbox.time_now'.tr();
      if (diff.inMinutes < 60) {
        return 'notifications.inbox.time_minutes'
            .tr(namedArgs: {'n': '${diff.inMinutes}'});
      }
      return 'notifications.inbox.time_hours'
          .tr(namedArgs: {'n': '${diff.inHours}'});
    case NotificationDayBucket.yesterday:
      return DateFormat.Hm().format(local);
    case NotificationDayBucket.thisWeek:
      return DateFormat.E().format(local);
    case NotificationDayBucket.month:
      return DateFormat.MMMd().format(local);
  }
}
