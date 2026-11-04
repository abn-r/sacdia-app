import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/authorization/access_subject.dart';
import 'package:sacdia_app/core/authorization/screen_catalog.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';

/// Un acceso del launcher del inicio (modelo compartido por las distintas
/// maquetas: [QuickAccessGrid] y las experimentales).
class QuickAccessItem {
  /// Translation key resolved at render time via tr(labelKey).
  final String labelKey;
  final HugeIconData icon;
  final Color? color;

  /// Static route path.
  final String route;

  /// Screen catalog id. Omit only for runtime tiles (judge assignment).
  final String? screenId;

  /// El súper-admin pasa todo el catálogo, pero estas pantallas dependen de un
  /// rol operativo concreto (el backend no deja autorizar ni presentar al
  /// súper-admin): se evalúan por los roles reales, sin ese atajo.
  final bool ignoreSuperAdminBypass;

  const QuickAccessItem({
    required this.labelKey,
    required this.icon,
    this.color,
    this.route = '',
    this.screenId,
    this.ignoreSuperAdminBypass = false,
  });
}

/// Pantalla del catálogo que abre «Unidades» (`units:update`). Un líder de
/// unidad sin ese permiso entra por otra vía: ver [leadsUnitInActiveSectionProvider].
const quickAccessUnitsScreenId = 'app-units';

List<QuickAccessItem> _quickAccessItemsConfig = [
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.members',
    icon: HugeIcons.strokeRoundedUserGroup,
    route: RouteNames.homeMembers,
    screenId: 'app-members',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.club',
    icon: HugeIcons.strokeRoundedBackpack03,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    screenId: 'app-club',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.evidence_folder',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    screenId: 'clubs-evidence-folders-list',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.camporees',
    icon: HugeIcons.strokeRoundedCampfire,
    color: AppColors.warning,
    route: RouteNames.homeCamporees,
    screenId: 'campamentos-list-local',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.finances',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    screenId: 'finances',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.units',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    screenId: quickAccessUnitsScreenId,
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.grouped_class',
    icon: HugeIcons.strokeRoundedBookOpen01,
    route: RouteNames.homeGroupedClass,
    screenId: 'app-grouped-class',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.investiture',
    icon: HugeIcons.strokeRoundedMedal01,
    color: AppColors.accent,
    route: RouteNames.sectionInvestiture,
    screenId: 'app-section-investiture',
    ignoreSuperAdminBypass: true,
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.authorizations',
    icon: HugeIcons.strokeRoundedCheckmarkBadge01,
    color: AppColors.secondary,
    route: RouteNames.investitureAuthorize,
    screenId: 'app-investiture-authorizer',
    ignoreSuperAdminBypass: true,
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.insurance',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    screenId: 'insurance-by-section',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.inventory',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    screenId: 'club-inventory',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.materials',
    icon: HugeIcons.strokeRoundedShoppingCart01,
    color: AppColors.info,
    route: RouteNames.homeMaterials,
    screenId: 'app-materials',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.resources',
    icon: HugeIcons.strokeRoundedFiles01,
    route: RouteNames.homeResources,
    screenId: 'resources-list',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.reports',
    icon: HugeIcons.strokeRoundedAnalytics01,
    color: AppColors.info,
    route: RouteNames.homeReports,
    screenId: 'reports-list',
  ),
  QuickAccessItem(
    labelKey: 'dashboard.quick_access.club_rankings',
    icon: HugeIcons.strokeRoundedMedal05,
    route: RouteNames.homeClubRankings,
    screenId: 'annual-folders-rankings',
  ),
];

const _judgeQuickAccessItem = QuickAccessItem(
  labelKey: 'dashboard.quick_access.camporee_judge',
  icon: HugeIcons.strokeRoundedNoteEdit,
  color: AppColors.warning,
  route: RouteNames.camporeeJudgeAssignments,
);

/// Resuelve los accesos visibles para [user], ya filtrados por permisos.
///
/// Lógica única del launcher: la comparten [QuickAccessGrid] y las maquetas
/// experimentales, así que todas muestran exactamente los mismos destinos.
///
/// - Sin autorización o sin superficie operativa del club (membresía
///   pendiente/inactiva) devuelve vacío.
/// - [unitsViaLeadership]: el usuario lidera una unidad de la sección activa
///   (ver [leadsUnitInActiveSectionProvider]); abre «Unidades» aunque el
///   catálogo (`units:update`) no lo conceda.
/// - [showJudgeTile]: tiene una asignación de juez con captura oficial.
List<QuickAccessItem> resolveQuickAccessItems({
  required UserEntity? user,
  required bool unitsViaLeadership,
  required bool showJudgeTile,
}) {
  if (user?.authorization == null) return const [];
  if (!canAccessClubOperationalSurface(user)) return const [];

  final subject = subjectFromUser(user);
  final withoutSuperAdminBypass = AccessSubject(
    permissions: subject.permissions,
    roles: subject.roles,
    isSuperAdmin: false,
  );

  final items = _quickAccessItemsConfig.where((item) {
    final screenId = item.screenId;
    if (screenId == null) return true;
    if (screenId == quickAccessUnitsScreenId && unitsViaLeadership) return true;
    return canViewScreen(
      item.ignoreSuperAdminBypass ? withoutSuperAdminBypass : subject,
      screenId,
    );
  }).toList();

  if (showJudgeTile) {
    final camporeeIndex = items.indexWhere(
      (item) => item.route == RouteNames.homeCamporees,
    );
    items.insert(
      camporeeIndex >= 0 ? camporeeIndex + 1 : items.length,
      _judgeQuickAccessItem,
    );
  }

  return items;
}

/// Accesos del launcher visibles para el usuario autenticado.
///
/// Observa la sesión, el liderazgo de unidad (solo si el catálogo no concede
/// «Unidades» y el usuario tiene `units:read`, falla cerrado mientras carga) y
/// las asignaciones de juez de camporee. Vacío mientras la sesión carga.
final visibleQuickAccessItemsProvider =
    Provider.autoDispose<List<QuickAccessItem>>((ref) {
  final user = ref.watch(authNotifierProvider.select((v) => v.value));
  if (user?.authorization == null) return const [];

  final subject = subjectFromUser(user);
  final unitsViaCatalog = canViewScreen(subject, quickAccessUnitsScreenId);
  final unitsViaLeadership = !unitsViaCatalog &&
      hasAnyPermission(user, const {'units:read'}) &&
      ref.watch(leadsUnitInActiveSectionProvider);

  final showJudgeTile = ref.watch(camporeeJudgeAssignmentsProvider).maybeWhen(
        data: (assignments) =>
            assignments.any((assignment) => assignment.canCaptureOfficialScore),
        orElse: () => false,
      );

  return resolveQuickAccessItems(
    user: user,
    unitsViaLeadership: unitsViaLeadership,
    showJudgeTile: showJudgeTile,
  );
});
