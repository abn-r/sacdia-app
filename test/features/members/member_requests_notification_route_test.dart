import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/members/presentation/utils/member_requests_notification_route.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';

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

  group('clubSectionIdOfInboxTarget', () {
    test('reads target_id for club_section and section_role', () {
      expect(
        clubSectionIdOfInboxTarget(
          targetType: NotificationTargetType.sectionRole,
          targetId: '166',
        ),
        166,
      );
      expect(
        clubSectionIdOfInboxTarget(
          targetType: NotificationTargetType.club,
          targetId: ' 167 ',
        ),
        167,
      );
    });

    test('ignores other target types, null and garbage (old server)', () {
      expect(
        clubSectionIdOfInboxTarget(
          targetType: NotificationTargetType.direct,
          targetId: 'user-uuid',
        ),
        isNull,
      );
      expect(
        clubSectionIdOfInboxTarget(
          targetType: NotificationTargetType.sectionRole,
        ),
        isNull,
      );
      expect(
        clubSectionIdOfInboxTarget(
          targetType: NotificationTargetType.sectionRole,
          targetId: 'abc',
        ),
        isNull,
      );
    });
  });

  group('memberRequestsDestinationFor', () {
    const approver = ['club_members:approve'];

    AuthorizationGrant grant(
      String id,
      int sectionId, {
      List<String> permissions = approver,
      String? status,
    }) =>
        AuthorizationGrant(
          assignmentId: id,
          roleName: 'director',
          permissions: permissions,
          clubId: 1,
          sectionId: sectionId,
          status: status,
        );

    UserEntity userWith(
      List<AuthorizationGrant> grants, {
      String? active,
      List<String> effective = approver,
    }) =>
        UserEntity(
          id: 'u-1',
          authorization: AuthorizationSnapshot(
            effectivePermissions: effective,
            clubAssignments: grants,
            activeAssignmentId: active,
          ),
        );

    test('switches to the notified section when the user has a grant there',
        () {
      final user = userWith(
        [grant('a-1', 166), grant('a-2', 167)],
        active: 'a-1',
      );

      final dest = memberRequestsDestinationFor(user, clubSectionId: 167);

      expect(dest!.route, RouteNames.homeMemberRequests);
      expect(dest.switchToAssignmentId, 'a-2');
    });

    test('switches even when the current context cannot see requests', () {
      final user = userWith(
        [
          grant('a-1', 166, permissions: const ['club_members:read']),
          grant('a-2', 167),
        ],
        active: 'a-1',
        effective: const ['club_members:read'],
      );

      final dest = memberRequestsDestinationFor(user, clubSectionId: 167);

      expect(dest?.switchToAssignmentId, 'a-2');
    });

    test('does not switch when the section is already the active one', () {
      final user = userWith(
        [grant('a-1', 166), grant('a-2', 167)],
        active: 'a-2',
      );

      final dest = memberRequestsDestinationFor(user, clubSectionId: 167);

      expect(dest!.route, RouteNames.homeMemberRequests);
      expect(dest.switchToAssignmentId, isNull);
    });

    test('ignores a section the user has no grant for (never escalates)', () {
      final user = userWith([grant('a-1', 166)], active: 'a-1');

      final dest = memberRequestsDestinationFor(user, clubSectionId: 999);

      expect(dest!.route, RouteNames.homeMemberRequests);
      expect(dest.switchToAssignmentId, isNull);
    });

    test('ignores a grant that is not active or cannot review requests', () {
      final user = userWith(
        [
          grant('a-1', 166),
          grant('a-2', 167, status: 'pending'),
          grant('a-3', 168, permissions: const ['club_members:read']),
          grant('a-4', 169, status: 'designated'),
        ],
        active: 'a-1',
      );

      for (final section in [167, 168, 169]) {
        final dest = memberRequestsDestinationFor(user, clubSectionId: section);
        expect(dest!.switchToAssignmentId, isNull, reason: '$section');
      }
    });

    test('works without a section id (old server)', () {
      final user = userWith(
        [grant('a-1', 166), grant('a-2', 167)],
        active: 'a-1',
      );

      final dest = memberRequestsDestinationFor(user);

      expect(dest!.route, RouteNames.homeMemberRequests);
      expect(dest.switchToAssignmentId, isNull);
    });

    test(
        'no destination when the current context cannot see requests and '
        'there is nothing to switch to', () {
      final user = userWith(
        [grant('a-1', 166, permissions: const [])],
        active: 'a-1',
        effective: const [],
      );

      expect(memberRequestsDestinationFor(user, clubSectionId: 999), isNull);
      expect(memberRequestsDestinationFor(null, clubSectionId: 999), isNull);
    });
  });

  group('resolveMemberRequestsRoute', () {
    final user = UserEntity(
      id: 'u-1',
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['club_members:approve'],
        activeAssignmentId: 'a-1',
        clubAssignments: const [
          AuthorizationGrant(
            assignmentId: 'a-1',
            permissions: ['club_members:approve'],
            clubId: 1,
            sectionId: 166,
          ),
          AuthorizationGrant(
            assignmentId: 'a-2',
            permissions: ['club_members:approve'],
            clubId: 1,
            sectionId: 167,
          ),
        ],
      ),
    );

    test('switches first, then returns the requests route', () async {
      final calls = <String>[];

      final route = await resolveMemberRequestsRoute(
        readUser: () => user,
        switchContext: (id) async {
          calls.add(id);
          return true;
        },
        clubSectionId: 167,
      );

      expect(calls, ['a-2']);
      expect(route, RouteNames.homeMemberRequests);
    });

    test('does not touch the context without a grant or without a section',
        () async {
      final calls = <String>[];
      Future<bool> record(String id) async {
        calls.add(id);
        return true;
      }

      expect(
        await resolveMemberRequestsRoute(
          readUser: () => user,
          switchContext: record,
          clubSectionId: 999,
        ),
        RouteNames.homeMemberRequests,
      );
      expect(
        await resolveMemberRequestsRoute(
          readUser: () => user,
          switchContext: record,
        ),
        RouteNames.homeMemberRequests,
      );
      expect(calls, isEmpty);
    });

    test('a failed or throwing switch falls back to the current context',
        () async {
      expect(
        await resolveMemberRequestsRoute(
          readUser: () => user,
          switchContext: (_) async => false,
          clubSectionId: 167,
        ),
        RouteNames.homeMemberRequests,
      );
      expect(
        await resolveMemberRequestsRoute(
          readUser: () => user,
          switchContext: (_) async => throw Exception('network'),
          clubSectionId: 167,
        ),
        RouteNames.homeMemberRequests,
      );
    });
  });
}
