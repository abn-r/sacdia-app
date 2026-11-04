import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';

UserEntity _userWithStatus(String status) {
  return UserEntity(
    id: 'user-1',
    email: 'elena@example.com',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      effectivePermissions: const ['users:read_detail', 'classes:read'],
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'assignment-1',
          roleName: 'member',
          permissions: const ['users:read_detail', 'classes:read'],
          status: status,
        ),
      ],
      activeAssignmentId: 'assignment-1',
    ),
  );
}

void main() {
  group('membershipGrantForDisplay', () {
    test('returns a pending request when no active assignment is selected', () {
      const auth = AuthorizationSnapshot(
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'pending-1',
            roleName: 'member',
            status: 'pending',
          ),
        ],
      );

      expect(membershipGrantForDisplay(auth)?.assignmentId, 'pending-1');
    });
  });

  group('canAccessClubOperationalSurface', () {
    test('blocks pending users even when permissions are present', () {
      final user = _userWithStatus('pending');

      expect(hasAnyPermission(user, const {'classes:read'}), isTrue);
      expect(canAccessClubOperationalSurface(user), isFalse);
    });

    test('allows active users with authorization', () {
      expect(
          canAccessClubOperationalSurface(_userWithStatus('active')), isTrue);
    });
  });

  group('isClubStaffMode', () {
    UserEntity user({
      String? role,
      String status = 'active',
      List<String> permissions = const [],
    }) {
      return UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        authorization: AuthorizationSnapshot(
          effectivePermissions: permissions,
          activeAssignmentId: 'a-1',
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a-1',
              roleName: role,
              status: status,
            ),
          ],
        ),
      );
    }

    test('is false without a user or authorization', () {
      expect(isClubStaffMode(null), isFalse);
      expect(
        isClubStaffMode(const UserEntity(id: 'u', email: 'e@example.com')),
        isFalse,
      );
    });

    test('is false for a plain member', () {
      expect(isClubStaffMode(user(role: 'member')), isFalse);
      expect(
        isClubStaffMode(
          user(role: 'member', permissions: const ['classes:read']),
        ),
        isFalse,
      );
    });

    test('is true for club roles other than member (normalized)', () {
      for (final role in const [
        'director',
        'Deputy-Director',
        ' counselor ',
        'instructor',
        'secretary',
        'treasurer',
      ]) {
        expect(isClubStaffMode(user(role: role)), isTrue, reason: role);
      }
    });

    test('is false for a non-club role without staff permissions', () {
      expect(isClubStaffMode(user(role: 'pastor')), isFalse);
    });

    test('is true for a member holding any staff permission', () {
      for (final permission in clubStaffHomePermissions) {
        expect(
          isClubStaffMode(user(role: 'member', permissions: [permission])),
          isTrue,
          reason: permission,
        );
      }
    });

    test('is false when the membership is not usable', () {
      expect(
          isClubStaffMode(user(role: 'director', status: 'pending')), isFalse);
      expect(
          isClubStaffMode(user(role: 'director', status: 'inactive')), isFalse);
    });
  });
}
