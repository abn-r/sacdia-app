import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/family_push_route.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

const _childId = '0d6e6d54-3c1d-4f1c-9a52-1f2b6a7a9c11';

UserEntity _user(
  PrincipalKind kind, {
  SupervisionStatus? supervision,
  AccountMode? serverMode,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      serverMode: serverMode,
      principal: PrincipalInfo(
        kind: kind,
        supervision:
            supervision == null ? null : SupervisionInfo(status: supervision),
      ),
    );

void main() {
  group('familyPushKindOf', () {
    test('reads the four push types by their spec names', () {
      expect(
        familyPushKindOf({'type': 'family:security'}),
        FamilyPushKind.security,
      );
      expect(
        familyPushKindOf({'type': 'family:evidence_uploaded'}),
        FamilyPushKind.evidenceUploaded,
      );
      expect(
        familyPushKindOf({'type': 'family:age_nudge'}),
        FamilyPushKind.ageNudge,
      );
      expect(
        familyPushKindOf({'type': 'family:teen_reminder'}),
        FamilyPushKind.teenReminder,
      );
    });

    test('reads the data.type values the backend really sends', () {
      expect(
        familyPushKindOf({'type': 'dependent_security'}),
        FamilyPushKind.security,
      );
      expect(
        familyPushKindOf({'type': 'dependent_evidence_uploaded'}),
        FamilyPushKind.evidenceUploaded,
      );
      expect(
        familyPushKindOf({'type': 'dependent_age_milestone'}),
        FamilyPushKind.ageNudge,
      );
      expect(
        familyPushKindOf({'type': 'teen_guardian_reminder'}),
        FamilyPushKind.teenReminder,
      );
      expect(
        familyPushKindOf({'type': 'teen_guardian_linked'}),
        FamilyPushKind.teenReminder,
      );
    });

    test('the source field also identifies the kind', () {
      expect(
        familyPushKindOf({'source': 'family:age_nudge'}),
        FamilyPushKind.ageNudge,
      );
    });

    test('anything else is not a family push', () {
      expect(familyPushKindOf({}), isNull);
      expect(familyPushKindOf({'type': 'achievement_unlocked'}), isNull);
      expect(familyPushKindOf({'type': 'family:securityx'}), isNull);
      expect(familyPushKindOf({'type': 42}), isNull);
    });
  });

  group('familyPushTarget: guardian side (account of an adult)', () {
    final guardian = _user(PrincipalKind.user);

    test('security, evidence and age nudge open the dependent detail', () {
      for (final kind in [
        FamilyPushKind.security,
        FamilyPushKind.evidenceUploaded,
        FamilyPushKind.ageNudge,
      ]) {
        final target = familyPushTarget(
          kind: kind,
          data: {'dependent_user_id': _childId},
          user: guardian,
        );
        expect(target?.route, RouteNames.familyDetailPath(_childId));
        expect(target?.dependentId, _childId);
        expect(target?.needsGuardianProfile, isTrue);
      }
    });

    test('a missing or malformed child id falls back to the family list', () {
      for (final data in <Map<String, dynamic>>[
        {},
        {'dependent_user_id': ''},
        {'dependent_user_id': '../../security'},
        {'dependent_user_id': 'a/b'},
      ]) {
        final target = familyPushTarget(
          kind: FamilyPushKind.security,
          data: data,
          user: guardian,
        );
        expect(target?.route, RouteNames.family, reason: '$data');
        expect(target?.dependentId, isNull);
      }
    });

    test('a teen reminder reaching a guardian opens the notices', () {
      final target = familyPushTarget(
        kind: FamilyPushKind.teenReminder,
        data: {'dependent_user_id': _childId},
        user: guardian,
      );
      expect(target?.route, RouteNames.notificationsInbox);
    });

    test('a guardian acting for a child still gets the detail route', () {
      final target = familyPushTarget(
        kind: FamilyPushKind.ageNudge,
        data: {'dependent_user_id': _childId},
        user: _user(PrincipalKind.guardianActing),
      );
      expect(target?.route, RouteNames.familyDetailPath(_childId));
    });
  });

  group('familyPushTarget: the other session modes ignore the child id', () {
    final data = <String, dynamic>{'dependent_user_id': _childId};

    test('pending teen: everything lands on the status screen', () {
      final teen = _user(
        PrincipalKind.supervisedUser,
        supervision: SupervisionStatus.pendingGuardian,
      );
      for (final kind in FamilyPushKind.values) {
        final target = familyPushTarget(kind: kind, data: data, user: teen);
        expect(target?.route, RouteNames.teenPendingHome, reason: '$kind');
        expect(target?.dependentId, isNull);
        expect(target?.needsGuardianProfile, isFalse);
      }
    });

    test('teen with a guardian: the notices, never Mi familia', () {
      final teen = _user(
        PrincipalKind.supervisedUser,
        supervision: SupervisionStatus.active,
      );
      for (final kind in FamilyPushKind.values) {
        final target = familyPushTarget(kind: kind, data: data, user: teen);
        expect(target?.route, RouteNames.notificationsInbox, reason: '$kind');
      }
    });

    test('a teen of unreadable state counts as pending (restrictive side)', () {
      final teen = _user(PrincipalKind.supervisedUser);
      final target = familyPushTarget(
        kind: FamilyPushKind.teenReminder,
        data: data,
        user: teen,
      );
      expect(target?.route, RouteNames.teenPendingHome);
    });

    test('linked device, unknown principal and no session: nothing', () {
      for (final user in [
        _user(PrincipalKind.linkedDevice),
        _user(PrincipalKind.unknown),
        _user(PrincipalKind.ageUnknownUser),
        null,
      ]) {
        for (final kind in FamilyPushKind.values) {
          expect(
            familyPushTarget(kind: kind, data: data, user: user),
            isNull,
            reason: '${user?.principal?.kind} $kind',
          );
        }
      }
    });
  });

  group('mayConfirmProfileSwitch', () {
    test('only an adult account or a guardian acting may be asked', () {
      expect(mayConfirmProfileSwitch(_user(PrincipalKind.user)), isTrue);
      expect(
        mayConfirmProfileSwitch(_user(PrincipalKind.guardianActing)),
        isTrue,
      );
      // Sin principal (servidor anterior a la Fase 3) cuenta como adulto.
      expect(
        mayConfirmProfileSwitch(const UserEntity(id: 'u', email: 'u@e.com')),
        isTrue,
      );
      for (final kind in [
        PrincipalKind.supervisedUser,
        PrincipalKind.linkedDevice,
        PrincipalKind.ageUnknownUser,
        PrincipalKind.unknown,
      ]) {
        expect(mayConfirmProfileSwitch(_user(kind)), isFalse, reason: '$kind');
      }
    });

    test('with no user the handler decides (it bails out without a session)',
        () {
      expect(mayConfirmProfileSwitch(null), isTrue);
    });
  });
}
