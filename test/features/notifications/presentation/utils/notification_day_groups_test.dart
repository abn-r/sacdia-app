import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/utils/notification_day_groups.dart';
import '../../../../support/l10n_test_support.dart';

NotificationItem _item(int id, DateTime at, {bool read = false}) =>
    NotificationItem(
      logId: id,
      title: 'n$id',
      body: '',
      type: 'info',
      targetType: NotificationTargetType.direct,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: at,
      isRead: read,
    );

void main() {
  setUpAll(loadSpanishTranslations);

  final now = DateTime(2026, 11, 5, 16, 0);

  test('buckets today, yesterday, this week, then one group per month', () {
    final groups = groupNotificationsByDay([
      _item(1, DateTime(2026, 11, 5, 9)),
      _item(2, DateTime(2026, 11, 5, 8), read: true),
      _item(3, DateTime(2026, 11, 4, 19)),
      _item(4, DateTime(2026, 10, 30, 10)),
      _item(5, DateTime(2026, 10, 28, 10)),
      _item(6, DateTime(2026, 10, 2, 10)),
      _item(7, DateTime(2026, 9, 20, 10)),
    ], now: now);

    expect(groups.map((g) => g.bucket), [
      NotificationDayBucket.today,
      NotificationDayBucket.yesterday,
      NotificationDayBucket.thisWeek,
      NotificationDayBucket.month,
      NotificationDayBucket.month,
    ]);
    expect(groups.map((g) => g.items.map((n) => n.logId).toList()), [
      [1, 2],
      [3],
      [4],
      [5, 6],
      [7],
    ]);
    expect(groups.first.unreadCount, 1);
    expect(groups.first.label, 'Hoy');
    expect(groups[1].label, 'Ayer');
    expect(groups[2].label, 'Esta semana');
  });

  test('row time fits the group', () {
    expect(
      notificationGroupedTime(
        _item(1, DateTime(2026, 11, 5, 9)),
        NotificationDayBucket.today,
        now: now,
      ),
      'hace 7 h',
    );
    expect(
      notificationGroupedTime(
        _item(2, DateTime(2026, 11, 5, 15, 48)),
        NotificationDayBucket.today,
        now: now,
      ),
      'hace 12 min',
    );
    expect(
      notificationGroupedTime(
        _item(3, DateTime(2026, 11, 4, 19, 5)),
        NotificationDayBucket.yesterday,
        now: now,
      ),
      '19:05',
    );
  });
}
