import '../../../../core/utils/app_logger.dart';
import '../entities/user_entity.dart';

const bool kRbacLegacyFallbackEnabled =
    bool.fromEnvironment('RBAC_LEGACY_FALLBACK_ENABLED', defaultValue: false);

bool _canonicalEventLogged = false;
bool _legacyFallbackEventLogged = false;

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

Set<String> _normalizePermissions(Iterable<dynamic> values) {
  return values
      .map((value) => value?.toString().trim().toLowerCase())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> _extractLegacyPermissions(UserEntity user) {
  final metadata = user.metadata;
  if (metadata == null) return <String>{};

  final raw = metadata['permissions'];
  if (raw is List) {
    return _normalizePermissions(raw);
  }

  return <String>{};
}

Set<String> _extractLegacyRoles(UserEntity user) {
  final metadata = user.metadata;
  if (metadata == null) return <String>{};

  final raw = metadata['roles'];
  if (raw is List) {
    return _normalizePermissions(raw);
  }

  return <String>{};
}

Set<String> extractUserRoles(UserEntity? user) {
  if (user == null) {
    return <String>{};
  }

  final resolvedRoles = user.authorization?.resolvedRoleNames ?? <String>{};
  if (resolvedRoles.isNotEmpty) {
    return resolvedRoles;
  }

  if (!kRbacLegacyFallbackEnabled) {
    return <String>{};
  }

  final legacyRoles = _extractLegacyRoles(user);
  if (legacyRoles.isNotEmpty) {
    _logLegacyFallbackEvent();
  }
  return legacyRoles;
}

void _logCanonicalEvent() {
  if (_canonicalEventLogged) return;
  _canonicalEventLogged = true;
  AppLogger.i('rbac_canonical_used', tag: 'RBAC');
}

void _logLegacyFallbackEvent() {
  if (_legacyFallbackEventLogged) return;
  _legacyFallbackEventLogged = true;
  AppLogger.w('rbac_legacy_fallback_used', tag: 'RBAC');
}

Set<String> extractUserPermissions(UserEntity? user) {
  if (user == null) {
    return <String>{};
  }

  final authorization = user.authorization;
  if (authorization != null) {
    final canonical = _normalizePermissions(authorization.effectivePermissions);
    if (canonical.isNotEmpty) {
      _logCanonicalEvent();
      return canonical;
    }
  }

  if (!kRbacLegacyFallbackEnabled) {
    return <String>{};
  }

  final legacy = _extractLegacyPermissions(user);
  if (legacy.isNotEmpty) {
    _logLegacyFallbackEvent();
  }
  return legacy;
}

bool hasAnyPermission(UserEntity? user, Iterable<String> permissions) {
  final granted = extractUserPermissions(user);
  if (granted.isEmpty) {
    return false;
  }

  for (final permission in permissions) {
    final normalized = permission.trim().toLowerCase();
    if (normalized.isNotEmpty && granted.contains(normalized)) {
      return true;
    }
  }

  return false;
}

bool canByPermissionOrLegacyRole(
  UserEntity? user, {
  required Set<String> requiredPermissions,
  Set<String> legacyRoles = const <String>{},
}) {
  if (hasAnyPermission(user, requiredPermissions)) {
    return true;
  }

  if (user == null || legacyRoles.isEmpty) {
    return false;
  }

  final roles = extractUserRoles(user);
  if (roles.isEmpty) {
    return false;
  }

  final normalizedLegacy =
      legacyRoles.map((role) => role.trim().toLowerCase()).toSet();
  final intersects = roles.intersection(normalizedLegacy).isNotEmpty;

  if (intersects) {
    _logLegacyFallbackEvent();
  }

  return intersects;
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
