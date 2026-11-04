import 'package:equatable/equatable.dart';

class AuthorizationGrant extends Equatable {
  final String? assignmentId;
  final String? roleName;
  final List<String> permissions;
  final int? clubId;
  final int? sectionId;
  final int? clubTypeId;

  /// Human-readable club name (e.g. 'ACV').
  /// Populated from `club.club_name` in the backend grant response.
  final String? clubName;

  /// Human-readable club type name for the section (e.g. 'Conquistadores').
  /// Populated from `club_type_name` in the backend grant response.
  final String? clubTypeName;

  /// Membership status: pending, active, rejected, expired, inactive, designated, ended.
  final String? status;

  /// When the membership request expires (only relevant for pending status).
  final DateTime? expiresAt;

  /// Reason for rejection (only present when status is 'rejected').
  final String? rejectionReason;

  const AuthorizationGrant({
    this.assignmentId,
    this.roleName,
    this.permissions = const [],
    this.clubId,
    this.sectionId,
    this.clubTypeId,
    this.clubName,
    this.clubTypeName,
    this.status,
    this.expiresAt,
    this.rejectionReason,
  });

  /// Whether this assignment is in a usable (active) state.
  /// Note: 'inactive' is explicitly NOT active.
  bool get isActive => status == null || status == 'active';

  /// Whether this assignment is an inactive ghost (assigned to club but not
  /// yet enrolled for the current ecclesiastical year).
  bool get isInactive => status == 'inactive';

  /// Whether this assignment is pending approval.
  bool get isPending => status == 'pending';

  /// Whether this assignment was rejected.
  bool get isRejected => status == 'rejected';

  /// Whether this assignment has expired.
  bool get isExpired => status == 'expired';

  @override
  List<Object?> get props => [
        assignmentId,
        roleName,
        permissions,
        clubId,
        sectionId,
        clubTypeId,
        clubName,
        clubTypeName,
        status,
        expiresAt,
        rejectionReason,
      ];
}

/// Territorio del actor (`/auth/me.authorization.territory`).
///
/// [level] es uno de `all`, `open`, `unconfigured`, `division`, `union` o
/// `local_field`; los ids son enteros o nulos según el nivel. La app no lo
/// evalúa: lo conserva tal cual para quien lo necesite (y para la caché).
class AuthorizationTerritory extends Equatable {
  final String level;
  final int? divisionId;
  final int? unionId;
  final int? localFieldId;

  const AuthorizationTerritory({
    required this.level,
    this.divisionId,
    this.unionId,
    this.localFieldId,
  });

  @override
  List<Object?> get props => [level, divisionId, unionId, localFieldId];
}

class AuthorizationSnapshot extends Equatable {
  final List<String> effectivePermissions;
  final List<AuthorizationGrant> globalGrants;
  final List<AuthorizationGrant> clubAssignments;
  final String? activeAssignmentId;

  /// Capacidades que el servidor calculó para el actor
  /// (`authorization.capabilities`, ordenadas; claves `a.b` de
  /// `kCapabilityKeys`). Semántica: «el actor puede intentarlo sobre al menos
  /// un objetivo»; el servidor sigue respondiendo 403 si el objetivo no
  /// coincide. Ausente (servidor anterior a la fase 7) = lista vacía = deny.
  final List<String> capabilities;

  /// `authorization.territory`; nulo si el servidor no lo informó.
  final AuthorizationTerritory? territory;

  /// `authorization.assignable_global_roles`. La app no lo consume: se parsea
  /// y se conserva para no perderlo en la caché.
  final List<String> assignableGlobalRoles;

  const AuthorizationSnapshot({
    this.effectivePermissions = const [],
    this.globalGrants = const [],
    this.clubAssignments = const [],
    this.activeAssignmentId,
    this.capabilities = const [],
    this.territory,
    this.assignableGlobalRoles = const [],
  });

  /// ¿El servidor concedió la capacidad [key] (p. ej. `club.active_director`)?
  bool hasCapability(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return capabilities.contains(normalized);
  }

  AuthorizationGrant? get activeGrant {
    if (activeAssignmentId == null) return null;
    for (final grant in clubAssignments) {
      if (grant.assignmentId == activeAssignmentId) {
        return grant;
      }
    }
    return null;
  }

  bool get hasCanonicalPermissions => effectivePermissions.isNotEmpty;

  /// Returns the membership status of the active grant, or null if no active grant.
  String? get activeMembershipStatus => activeGrant?.status;

  /// Whether the active assignment is pending approval.
  bool get isActivePending => activeGrant?.isPending ?? false;

  /// Whether the active assignment was rejected.
  bool get isActiveRejected => activeGrant?.isRejected ?? false;

  /// Whether the active assignment has expired.
  bool get isActiveExpired => activeGrant?.isExpired ?? false;

  /// Whether the active assignment is an inactive ghost.
  bool get isActiveInactive => activeGrant?.isInactive ?? false;

  /// Whether the active assignment is in a non-active state
  /// (pending/rejected/expired/inactive).
  bool get hasRestrictedAccess =>
      isActivePending ||
      isActiveRejected ||
      isActiveExpired ||
      isActiveInactive;

  /// Role names relevant to the current context: global grants + the active
  /// club assignment only. Roles from inactive club assignments are excluded so
  /// that permission gating (e.g. the quick-access grid) reflects the user's
  /// role in the ACTIVE section, not the highest role across all sections.
  Set<String> get resolvedRoleNames {
    final roles = <String>{};

    void addRole(String? roleName) {
      final normalized = roleName?.trim().toLowerCase();
      if (normalized != null && normalized.isNotEmpty) {
        roles.add(normalized);
      }
    }

    for (final grant in globalGrants) {
      addRole(grant.roleName);
    }

    // Only the active club assignment contributes its role — not all of them.
    final active = activeGrant;
    if (active != null) {
      addRole(active.roleName);
    }

    return roles;
  }

  @override
  List<Object?> get props => [
        effectivePermissions,
        globalGrants,
        clubAssignments,
        activeAssignmentId,
        capabilities,
        territory,
        assignableGlobalRoles,
      ];
}
