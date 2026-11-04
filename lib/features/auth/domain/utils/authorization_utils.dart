import '../entities/authorization_snapshot.dart';
import '../entities/principal_info.dart';
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
  SensitiveUserFamily.health: {'health:update', 'users:update_profile'},
  SensitiveUserFamily.emergencyContacts: {
    'emergency_contacts:update',
    'users:update_profile',
  },
  SensitiveUserFamily.legalRepresentative: {
    'legal_representative:update',
    'users:update_profile',
  },
  // No `post_registration:update` grant exists; the route falls back to users:update_profile.
  SensitiveUserFamily.postRegistration: {'users:update_profile'},
};

const Set<String> memberRankingReadSelfPermissions = {
  'member_rankings:read_self',
};

const Set<String> sectionRankingReadPermissions = {
  'section_rankings:read_club',
  'section_rankings:read_lf',
  'section_rankings:read_global',
};

const Set<String> clubRankingReadPermissions = {
  'rankings:read',
};

const Set<String> reportReadPermissions = {
  'reports:read',
};

/// Mirrors `@RequirePermissions('activities:update')` on
/// `PATCH /activities/:activityId` (activities.controller.ts).
const Set<String> activityUpdatePermissions = {
  'activities:update',
};

/// Mirrors `@RequirePermissions('activities:delete')` on
/// `DELETE /activities/:activityId` (activities.controller.ts).
const Set<String> activityDeletePermissions = {
  'activities:delete',
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

/// ¿El servidor concedió al actor la capacidad [capability]
/// (`/auth/me.authorization.capabilities`, claves `a.b` de `kCapabilityKeys`)?
///
/// Es la forma canónica de preguntar «¿puede intentarlo?» en la app: nunca se
/// compara el nombre de un rol. Semántica del contrato: «el actor puede
/// intentarlo sobre al menos un objetivo»; el servidor sigue respondiendo 403
/// si el objetivo no coincide. Sin autorización, o con un servidor que aún no
/// publica capacidades, es `false` (deny).
bool hasCapability(UserEntity? user, String capability) {
  final authorization = user?.authorization;
  if (authorization == null) return false;
  return authorization.hasCapability(capability);
}

/// Canonical role-name check against `user.authorization.resolvedRoleNames`.
/// Use this only when the gate is genuinely role-based (global roles like
/// `coordinator`, `admin`, `super-admin`). Prefer [hasAnyPermission] for
/// anything permission-driven and [hasCapability] for anything the backend
/// already computes as a capability.
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

bool canViewMyRanking(UserEntity? user) {
  return hasAnyPermission(user, memberRankingReadSelfPermissions);
}

bool canViewSectionRankings(UserEntity? user) {
  return hasAnyPermission(user, sectionRankingReadPermissions);
}

bool canViewClubRankings(UserEntity? user) {
  return hasAnyPermission(user, clubRankingReadPermissions);
}

bool canUpdateActivities(UserEntity? user) {
  return hasAnyPermission(user, activityUpdatePermissions);
}

bool canDeleteActivities(UserEntity? user) {
  return hasAnyPermission(user, activityDeletePermissions);
}

bool _isDesignated(AuthorizationGrant grant) => grant.status == 'designated';

/// Assignments that may appear in the club switcher (never a scheduled director).
List<AuthorizationGrant> visibleClubAssignments(
  List<AuthorizationGrant> assignments,
) {
  return assignments.where((grant) => !_isDesignated(grant)).toList();
}

/// Assignments that can become the active operational context.
List<AuthorizationGrant> selectableClubAssignments(
  List<AuthorizationGrant> assignments,
) {
  return assignments.where((grant) => grant.isActive).toList();
}

AuthorizationGrant? membershipGrantForDisplay(
  AuthorizationSnapshot? authorization,
) {
  if (authorization == null) return null;

  final assignments = authorization.clubAssignments;
  if (selectableClubAssignments(assignments).isNotEmpty) {
    return null;
  }

  final activeGrant = authorization.activeGrant;
  if (activeGrant != null &&
      !_isDesignated(activeGrant) &&
      !activeGrant.isActive) {
    return activeGrant;
  }

  for (final grant in assignments) {
    if (_isDesignated(grant) || grant.isActive) continue;
    return grant;
  }

  return null;
}

bool canAccessClubOperationalSurface(UserEntity? user) {
  final authorization = user?.authorization;
  if (authorization == null) return false;
  return membershipGrantForDisplay(authorization) == null;
}

/// Permisos cuya sola presencia en el ámbito activo convierte el inicio en el
/// de gestión (pendientes, accesos operativos), aunque el rol sea de miembro.
const Set<String> clubStaffHomePermissions = {
  'club_members:approve',
  'consent:verify',
  'evidence_folders:read',
  'reports:submit',
};

/// ¿El inicio debe mostrarse en modo gestión (staff) y no en modo miembro?
///
/// Es modo gestión cuando el usuario opera el club (ver
/// [canAccessClubOperationalSurface]) y además:
///   - el servidor le concede `club.staff_mode` (su concesión activa es de
///     club y su rol no es `member`), o
///   - conserva alguno de [clubStaffHomePermissions] en el ámbito activo.
///
/// Todo lo demás (miembro sin esos permisos, concesión pendiente o inactiva,
/// sin autorización) es modo miembro.
bool isClubStaffMode(UserEntity? user) {
  if (!canAccessClubOperationalSurface(user)) return false;
  if (hasCapability(user, 'club.staff_mode')) return true;
  return hasAnyPermission(user, clubStaffHomePermissions);
}

/// ¿Es un pastor «solo pastor» (`admin_panel.pastor_only`: roles globales no
/// vacíos y todos pastor) sin ninguna presencia en un club?
///
/// Esa persona no pasa por el post-registro de club ni ve el inicio de un
/// miembro: la app le muestra solo «Autorizaciones» y su perfil. Con cualquier
/// asignación de club utilizable, pendiente, inactiva o vencida, deja de
/// calificar y conserva el flujo normal.
bool isPastorWithoutClub(UserEntity? user) {
  final authorization = user?.authorization;
  if (authorization == null) return false;
  if (!hasCapability(user, 'admin_panel.pastor_only')) return false;
  return authorization.clubAssignments.every(_isDesignated);
}

/// ¿Puede ver el panel de coordinación (`coordination.hub_view`) sin ninguna
/// presencia en un club?
///
/// Igual que el pastor sin club: no pasa por el post-registro de club y su
/// inicio no es el resumen de un club sino el panel de coordinación. No exige
/// `consent:verify` ni secciones asignadas: el propio panel resuelve esos
/// estados (alcance vacío, sin fichas). Con cualquier asignación de club
/// visible (activa, pendiente, inactiva o vencida) deja de calificar y conserva
/// el flujo normal; las `designated` no cuentan como pertenencia. Es falso
/// mientras se actúa por un dependiente.
///
/// Precedencia: si además es tutor, el inicio es la coordinación y «Mi familia»
/// sigue disponible desde el perfil. Si además es pastor sin club, el inicio
/// también es la coordinación (ver `coordinator_route_access.dart`).
bool isCoordinatorWithoutClub(UserEntity? user) {
  if (user == null || user.actingFor != null) return false;
  final authorization = user.authorization;
  if (authorization == null) return false;
  if (!hasCapability(user, 'coordination.hub_view')) return false;
  return visibleClubAssignments(authorization.clubAssignments).isEmpty;
}

/// ¿Es un tutor que no pertenece a ningún club?
///
/// Es el caso de quien cerró el post-registro por «solo tutor»: tiene la cuenta
/// completa y dependientes, pero ninguna asignación de club, así que no hay
/// resumen de dashboard que mostrar. No inventa campos del servidor: se deriva
/// de `family` (`is_guardian`, `dependents_count`) y de las asignaciones de
/// club de `authorization`.
///
/// Es falso mientras se actúa por un dependiente y con cualquier asignación
/// visible (activa, pendiente, inactiva o vencida; las `designated` no cuentan
/// como pertenencia).
bool isGuardianWithoutClub(UserEntity? user) {
  if (user == null || user.actingFor != null) return false;
  final assignments = user.authorization?.clubAssignments ?? const [];
  if (visibleClubAssignments(assignments).isNotEmpty) return false;
  final family = user.family;
  final isGuardian =
      family != null && (family.isGuardian || family.dependentsCount > 0);
  // Sin datos de tutoría, solo califica quien ya completó el post-registro y
  // el servidor devolvió su autorización sin clubes (cuenta de tutor sin club).
  final completedWithoutClub =
      user.postRegisterComplete && user.authorization != null;
  return isGuardian || completedWithoutClub;
}

/// ¿Debe pasar por el post-registro de club?
///
/// Falta completarlo, salvo para el pastor o el coordinador sin club: su
/// cuenta no tiene datos de club que completar. Una cuenta sin fecha de nacimiento
/// (`profile_incomplete`) lo necesita siempre: la restricción la levanta el
/// servidor, no la bandera local.
bool userNeedsPostRegistration(UserEntity user) =>
    user.mode == AccountMode.profileIncomplete ||
    (!user.postRegisterComplete &&
        !isPastorWithoutClub(user) &&
        !isCoordinatorWithoutClub(user));

/// ¿Se ofrece «Eliminar cuenta» en el menú del post-registro?
///
/// La guideline 5.1.1(v) de App Store exige poder borrar la cuenta dentro de la
/// app aunque el registro no haya terminado (un alta nueva con Apple/Google es
/// `age_unknown_user`). Solo para quien puede borrar SU cuenta: un adulto o una
/// cuenta sin fecha de nacimiento (`account:manage`). Nunca mientras se actúa
/// por un dependiente, ni para un adolescente supervisado (su borrado lo
/// gestiona el tutor o un administrador) ni para un principal desconocido.
bool canDeleteAccountInPostRegistration(
  UserEntity? user, {
  required bool acting,
}) {
  if (user == null || acting || user.actingFor != null) return false;
  final kind = user.principal?.kind ?? PrincipalKind.user;
  final kindAllowed =
      kind == PrincipalKind.user || kind == PrincipalKind.ageUnknownUser;
  final mode = user.mode;
  final modeAllowed =
      mode == AccountMode.adult || mode == AccountMode.profileIncomplete;
  return kindAllowed && modeAllowed;
}

/// ¿Debe aceptar los documentos legales vigentes antes de usar la app?
bool userNeedsLegalAcceptance(UserEntity user) => user.legalAcceptancePending;

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
