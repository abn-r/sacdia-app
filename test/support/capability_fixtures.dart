/// Espejo de la tabla de capacidades del backend (fase 7) para las FIXTURES de
/// los tests: la app nunca deriva capacidades de roles (eso lo hace el
/// servidor), pero un fixture construido con roles necesita las mismas
/// capacidades que `/auth/me` devolvería.
///
/// G = roles globales, A = rol de la concesión de club activa.
library;

import 'package:sacdia_app/core/authorization/generated/role_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';

const Set<String> kHubViewRoles = {
  'super-admin',
  'admin',
  'assistant-admin',
  'coordinator',
  'zone-coordinator',
  'general-coordinator',
  'director-lf',
  'assistant-lf',
};

const Set<String> kAuthorizerRoles = {'director-lf', 'assistant-lf', 'pastor'};

const Set<String> kOperationalStaffRoles = {
  'director',
  'deputy-director',
  'secretary',
  'treasurer',
  'secretary-treasurer',
  'counselor',
};

const Set<String> kUnitsManageRoles = {
  'director',
  'deputy-director',
  'secretary',
  'treasurer',
  'secretary-treasurer',
};

const Set<String> kInvestitureBoardRoles = {
  'director',
  'secretary',
  'secretary-treasurer',
};

String _norm(String? role) => (role ?? '').trim().toLowerCase();

/// Capacidades (ordenadas) que el backend publicaría para [globalRoles] y el
/// rol [activeClubRole] de la concesión de club activa.
List<String> capabilitiesFor({
  Iterable<String?> globalRoles = const [],
  String? activeClubRole,
}) {
  final g = globalRoles.map(_norm).where((r) => r.isNotEmpty).toSet();
  final a = _norm(activeClubRole);
  final out = <String>{};
  if (g.isNotEmpty && g.every((r) => r == 'pastor')) {
    out.add('admin_panel.pastor_only');
  }
  if (g.any(kHubViewRoles.contains)) out.add('coordination.hub_view');
  if (g.any(kAuthorizerRoles.contains)) {
    out.add('investiture.authorize_requests');
  }
  // A es siempre un rol de CLUB del catálogo generado.
  if (kClubRoleNames.contains(a)) {
    if (a != 'member') out.add('club.staff_mode');
    if (a == 'director') out.add('club.active_director');
    if (kOperationalStaffRoles.contains(a)) out.add('club.operational_staff');
    if (kUnitsManageRoles.contains(a)) {
      out.add('units.manage');
      out.add('camporee_orders.issue');
    }
    if (kInvestitureBoardRoles.contains(a)) {
      out.add('investiture.board');
      out.add('camporee_supplies.plan');
    }
  }
  return out.toList()..sort();
}

/// Copia de [snapshot] con las capacidades que el backend derivaría de sus
/// roles globales y de su concesión activa (solo si está vigente).
AuthorizationSnapshot withDerivedCapabilities(AuthorizationSnapshot snapshot) {
  final active = snapshot.activeGrant;
  return AuthorizationSnapshot(
    effectivePermissions: snapshot.effectivePermissions,
    globalGrants: snapshot.globalGrants,
    clubAssignments: snapshot.clubAssignments,
    activeAssignmentId: snapshot.activeAssignmentId,
    capabilities: capabilitiesFor(
      globalRoles: snapshot.globalGrants.map((g) => g.roleName),
      activeClubRole:
          active != null && active.isActive ? active.roleName : null,
    ),
    territory: snapshot.territory,
    assignableGlobalRoles: snapshot.assignableGlobalRoles,
  );
}
