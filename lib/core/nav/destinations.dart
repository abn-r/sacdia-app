import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

/// A single navigable destination used across all navigation surfaces
/// (persona nav slots, «Más» bottom sheet, etc.).
///
/// Const-constructible so the [appDestinations] list is a compile-time
/// constant and avoids repeated allocation on rebuild.
class NavDestination {
  /// Translation key resolved at render time via `tr(labelKey)`.
  final String labelKey;

  /// HugeIcons icon constant. Always [HugeIconData] — never `Icons.*`.
  final HugeIconData icon;

  /// Optional tint color. Falls back to the theme text color when null.
  final Color? color;

  /// Static route path. Use for routes that do not depend on runtime context.
  /// Leave empty and provide [routeResolver] for dynamic routes.
  final String route;

  /// Optional resolver for routes that need runtime data (e.g. sectionId from
  /// [clubContextProvider]). Called at render time with a [WidgetRef]. Return
  /// `null` to hide the card / item when context data is unavailable.
  final String? Function(WidgetRef ref)? routeResolver;

  /// Permission keys required to show this destination. Checked via
  /// [hasAnyPermission]. Leave empty when gating is role-based only.
  final Set<String> requiredPermissions;

  /// Canonical role names that gate this destination when it cannot be
  /// modelled as a single permission (e.g. `coordinator`, `admin`). Leave
  /// empty when gating is permission-based only.
  final Set<String> requiredRoles;

  const NavDestination({
    required this.labelKey,
    required this.icon,
    this.color,
    this.route = '',
    this.routeResolver,
    this.requiredPermissions = const {},
    this.requiredRoles = const {},
  });
}

/// Single source of truth for all navigable app destinations.
///
/// Every surface that exposes navigation items (persona nav bar, «Más»
/// sheet, etc.) MUST consume this list and apply RBAC / slot-dedup at render
/// time. Do NOT maintain parallel copies.
///
/// Adding a new destination:
///   1. Add an entry here with appropriate [requiredPermissions] / [requiredRoles].
///   2. Ensure the route is declared in [RouteNames].
///   3. Run `flutter test test/core/nav/destinations_drift_test.dart` to
///      verify the invariants are met.
// ignore: prefer_const_declarations
final List<NavDestination> appDestinations = [
  // Coordination hub — gated by GLOBAL role only. The concept "is the user a
  // coordinator / admin" does not map to a single permission, because club
  // directors also hold operational permissions like `investiture:validate`;
  // using those would incorrectly reveal the hub to directors.
  NavDestination(
    labelKey: 'dashboard.quick_access.coordination',
    icon: HugeIcons.strokeRoundedAnalytics01,
    color: AppColors.info,
    route: RouteNames.coordinator,
    requiredRoles: {'coordinator', 'admin', 'super-admin', 'assistant-admin'},
  ),
  // Administrative: member list — users:read_detail is held by counselor+
  NavDestination(
    labelKey: 'dashboard.quick_access.members',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: AppColors.primary,
    route: RouteNames.homeMembers,
    requiredPermissions: {'users:read_detail'},
  ),
  // Administrative: club management — clubs:update is held by secretary+
  NavDestination(
    labelKey: 'dashboard.quick_access.club',
    icon: HugeIcons.strokeRoundedBuilding01,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    requiredPermissions: {'clubs:update'},
  ),
  // Administrative: evidence folder management — uses users:read_detail.
  // Members access their OWN evidence via the profile screen, not this view.
  NavDestination(
    labelKey: 'dashboard.quick_access.evidence_folder',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    requiredPermissions: {'users:read_detail'},
  ),
  // Administrative: financial records — finances:read is held by treasurer+
  NavDestination(
    labelKey: 'dashboard.quick_access.finances',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    requiredPermissions: {'finances:read'},
  ),
  // Administrative: unit management — units:update is held by counselor+
  NavDestination(
    labelKey: 'dashboard.quick_access.units',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    requiredPermissions: {'units:update'},
  ),
  // Administrative: group class management — classes:submit_progress is held by counselor+
  NavDestination(
    labelKey: 'dashboard.quick_access.grouped_class',
    icon: HugeIcons.strokeRoundedBookOpen01,
    color: AppColors.primary,
    route: RouteNames.homeGroupedClass,
    requiredPermissions: {'classes:submit_progress'},
  ),
  // Administrative: insurance management
  NavDestination(
    labelKey: 'dashboard.quick_access.insurance',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    requiredPermissions: {'insurance:read'},
  ),
  // Administrative: inventory management
  NavDestination(
    labelKey: 'dashboard.quick_access.inventory',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    requiredPermissions: {'inventory:read'},
  ),
  // Club-wide shared resources — folders:read is granted to every club role.
  NavDestination(
    labelKey: 'dashboard.quick_access.resources',
    icon: HugeIcons.strokeRoundedFiles01,
    route: RouteNames.homeResources,
    requiredPermissions: {'folders:read'},
  ),
  // Mi ranking — only visible to roles that hold member_rankings:read_self
  // (MEMBER club-scope, ADMIN global, SUPER_ADMIN global). Other club roles
  // (director, counselor, secretary, treasurer…) do not have this permission
  // and must not see the entry.
  NavDestination(
    labelKey: 'dashboard.quick_access.my_ranking',
    icon: HugeIcons.strokeRoundedRanking,
    color: AppColors.accent,
    route: RouteNames.homeMyRanking,
    requiredPermissions: {'member_rankings:read_self'},
  ),
  // Ranking de sección — gated by units:update (counselor+). Route is
  // resolved at render time because it requires the active sectionId from
  // clubContextProvider. Card is hidden when context is unavailable.
  NavDestination(
    labelKey: 'dashboard.quick_access.section_ranking',
    icon: HugeIcons.strokeRoundedAward01,
    color: AppColors.primary,
    routeResolver: (ref) {
      final ctxAsync = ref.watch(clubContextProvider);
      final sectionId = ctxAsync.valueOrNull?.sectionId;
      if (sectionId == null) return null;
      return RouteNames.sectionRankingPath(sectionId);
    },
    requiredPermissions: {'units:update'},
  ),
];
