import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/finances_reminder_push_route.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

const _adult =
    UserEntity(id: 'u-1', email: 'a@b.c', postRegisterComplete: true);

const _teen = UserEntity(
  id: 'u-2',
  email: 't@b.c',
  principal: PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.active),
  ),
);

void main() {
  group('finances_reminder routing', () {
    test('recognises the push type and the inbox source', () {
      expect(isFinancesReminderPushType('finances_reminder'), isTrue);
      expect(isFinancesReminderPushType(' finances_reminder '), isTrue);
      expect(isFinancesReminderPushType('monthly_report_reminder'), isFalse);
      expect(isFinancesReminderPushType(null), isFalse);
      expect(isFinancesReminderSource('finances:reminder'), isTrue);
      expect(isFinancesReminderSource('Finances:Reminder'), isTrue);
      expect(isFinancesReminderSource('finances:other'), isFalse);
      expect(isFinancesReminderSource('monthly_reports:reminder'), isFalse);
      expect(isFinancesReminderSource(null), isFalse);
    });

    test('an adult account lands on the finances screen', () {
      expect(
        financesReminderRouteFor(_adult, acting: false),
        RouteNames.homeFinances,
      );
    });

    test('nothing opens while acting for a dependent', () {
      expect(financesReminderRouteFor(_adult, acting: true), isNull);
    });

    test('nothing opens without a session or for a supervised teen', () {
      expect(financesReminderRouteFor(null, acting: false), isNull);
      expect(financesReminderRouteFor(_teen, acting: false), isNull);
    });
  });
}
