import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/notifications/domain/notification_time.dart';

void main() {
  final now = DateTime(2026, 8, 31, 18, 45);

  group('notificationReceivedLabel', () {
    test('does not repeat the calendar date for old notifications', () {
      final created = DateTime(2026, 7, 14, 14, 16);

      expect(
        notificationReceivedLabel(created, now: now),
        '14/07/2026 14:16',
      );
    });

    test('keeps a relative phrase when it is not a date', () {
      final created = DateTime(2026, 8, 31, 18, 38);

      expect(
        notificationReceivedLabel(created, now: now),
        '31/08/2026 18:38 · hace 7 min',
      );
    });
  });

  group('notificationInboxTime', () {
    test('uses a date for items older than a week', () {
      expect(
        notificationInboxTime(DateTime(2026, 7, 14, 14, 16), now: now),
        '14/07/2026',
      );
    });
  });
}
