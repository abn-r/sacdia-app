import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';

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
      final user = buildUser(
        id: 'actor',
        clubAssignments: const [
          AuthorizationGrant(roleName: 'Director'),
          AuthorizationGrant(roleName: 'Secretary'),
        ],
      );

      expect(extractUserRoles(user), {'director', 'secretary'});
    });

    test(
        'allows third-party administrative completion with explicit global access',
        () {
      final user = buildUser(
        id: 'actor',
        permissions: const ['users:update'],
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
      final updater = buildUser(
        id: 'actor',
        permissions: const ['users:update'],
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
}
