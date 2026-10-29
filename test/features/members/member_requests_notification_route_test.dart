import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/members/presentation/utils/member_requests_notification_route.dart';

UserEntity _user(List<String> permissions) => UserEntity(
      id: 'u-1',
      email: 'a@b.c',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(effectivePermissions: permissions),
    );

void main() {
  group('isMembershipRequestSource', () {
    test('matches the new_request source and any sibling of the prefix', () {
      expect(
        isMembershipRequestSource('membership_requests:new_request'),
        isTrue,
      );
      expect(
        isMembershipRequestSource(' Membership_Requests:consent_verified '),
        isTrue,
      );
    });

    test('ignores other sources', () {
      expect(isMembershipRequestSource('monthly_reports:reminder'), isFalse);
      expect(isMembershipRequestSource('family:consent_verified'), isFalse);
      expect(isMembershipRequestSource(null), isFalse);
      expect(isMembershipRequestSource(''), isFalse);
    });
  });

  group('isMembershipRequestPushType', () {
    test('matches the backend data.type only', () {
      expect(isMembershipRequestPushType('membership_request_created'), isTrue);
      expect(isMembershipRequestPushType('investiture_result'), isFalse);
      expect(isMembershipRequestPushType(null), isFalse);
    });
  });

  group('memberRequestsRouteFor', () {
    test('an approver opens Members on the requests tab', () {
      expect(
        memberRequestsRouteFor(_user(['club_members:approve'])),
        RouteNames.homeMemberRequests,
      );
      expect(RouteNames.homeMemberRequests, '/home/members?tab=requests');
    });

    test('a verify-only reviewer with club authority also gets the route', () {
      expect(
        memberRequestsRouteFor(_user(['consent:verify'])),
        RouteNames.homeMemberRequests,
      );
    });

    test('without approve/verify, or without a user, there is no destination',
        () {
      expect(memberRequestsRouteFor(_user(['club_members:read'])), isNull);
      expect(memberRequestsRouteFor(_user(const [])), isNull);
      expect(memberRequestsRouteFor(null), isNull);
    });
  });

  group('membersInitialModeForTab', () {
    test('requests tab opens mode 1, anything else mode 0', () {
      expect(membersInitialModeForTab('requests'), membersRequestsMode);
      expect(membersInitialModeForTab('Requests'), membersRequestsMode);
      expect(membersInitialModeForTab(null), 0);
      expect(membersInitialModeForTab('x'), 0);
    });
  });
}
