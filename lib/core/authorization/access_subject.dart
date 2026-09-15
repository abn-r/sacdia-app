import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';

class AccessSubject {
  final Set<String> permissions;
  final Set<String> roles;
  final bool isSuperAdmin;

  const AccessSubject({
    required this.permissions,
    required this.roles,
    required this.isSuperAdmin,
  });
}

const String kSuperAdminRole = 'super-admin';

AccessSubject subjectFromUser(UserEntity? user) {
  final roles = extractUserRoles(user)
      .map((role) => role.trim().toLowerCase())
      .where((role) => role.isNotEmpty)
      .toSet();
  final permissions = extractUserPermissions(user);
  return AccessSubject(
    permissions: permissions,
    roles: roles,
    isSuperAdmin: roles.contains(kSuperAdminRole),
  );
}
