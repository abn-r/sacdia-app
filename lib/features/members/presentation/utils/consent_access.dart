import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';

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

/// Acceso del usuario a las solicitudes. Aprobar manda sobre verificar: el
/// servidor acepta cualquiera de los dos permisos en el listado, pero solo el
/// primero aprueba y rechaza.
JoinRequestsAccess joinRequestsAccess(UserEntity? user) {
  if (canApproveJoinRequests(user)) return JoinRequestsAccess.approve;
  if (hasAnyPermission(user, verifyConsentPermissions)) {
    return JoinRequestsAccess.verifyOnly;
  }
  return JoinRequestsAccess.none;
}
