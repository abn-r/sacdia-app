import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/family_push_route.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

const _childId = '0d6e6d54-3c1d-4f1c-9a52-1f2b6a7a9c11';

UserEntity _guardian() => const UserEntity(
      id: 'g',
      principal: PrincipalInfo(kind: PrincipalKind.user),
    );

UserEntity _released({bool frozen = false}) => UserEntity(
      id: 'r',
      serverMode: AccountMode.released,
      principal: PrincipalInfo(
        kind: PrincipalKind.releasedUser,
        release: ReleaseInfo(
          status: frozen ? ReleaseStatus.frozen : ReleaseStatus.pending,
        ),
      ),
    );

UserEntity _teen({required bool active}) => UserEntity(
      id: 't',
      serverMode: active ? AccountMode.teenSupervised : AccountMode.teenPending,
      principal: PrincipalInfo(
        kind: PrincipalKind.supervisedUser,
        supervision: SupervisionInfo(
          status: active
              ? SupervisionStatus.active
              : SupervisionStatus.pendingGuardian,
        ),
      ),
    );

void main() {
  group('familyPushKindOf (majority)', () {
    test('reads data.type and source', () {
      const expected = {
        'majority_notice': FamilyPushKind.majorityNotice,
        'majority_released': FamilyPushKind.majorityReleased,
        'majority_reminder': FamilyPushKind.majorityReminder,
        'majority_frozen': FamilyPushKind.majorityFrozen,
        'majority_handover': FamilyPushKind.majorityHandover,
      };
      expected.forEach((type, kind) {
        expect(familyPushKindOf({'type': type}), kind, reason: type);
      });
      expect(
        familyPushKindOf({'source': 'family:majority:handover'}),
        FamilyPushKind.majorityHandover,
      );
      expect(
        familyPushKindOf({'type': 'family:majority:reminder'}),
        FamilyPushKind.majorityReminder,
      );
      expect(familyPushKindOf({'type': 'majority_other'}), isNull);
    });
  });

  group('familyPushTarget (majority)', () {
    test('the released person goes to /release or /release/frozen by status',
        () {
      for (final kind in [
        FamilyPushKind.majorityReleased,
        FamilyPushKind.majorityReminder,
        FamilyPushKind.majorityFrozen,
      ]) {
        expect(
          familyPushTarget(kind: kind, data: const {}, user: _released())!
              .route,
          RouteNames.release,
          reason: '$kind pending',
        );
        expect(
          familyPushTarget(
                  kind: kind, data: const {}, user: _released(frozen: true))!
              .route,
          RouteNames.releaseFrozen,
          reason: '$kind frozen',
        );
      }
    });

    test('the payload never picks the route or a profile for the person', () {
      final target = familyPushTarget(
        kind: FamilyPushKind.majorityReminder,
        data: {'dependent_user_id': _childId, 'route': '/home/dashboard'},
        user: _released(),
      )!;
      expect(target.route, RouteNames.release);
      expect(target.dependentId, isNull);
      expect(target.needsGuardianProfile, isFalse);
    });

    test('a released person ignores guardian-only handover', () {
      expect(
        familyPushTarget(
          kind: FamilyPushKind.majorityHandover,
          data: const {},
          user: _released(),
        ),
        isNull,
      );
    });

    test('guardian: notice -> /family, handover -> /family/released', () {
      final notice = familyPushTarget(
        kind: FamilyPushKind.majorityNotice,
        data: {'dependent_user_id': _childId},
        user: _guardian(),
      )!;
      expect(notice.route, RouteNames.family);
      expect(notice.needsGuardianProfile, isTrue);

      final handover = familyPushTarget(
        kind: FamilyPushKind.majorityHandover,
        data: {'dependent_user_id': _childId},
        user: _guardian(),
      )!;
      expect(handover.route, RouteNames.familyReleased);
      expect(handover.needsGuardianProfile, isTrue);
    });

    test('a guardian does not get the person-only notices', () {
      for (final kind in [
        FamilyPushKind.majorityReleased,
        FamilyPushKind.majorityReminder,
        FamilyPushKind.majorityFrozen,
      ]) {
        expect(
          familyPushTarget(kind: kind, data: const {}, user: _guardian()),
          isNull,
          reason: '$kind',
        );
      }
    });

    test('teens: supervised -> inbox, pending -> their status screen', () {
      expect(
        familyPushTarget(
          kind: FamilyPushKind.majorityNotice,
          data: const {},
          user: _teen(active: true),
        )!
            .route,
        RouteNames.notificationsInbox,
      );
      expect(
        familyPushTarget(
          kind: FamilyPushKind.majorityNotice,
          data: const {},
          user: _teen(active: false),
        )!
            .route,
        RouteNames.teenPendingHome,
      );
    });

    test('no session: nothing', () {
      expect(
        familyPushTarget(
          kind: FamilyPushKind.majorityNotice,
          data: const {},
          user: null,
        ),
        isNull,
      );
    });
  });
}
