import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';

/// Maps an [AuthorizationSnapshot] to the single [Persona] that represents
/// the user's current UI identity.
///
/// Resolution order:
/// 1. If [snapshot.activeGrant] is non-null, its [roleName] is used directly.
/// 2. If no active grant, fall through to [snapshot.resolvedRoleNames] (global
///    grants only at this point) using the precedence ladder from FR-1.
/// 3. If neither produces a match, defaults to [Persona.miembro].
///
/// This function is PURE and SYNCHRONOUS — it reads only from the already-
/// cached snapshot. Zero network calls are made.
Persona resolvePersona(AuthorizationSnapshot? snapshot) {
  if (snapshot == null) return Persona.miembro;

  // Primary signal: the active club assignment's role.
  final activeRoleName = snapshot.activeGrant?.roleName?.trim().toLowerCase();
  if (activeRoleName != null && activeRoleName.isNotEmpty) {
    final persona = _roleToPersona(activeRoleName);
    if (persona != null) return persona;
  }

  // Fallback: highest-privilege role from global grants (resolvedRoleNames
  // at this point only includes global grants when activeGrant is null).
  final globalRoles = snapshot.resolvedRoleNames;
  if (globalRoles.isNotEmpty) {
    // Precedence order per FR-1:
    // coordinator > admin > super-admin > assistant-admin >
    // treasurer > director > counselor > member
    const precedence = [
      'coordinator',
      'admin',
      'super-admin',
      'assistant-admin',
      'treasurer',
      'director',
      'deputy-director',
      'secretary',
      'secretary-treasurer',
      'counselor',
      'member',
    ];
    for (final role in precedence) {
      if (globalRoles.contains(role)) {
        final persona = _roleToPersona(role);
        if (persona != null) return persona;
      }
    }
  }

  return Persona.miembro;
}

/// Maps a single role string to a [Persona], or null if not recognised.
Persona? _roleToPersona(String role) {
  switch (role) {
    case 'member':
      return Persona.miembro;
    case 'counselor':
      return Persona.consejero;
    case 'director':
    case 'deputy-director':
    case 'secretary':
    case 'secretary-treasurer':
      return Persona.director;
    case 'treasurer':
      return Persona.tesorero;
    case 'coordinator':
    case 'admin':
    case 'super-admin':
    case 'assistant-admin':
      return Persona.coordinador;
    default:
      return null;
  }
}

/// Returns the post-login landing route for the given [Persona].
///
/// The redirect in [router.dart] uses this to decide where to send the user
/// after a successful authentication when no deep-link target is present.
///
/// Landing routes per FR-3:
/// - Miembro     → [RouteNames.homeDashboard]
/// - Consejero   → [RouteNames.homeUnits]   (units/list, branch 8)
/// - Director    → [RouteNames.homeMembers] (members,   branch 4)
/// - Tesorero    → [RouteNames.homeFinances] (finances,  branch 7)
/// - Coordinador → [RouteNames.coordinator] (outside main shell)
String personaLandingRoute(Persona persona) {
  switch (persona) {
    case Persona.miembro:
      return RouteNames.homeDashboard;
    case Persona.consejero:
      return RouteNames.homeUnits;
    case Persona.director:
      return RouteNames.homeMembers;
    case Persona.tesorero:
      return RouteNames.homeFinances;
    case Persona.coordinador:
      return RouteNames.coordinator;
  }
}
