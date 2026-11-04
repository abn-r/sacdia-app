import 'generated/role_aliases.dart';

export 'generated/role_aliases.dart';

// `kGlobalRoleAliases` is GENERATED from the backend catalog
// (`pnpm authz:generate` in sacdia-backend) into
// `generated/role_aliases.dart` and re-exported here. No manual sync needed;
// `test/fixtures/screen-catalog.snapshot.json` stays as is.

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
