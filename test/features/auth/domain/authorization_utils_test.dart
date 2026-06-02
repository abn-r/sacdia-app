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
}
