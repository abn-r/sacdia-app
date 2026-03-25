import 'package:equatable/equatable.dart';

class AuthorizationGrant extends Equatable {
  final String? assignmentId;
  final String? roleName;
  final List<String> permissions;
  final int? clubId;
  final int? sectionId;

  /// Membership status: 'pending', 'active', 'rejected', 'expired'.
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
    this.status,
    this.expiresAt,
    this.rejectionReason,
  });

  /// Whether this assignment is in a usable (active) state.
  bool get isActive => status == null || status == 'active';

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
        status,
        expiresAt,
        rejectionReason,
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

  /// Returns the membership status of the active grant, or null if no active grant.
  String? get activeMembershipStatus => activeGrant?.status;

  /// Whether the active assignment is pending approval.
  bool get isActivePending => activeGrant?.isPending ?? false;

  /// Whether the active assignment was rejected.
  bool get isActiveRejected => activeGrant?.isRejected ?? false;

  /// Whether the active assignment has expired.
  bool get isActiveExpired => activeGrant?.isExpired ?? false;

  /// Whether the active assignment is in a non-active state (pending/rejected/expired).
  bool get hasRestrictedAccess =>
      isActivePending || isActiveRejected || isActiveExpired;

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
