import '../entities/user_entity.dart';

enum SensitiveUserFamily {
  health,
  emergencyContacts,
  legalRepresentative,
  postRegistration,
}

const Map<SensitiveUserFamily, Set<String>> _sensitiveFamilyReadPermissions = {
  SensitiveUserFamily.health: {'health:read', 'users:read_detail'},
  SensitiveUserFamily.emergencyContacts: {
    'emergency_contacts:read',
    'users:read_detail',
  },
  SensitiveUserFamily.legalRepresentative: {
    'legal_representative:read',
    'users:read_detail',
  },
  SensitiveUserFamily.postRegistration: {
    'post_registration:read',
    'users:read_detail',
  },
};

const Map<SensitiveUserFamily, Set<String>> _sensitiveFamilyUpdatePermissions =
    {
  SensitiveUserFamily.health: {'health:update', 'users:update'},
  SensitiveUserFamily.emergencyContacts: {
    'emergency_contacts:update',
    'users:update',
  },
  SensitiveUserFamily.legalRepresentative: {
    'legal_representative:update',
    'users:update',
  },
  SensitiveUserFamily.postRegistration: {
    'post_registration:update',
    'users:update',
  },
};

Set<String> _normalize(Iterable<dynamic> values) {
  return values
      .map((value) => value?.toString().trim().toLowerCase())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> extractUserRoles(UserEntity? user) {
  if (user == null) return <String>{};
  return user.authorization?.resolvedRoleNames ?? <String>{};
}

Set<String> extractUserPermissions(UserEntity? user) {
  if (user == null) return <String>{};
  final authorization = user.authorization;
  if (authorization == null) return <String>{};
  return _normalize(authorization.effectivePermissions);
}

bool hasAnyPermission(UserEntity? user, Iterable<String> permissions) {
  final granted = extractUserPermissions(user);
  if (granted.isEmpty) return false;

  for (final permission in permissions) {
    final normalized = permission.trim().toLowerCase();
    if (normalized.isNotEmpty && granted.contains(normalized)) {
      return true;
    }
  }
  return false;
}

/// Canonical role-name check against `user.authorization.resolvedRoleNames`.
/// Use this only when the gate is genuinely role-based (global roles like
/// `coordinator`, `admin`, `super_admin`). Prefer [hasAnyPermission] for
/// anything permission-driven.
bool hasAnyRole(UserEntity? user, Iterable<String> roles) {
  final granted = extractUserRoles(user);
  if (granted.isEmpty) return false;

  final normalizedGranted = _normalize(granted);
  for (final role in roles) {
    final normalized = role.trim().toLowerCase();
    if (normalized.isNotEmpty && normalizedGranted.contains(normalized)) {
      return true;
    }
  }
  return false;
}

bool isUserOwner(UserEntity? user, String targetUserId) {
  final normalizedTarget = targetUserId.trim();
  if (user == null || normalizedTarget.isEmpty) {
    return false;
  }
  return user.id.trim() == normalizedTarget;
}

bool canViewAdministrativeCompletionForUser(
  UserEntity? user, {
  required String targetUserId,
}) {
  return isUserOwner(user, targetUserId) ||
      hasAnyPermission(user, {
        ..._sensitiveFamilyReadPermissions[
            SensitiveUserFamily.postRegistration]!,
        ..._sensitiveFamilyUpdatePermissions[
            SensitiveUserFamily.postRegistration]!,
      });
}

bool canManageAdministrativeCompletionForUser(
  UserEntity? user, {
  required String targetUserId,
}) {
  return canUpdateSensitiveUserFamilyForUser(
    user,
    targetUserId: targetUserId,
    family: SensitiveUserFamily.postRegistration,
  );
}

bool canReadSensitiveUserFamilyForUser(
  UserEntity? user, {
  required String targetUserId,
  required SensitiveUserFamily family,
}) {
  return isUserOwner(user, targetUserId) ||
      hasAnyPermission(user, _sensitiveFamilyReadPermissions[family]!);
}

bool canUpdateSensitiveUserFamilyForUser(
  UserEntity? user, {
  required String targetUserId,
  required SensitiveUserFamily family,
}) {
  return isUserOwner(user, targetUserId) ||
      hasAnyPermission(user, _sensitiveFamilyUpdatePermissions[family]!);
}

bool canAccessSensitiveUserDataForUser(
  UserEntity? user, {
  required String targetUserId,
}) {
  return isUserOwner(user, targetUserId) ||
      hasAnyPermission(user, const {'users:read_detail'});
}
