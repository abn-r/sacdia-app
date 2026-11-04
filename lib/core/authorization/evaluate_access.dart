import 'access_subject.dart';
import 'role_aliases.dart';

class CapabilityGate {
  final List<String> permissions;
  final List<String> roles;
  final bool requireAll;
  final bool exactRoles;

  /// Capacidad del servidor (`kCapabilityKeys`) que el sujeto debe tener,
  /// además de [permissions]. Cuando hay [capability], [roles] es `[]`: la
  /// capacidad ya resume el gate por rol.
  final String? capability;

  const CapabilityGate({
    this.permissions = const [],
    this.roles = const [],
    this.requireAll = false,
    this.exactRoles = false,
    this.capability,
  });
}

String _normalizePermission(String permission) =>
    permission.trim().toLowerCase();

/// Same rules as `sacdia-admin/src/lib/auth/screen-catalog/evaluate.ts`.
bool evaluateAccess(AccessSubject subject, CapabilityGate access) {
  if (subject.isSuperAdmin) return true;

  final permissions = access.permissions;
  final roles = access.roles;
  final capability = access.capability;

  if (capability == null && permissions.isEmpty && roles.isEmpty) return true;

  // La capacidad se evalúa primero, junto con los permisos: ambos se exigen.
  if (capability != null &&
      !subject.capabilities.contains(capability.trim().toLowerCase())) {
    return false;
  }

  final permissionsOk = permissions.isEmpty ||
      (access.requireAll
          ? permissions.every(
              (permission) => subject.permissions
                  .contains(_normalizePermission(permission)),
            )
          : permissions.any(
              (permission) => subject.permissions
                  .contains(_normalizePermission(permission)),
            ));

  if (!permissionsOk) return false;

  if (access.exactRoles) {
    return roles.isEmpty || roles.any(subject.roles.contains);
  }
  return roleGateSatisfied(subject.roles, roles);
}
