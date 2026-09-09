import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';

// ignore_for_file: avoid_redundant_argument_values

UserEntity buildUser({
  required String id,
  List<String> permissions = const [],
  List<AuthorizationGrant> globalGrants = const [],
  List<AuthorizationGrant> clubAssignments = const [],
}) {
  return UserEntity(
    id: id,
    email: '$id@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      globalGrants: globalGrants,
      clubAssignments: clubAssignments,
    ),
  );
}

void main() {
  group('authorization utils', () {
    test('uses canonical permissions from authorization snapshot', () {
      final user = buildUser(
        id: 'actor',
        permissions: const ['Users:Read_Detail', 'users:update'],
      );

      expect(
        extractUserPermissions(user),
        {'users:read_detail', 'users:update'},
      );
    });

    test('uses resolved role names from authorization grants', () {
      // resolvedRoleNames returns globalGrants + active club assignment only.
      // Use globalGrants to assert that role names are normalised to lowercase.
      final user = buildUser(
        id: 'actor',
        globalGrants: const [
          AuthorizationGrant(roleName: 'Director'),
          AuthorizationGrant(roleName: 'Secretary'),
        ],
      );

      expect(extractUserRoles(user), {'director', 'secretary'});
    });

    test(
        'allows third-party administrative completion with explicit global access',
        () {
      // The fine-grained permission for postRegistration update is
      // 'users:update_profile' (not the generic 'users:update').
      final user = buildUser(
        id: 'actor',
        permissions: const ['users:update_profile'],
      );

      expect(
        canViewAdministrativeCompletionForUser(
          user,
          targetUserId: 'target',
        ),
        isTrue,
      );
      expect(
        canManageAdministrativeCompletionForUser(
          user,
          targetUserId: 'target',
        ),
        isTrue,
      );
    });

    test('does not treat generic users:update as sensitive data access', () {
      final user = buildUser(
        id: 'actor',
        permissions: const ['users:update'],
      );

      expect(
        canAccessSensitiveUserDataForUser(user, targetUserId: 'target'),
        isFalse,
      );
    });

    test('allows sensitive data access only for owner or users:read_detail',
        () {
      final reader = buildUser(
        id: 'actor',
        permissions: const ['users:read_detail'],
      );
      final owner = buildUser(id: 'target');

      expect(
        canAccessSensitiveUserDataForUser(reader, targetUserId: 'target'),
        isTrue,
      );
      expect(
        canAccessSensitiveUserDataForUser(owner, targetUserId: 'target'),
        isTrue,
      );
    });

    test('allows fine-grained sensitive family reads with legacy fallback', () {
      final fineGrained = buildUser(
        id: 'actor',
        permissions: const ['health:read', 'emergency_contacts:read'],
      );
      final legacy = buildUser(
        id: 'actor',
        permissions: const ['users:read_detail'],
      );

      expect(
        canReadSensitiveUserFamilyForUser(
          fineGrained,
          targetUserId: 'target',
          family: SensitiveUserFamily.health,
        ),
        isTrue,
      );
      expect(
        canReadSensitiveUserFamilyForUser(
          fineGrained,
          targetUserId: 'target',
          family: SensitiveUserFamily.emergencyContacts,
        ),
        isTrue,
      );
      expect(
        canReadSensitiveUserFamilyForUser(
          legacy,
          targetUserId: 'target',
          family: SensitiveUserFamily.legalRepresentative,
        ),
        isTrue,
      );
    });

    test(
        'allows fine-grained updates without treating users:update as sensitive read',
        () {
      // 'users:update_profile' grants postRegistration update but not read.
      // This verifies that update-only permissions do not bleed into read gates.
      final updater = buildUser(
        id: 'actor',
        permissions: const ['users:update_profile'],
      );
      final fineGrained = buildUser(
        id: 'actor',
        permissions: const ['legal_representative:update'],
      );

      expect(
        canUpdateSensitiveUserFamilyForUser(
          updater,
          targetUserId: 'target',
          family: SensitiveUserFamily.postRegistration,
        ),
        isTrue,
      );
      expect(
        canReadSensitiveUserFamilyForUser(
          updater,
          targetUserId: 'target',
          family: SensitiveUserFamily.postRegistration,
        ),
        isFalse,
      );
      expect(
        canUpdateSensitiveUserFamilyForUser(
          fineGrained,
          targetUserId: 'target',
          family: SensitiveUserFamily.legalRepresentative,
        ),
        isTrue,
      );
    });
  });

  // ── Inactive (ghost) status ──────────────────────────────────────────────

  group('AuthorizationGrant.isInactive', () {
    test('inactive grant returns isInactive=true', () {
      const grant = AuthorizationGrant(status: 'inactive');
      expect(grant.isInactive, isTrue);
    });

    test('inactive grant returns isActive=false', () {
      const grant = AuthorizationGrant(status: 'inactive');
      expect(grant.isActive, isFalse);
    });

    test('active grant returns isInactive=false', () {
      const grant = AuthorizationGrant(status: 'active');
      expect(grant.isInactive, isFalse);
      expect(grant.isActive, isTrue);
    });

    test('designated status is not inactive (no ghost banner)', () {
      const grant = AuthorizationGrant(status: 'designated', roleName: 'director');
      expect(grant.isInactive, isFalse);
      expect(grant.isActive, isFalse);
    });
  });

  group('AuthorizationSnapshot.hasRestrictedAccess includes inactive', () {
    AuthorizationSnapshot _snapshotWithActiveGrant(String status) {
      const id = 'assign-1';
      final grant = AuthorizationGrant(assignmentId: id, status: status);
      return AuthorizationSnapshot(
        clubAssignments: [grant],
        activeAssignmentId: id,
      );
    }

    test('inactive → hasRestrictedAccess=true', () {
      final snap = _snapshotWithActiveGrant('inactive');
      expect(snap.isActiveInactive, isTrue);
      expect(snap.hasRestrictedAccess, isTrue);
    });

    test('pending → hasRestrictedAccess=true', () {
      final snap = _snapshotWithActiveGrant('pending');
      expect(snap.hasRestrictedAccess, isTrue);
    });

    test('active → hasRestrictedAccess=false', () {
      final snap = _snapshotWithActiveGrant('active');
      expect(snap.hasRestrictedAccess, isFalse);
    });

    test('null status → hasRestrictedAccess=false', () {
      const id = 'assign-1';
      const grant = AuthorizationGrant(assignmentId: id);
      final snap = AuthorizationSnapshot(
        clubAssignments: [grant],
        activeAssignmentId: id,
      );
      expect(snap.hasRestrictedAccess, isFalse);
    });
  });

  group('membershipGrantForDisplay for inactive', () {
    test('returns inactive grant for display', () {
      const id = 'assign-1';
      const grant = AuthorizationGrant(
          assignmentId: id, status: 'inactive', clubId: 1, sectionId: 2);
      final snap = AuthorizationSnapshot(
        clubAssignments: [grant],
        activeAssignmentId: id,
      );
      final result = membershipGrantForDisplay(snap);
      expect(result, isNotNull);
      expect(result!.isInactive, isTrue);
    });

    test('returns null for active grant (nothing to display)', () {
      const id = 'assign-1';
      const grant = AuthorizationGrant(
          assignmentId: id, status: 'active', clubId: 1, sectionId: 2);
      final snap = AuthorizationSnapshot(
        clubAssignments: [grant],
        activeAssignmentId: id,
      );
      expect(membershipGrantForDisplay(snap), isNull);
    });
  });
}
