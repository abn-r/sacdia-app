import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';

// `coordinatorRoleNames` vive con los predicados de autorización (lo usa
// `isCoordinatorWithoutClub`); se reexporta aquí para quien ya lo importa de
// este archivo.
export '../../../auth/domain/utils/authorization_utils.dart'
    show coordinatorRoleNames;

/// Permiso que el servidor exige para APROBAR una solicitud
/// (`club_members:approve`). Un revisor con solo `consent:verify` puede
/// verificar la ficha pero no aprobar (403 `MR_APPROVE_PERMISSION_REQUIRED`).
const Set<String> approveJoinRequestPermissions = {'club_members:approve'};

/// El usuario ve "Confirmar y aprobar". Sin el permiso la vista queda en modo
/// "solo verificar". El servidor sigue siendo la autoridad.
bool canApproveJoinRequests(UserEntity? user) =>
    hasAnyPermission(user, approveJoinRequestPermissions);

/// Permiso con el que se revisa una ficha de consentimiento sin poder aprobar
/// (`consent:verify`): coordinadores y revisores "solo verificar".
const Set<String> verifyConsentPermissions = {'consent:verify'};

/// Qué puede hacer el usuario con las solicitudes de ingreso de su sección.
enum JoinRequestsAccess {
  /// Sin `club_members:approve` ni `consent:verify`: no hay modo Solicitudes.
  none,

  /// Solo `consent:verify`: ve las fichas por verificar, sin aprobar ni
  /// rechazar.
  verifyOnly,

  /// `club_members:approve`: vista completa de director.
  approve,
}

bool _grantHas(AuthorizationGrant grant, Set<String> permissions) => grant
    .permissions
    .any((permission) => permissions.contains(permission.trim().toLowerCase()));

/// El usuario tiene un rol global DE COORDINACIÓN que lleva `consent:verify`:
/// lo que exige el servidor para «Fichas por verificar» del panel de
/// coordinación (`GET /coordination/me/consent-pending`). Un permiso suelto o de
/// otro rol no basta. Espejo de `coordinatorRoleCanVerify` del admin.
bool coordinatorRoleCanVerify(UserEntity? user) {
  final authorization = user?.authorization;
  if (authorization == null) return false;
  return authorization.globalGrants.any((grant) {
    final role = grant.roleName?.trim().toLowerCase();
    return role != null &&
        coordinatorRoleNames.contains(role) &&
        _grantHas(grant, verifyConsentPermissions);
  });
}

/// `consent:verify` por AUTORIDAD DE CLUB: lo trae el rol de la sección activa,
/// un rol global que no es de coordinación o un permiso directo, igual que
/// `clubAuthority` en el `PermissionsGuard` del backend. Un coordinador que es
/// solo miembro de la sección NO lo tiene (403 `GUARD_CLUB_SCOPE_REQUIRED`
/// fuera de sus asignaciones).
///
/// `/auth/me` entrega los permisos por origen (`grants.global_roles[]`,
/// `grants.club_assignments[]`), y `effective.permissions` es la unión de los
/// globales, los directos y los del rol activo. Un permiso efectivo que ningún
/// rol global ni el rol activo lista es, por tanto, directo.
bool hasClubVerifyAuthority(UserEntity? user) {
  final authorization = user?.authorization;
  if (authorization == null) return false;
  if (!hasAnyPermission(user, verifyConsentPermissions)) return false;

  final active = authorization.activeGrant;
  if (active != null &&
      active.isActive &&
      _grantHas(active, verifyConsentPermissions)) {
    return true;
  }

  var heldByAGlobalRole = false;
  for (final grant in authorization.globalGrants) {
    if (!_grantHas(grant, verifyConsentPermissions)) continue;
    heldByAGlobalRole = true;
    final role = grant.roleName?.trim().toLowerCase();
    if (role == null || !coordinatorRoleNames.contains(role)) return true;
  }

  // Ningún rol lo lista: viene de un permiso directo del usuario.
  return !heldByAGlobalRole;
}

/// Acceso del usuario a las solicitudes. Aprobar manda sobre verificar: el
/// servidor acepta cualquiera de los dos permisos en el listado, pero solo el
/// primero aprueba y rechaza. «Solo verificar» exige `consent:verify` por
/// autoridad de club ([hasClubVerifyAuthority]); el de un coordinador se usa en
/// su panel.
JoinRequestsAccess joinRequestsAccess(UserEntity? user) {
  if (canApproveJoinRequests(user)) return JoinRequestsAccess.approve;
  if (hasClubVerifyAuthority(user)) return JoinRequestsAccess.verifyOnly;
  return JoinRequestsAccess.none;
}
