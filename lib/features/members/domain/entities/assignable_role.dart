/// Código de violación de elegibilidad: el cargo exige ser Guía Mayor.
const clubRoleGuideMajorRequiredCode = 'CLUB_ROLE_GUIDE_MAJOR_REQUIRED';

/// Código de violación: un Guía Mayor no puede ser miembro en la sección.
const clubRoleMemberRequiresGuideMajorSectionCode =
    'CLUB_ROLE_MEMBER_REQUIRES_GUIDE_MAJOR_SECTION';

/// Rol de club con su elegibilidad para un usuario en una sección.
class AssignableRole {
  final String roleId;
  final String roleName;
  final bool allowed;
  final String? violationCode;

  const AssignableRole({
    required this.roleId,
    required this.roleName,
    required this.allowed,
    this.violationCode,
  });

  factory AssignableRole.fromJson(Map<String, dynamic> json) {
    return AssignableRole(
      roleId: json['role_id']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      allowed: json['allowed'] != false,
      violationCode: json['violation_code']?.toString(),
    );
  }
}

/// Respuesta de `GET /clubs/:clubId/sections/:sectionId/members/:userId/assignable-roles`.
class AssignableRolesResult {
  final List<AssignableRole> roles;
  final bool guideMajorEligible;
  final String? sectionKind;

  const AssignableRolesResult({
    this.roles = const [],
    this.guideMajorEligible = false,
    this.sectionKind,
  });

  factory AssignableRolesResult.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    return AssignableRolesResult(
      roles: rawRoles is List
          ? rawRoles
              .whereType<Map>()
              .map((r) => AssignableRole.fromJson(Map<String, dynamic>.from(r)))
              .where((r) => r.roleName.isNotEmpty)
              .toList()
          : const [],
      guideMajorEligible: json['guide_major_eligible'] == true,
      sectionKind: json['section_kind']?.toString(),
    );
  }
}
