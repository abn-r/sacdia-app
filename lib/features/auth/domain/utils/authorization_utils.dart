import '../../../../core/utils/app_logger.dart';
import '../entities/user_entity.dart';

const bool kRbacLegacyFallbackEnabled =
    bool.fromEnvironment('RBAC_LEGACY_FALLBACK_ENABLED', defaultValue: false);

bool _canonicalEventLogged = false;
bool _legacyFallbackEventLogged = false;

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

  if (!kRbacLegacyFallbackEnabled || user == null || legacyRoles.isEmpty) {
    return false;
  }

  final roles = _extractLegacyRoles(user);
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
