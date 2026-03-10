import 'package:equatable/equatable.dart';

class AuthorizationGrant extends Equatable {
  final String? assignmentId;
  final String? roleName;
  final List<String> permissions;
  final int? clubId;
  final String? instanceType;
  final int? instanceId;

  const AuthorizationGrant({
    this.assignmentId,
    this.roleName,
    this.permissions = const [],
    this.clubId,
    this.instanceType,
    this.instanceId,
  });

  @override
  List<Object?> get props => [
        assignmentId,
        roleName,
        permissions,
        clubId,
        instanceType,
        instanceId,
      ];
}

class AuthorizationSnapshot extends Equatable {
  final List<String> effectivePermissions;
  final List<AuthorizationGrant> globalGrants;
  final List<AuthorizationGrant> clubAssignments;
  final String? activeAssignmentId;

  const AuthorizationSnapshot({
    this.effectivePermissions = const [],
    this.globalGrants = const [],
    this.clubAssignments = const [],
    this.activeAssignmentId,
  });

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

    for (final grant in clubAssignments) {
      addRole(grant.roleName);
    }

    return roles;
  }

  @override
  List<Object?> get props => [
        effectivePermissions,
        globalGrants,
        clubAssignments,
        activeAssignmentId,
      ];
}
