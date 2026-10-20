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
