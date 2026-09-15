/// Mirror of `GLOBAL_ROLE_ALIASES` in
/// `sacdia-backend/src/common/guards/global-roles.guard.ts`
/// and `sacdia-admin/src/lib/auth/screen-catalog/role-aliases.ts`.
/// Keep in sync via `test/fixtures/screen-catalog.snapshot.json`.
const List<String> _fieldAdminRoles = [
  'director-lf',
  'assistant-lf',
  'director-union',
  'assistant-union',
  'director-dia',
  'assistant-dia',
];

const Map<String, List<String>> kGlobalRoleAliases = {
  'admin': ['admin', 'assistant-admin'],
  'assistant-admin': ['assistant-admin', 'admin'],
  'assistant-dia': _fieldAdminRoles,
  'assistant-lf': _fieldAdminRoles,
  'assistant-union': _fieldAdminRoles,
  'coordinator': ['coordinator', 'zone-coordinator', 'general-coordinator'],
  'director-dia': _fieldAdminRoles,
  'director-lf': _fieldAdminRoles,
  'director-union': _fieldAdminRoles,
  'general-coordinator': ['general-coordinator'],
  'pastor': ['pastor'],
  'super-admin': ['super-admin'],
  'user': ['user'],
  'zone-coordinator': ['zone-coordinator', 'general-coordinator'],
};

List<String> expandRequiredRoles(Iterable<String> requiredRoles) {
  final out = <String>{};
  for (final role in requiredRoles) {
    final aliases = kGlobalRoleAliases[role];
    if (aliases == null) {
      out.add(role);
    } else {
      out.addAll(aliases);
    }
  }
  return out.toList();
}

bool roleGateSatisfied(Set<String> actorRoles, Iterable<String> requiredRoles) {
  final required = requiredRoles.toList();
  if (required.isEmpty) return true;
  return expandRequiredRoles(required).any(actorRoles.contains);
}
