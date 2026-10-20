import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/device_push_route.dart';
import 'package:sacdia_app/features/device_mode/domain/utils/device_label.dart';
import 'package:sacdia_app/features/device_mode/domain/utils/next_activity.dart';

import 'device_test_harness.dart';

void main() {
  group('sanitizeDeviceLabel', () {
    test('keeps a normal name', () {
      expect(sanitizeDeviceLabel('Tablet de Ana'), 'Tablet de Ana');
    });

    test('drops control and bidi characters and collapses spaces', () {
      final dirty = [
        '  Tablet',
        String.fromCharCode(0),
        '\n de ',
        String.fromCharCode(0x202E),
        '  Ana',
        String.fromCharCode(0x200B),
        ' ',
      ].join();
      expect(sanitizeDeviceLabel(dirty), 'Tablet de Ana');
    });

    test('cuts to 40 characters without splitting an emoji', () {
      final label = sanitizeDeviceLabel('${'a' * 39}😀😀😀');
      expect(label.runes.length, 40);
      expect(label.endsWith('😀'), isTrue);
      expect(sanitizeDeviceLabel('x' * 500).length, 40);
    });

    test('a hostile label stays short text, never a crash', () {
      final label = sanitizeDeviceLabel('<script>alert(1)</script>' * 5);
      expect(label.length, lessThanOrEqualTo(kDeviceLabelMaxLength));
    });

    test('empty stays empty', () {
      expect(sanitizeDeviceLabel('   \n\t '), '');
    });
  });

  group('nextUpcomingActivity', () {
    final now = DateTime(2026, 10, 20, 15);

    test('picks the earliest of today and later', () {
      final list = [
        activity(1, name: 'Lejos', date: DateTime(2026, 11, 20)),
        activity(2, name: 'Hoy', date: DateTime(2026, 10, 20, 8)),
        activity(3, name: 'Ayer', date: DateTime(2026, 10, 19)),
        activity(4, name: 'Mañana', date: DateTime(2026, 10, 21)),
      ];
      expect(nextUpcomingActivity(list, now)!.name, 'Hoy');
    });

    test('nothing upcoming is null', () {
      expect(nextUpcomingActivity(const [], now), isNull);
      expect(
        nextUpcomingActivity([activity(1, date: DateTime(2026, 1, 1))], now),
        isNull,
      );
    });
  });

  group('deviceRouteForPush', () {
    test('class and activity pushes open the device detail', () {
      expect(deviceRouteForPush({'route': '/class/3'}),
          RouteNames.deviceClassDetailPath(3));
      expect(deviceRouteForPush({'route': '/activity/12'}),
          RouteNames.deviceActivityDetailPath(12));
    });

    test('everything else opens the notices tab', () {
      for (final data in [
        <String, dynamic>{},
        {'route': RouteNames.family},
        {'route': '/class/abc'},
        {'route': '/class/3/extra'},
        {'route': 42},
        {'type': 'achievement_unlocked'},
        {'dependent_user_id': 'x', 'route': RouteNames.homeDashboard},
      ]) {
        expect(deviceRouteForPush(data), RouteNames.deviceInbox,
            reason: '$data');
      }
    });
  });
}
