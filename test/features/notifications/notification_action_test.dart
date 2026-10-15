import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/notifications/domain/notification_action.dart';

void main() {
  test('monthly report reminders open the Reportes screen', () {
    final action = notificationActionFor('monthly_reports:reminder');

    expect(action, isNotNull);
    expect(action!.route, RouteNames.homeReports);
    expect(action.labelKey, 'notifications.inbox.detail_open_reports');
  });

  test('sources without a destination have no action', () {
    expect(notificationActionFor('admin:manual_send'), isNull);
    expect(notificationActionFor(null), isNull);
  });
}
