import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_nav_config.dart';
import 'package:sacdia_app/core/persona/persona_providers.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

/// A single navigable destination exposed in the «Más» sheet.
///
/// Mirrors the structure of the private `_QuickAccessItemConfig` in
/// `quick_access_grid.dart` so that the sheet can reuse the same RBAC
/// predicates ([hasAnyPermission] / [hasAnyRole]) without coupling to the
/// dashboard widget's private types.
@visibleForTesting
class MoreSheetDestination {
  final String labelKey;
  final HugeIconData icon;
  final Color? color;

  /// Static route path. Use when the route does not depend on runtime context.
  final String route;

  /// Optional resolver for routes that need runtime data (e.g. sectionId).
  /// Return `null` to hide the item when context data is unavailable.
  final String? Function(WidgetRef ref)? routeResolver;

  final Set<String> requiredPermissions;
  final Set<String> requiredRoles;

  const MoreSheetDestination({
    required this.labelKey,
    required this.icon,
    this.color,
    this.route = '',
    this.routeResolver,
    this.requiredPermissions = const {},
    this.requiredRoles = const {},
  });
}

/// Master list of all navigable destinations that can appear in the «Más» sheet.
///
/// This list intentionally mirrors [_quickAccessItemsConfig] from
/// `quick_access_grid.dart` so the same destinations are reachable from both
/// surfaces. RBAC gating is applied at render time via [hasAnyPermission] /
/// [hasAnyRole]. Persona-nav-slot dedup is applied per [_buildSheetItems].
///
/// NOTE: Do NOT add new routes here unless they are also present in
/// [_quickAccessItemsConfig]. The «Más» sheet is a secondary surface for
/// out-of-band navigation, not a primary feature launcher.
const List<MoreSheetDestination> moreSheetDestinations = [
  // Coordination hub — gated by GLOBAL role only.
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.coordination',
    icon: HugeIcons.strokeRoundedAnalytics01,
    color: AppColors.info,
    route: RouteNames.coordinator,
    requiredRoles: {'coordinator', 'admin', 'super-admin', 'assistant-admin'},
  ),
  // Member list — users:read_detail is held by counselor+
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.members',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: AppColors.primary,
    route: RouteNames.homeMembers,
    requiredPermissions: {'users:read_detail'},
  ),
  // Club management — clubs:update is held by secretary+
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.club',
    icon: HugeIcons.strokeRoundedBuilding01,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    requiredPermissions: {'clubs:update'},
  ),
  // Evidence folder management — users:read_detail
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.evidence_folder',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    requiredPermissions: {'users:read_detail'},
  ),
  // Financial records — finances:read is held by treasurer+
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.finances',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    requiredPermissions: {'finances:read'},
  ),
  // Unit management — units:update is held by counselor+
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.units',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    requiredPermissions: {'units:update'},
  ),
  // Group class management — classes:submit_progress is held by counselor+
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.grouped_class',
    icon: HugeIcons.strokeRoundedBookOpen01,
    color: AppColors.primary,
    route: RouteNames.homeGroupedClass,
    requiredPermissions: {'classes:submit_progress'},
  ),
  // Insurance management
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.insurance',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    requiredPermissions: {'insurance:read'},
  ),
  // Inventory management
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.inventory',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    requiredPermissions: {'inventory:read'},
  ),
  // Club-wide shared resources — folders:read is granted to every club role
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.resources',
    icon: HugeIcons.strokeRoundedFiles01,
    route: RouteNames.homeResources,
    requiredPermissions: {'folders:read'},
  ),
  // My ranking — member_rankings:read_self (member scope)
  MoreSheetDestination(
    labelKey: 'dashboard.quick_access.my_ranking',
    icon: HugeIcons.strokeRoundedRanking,
    color: AppColors.accent,
    route: RouteNames.homeMyRanking,
    requiredPermissions: {'member_rankings:read_self'},
  ),
];

// ─── Sheet logic ──────────────────────────────────────────────────────────────

/// Value object that pairs a [MoreSheetDestination] with its resolved route.
class MoreSheetResolvedItem {
  final MoreSheetDestination dest;
  final String resolvedRoute;

  const MoreSheetResolvedItem({required this.dest, required this.resolvedRoute});
}

/// Pure filtering function: returns items from [moreSheetDestinations] that
/// pass the persona-slot dedup and RBAC checks.
///
/// Filtering rules (applied in order):
/// 1. Remove items whose static route is in [navRoutes].
/// 2. Remove items the user has no RBAC access to (no permission AND no role).
/// 3. Remove items with a dynamic [routeResolver] that resolves to null.
///
/// [ref] is optional — when provided, dynamic route resolvers are evaluated.
/// When null (e.g. in unit tests without a widget tree), dynamic-route items
/// are skipped.
@visibleForTesting
List<MoreSheetResolvedItem> filterSheetDestinations({
  required Set<String> navRoutes,
  required UserEntity? user,
  WidgetRef? ref,
}) {
  final result = <MoreSheetResolvedItem>[];
  for (final dest in moreSheetDestinations) {
    // 1. Skip if static route is already in persona nav slots.
    if (dest.routeResolver == null && navRoutes.contains(dest.route)) continue;

    // 2. RBAC gate — mirrors QuickAccessGrid's filter predicate exactly.
    if (dest.requiredPermissions.isEmpty && dest.requiredRoles.isEmpty) {
      // Ungated — visible to all authenticated users.
    } else {
      final hasPermission = dest.requiredPermissions.isNotEmpty &&
          hasAnyPermission(user, dest.requiredPermissions);
      final hasRole = dest.requiredRoles.isNotEmpty &&
          hasAnyRole(user, dest.requiredRoles);
      if (!hasPermission && !hasRole) continue;
    }

    // 3. Dynamic route resolution — hide when context data is unavailable.
    String resolvedRoute;
    if (dest.routeResolver != null) {
      if (ref == null) continue; // No ref available to resolve dynamic route.
      final resolved = dest.routeResolver!(ref);
      if (resolved == null) continue;
      if (navRoutes.contains(resolved)) continue; // Dedup vs nav slots.
      resolvedRoute = resolved;
    } else {
      resolvedRoute = dest.route;
    }

    result.add(MoreSheetResolvedItem(dest: dest, resolvedRoute: resolvedRoute));
  }
  return result;
}

/// Provider-aware wrapper: reads auth from [ref] and delegates to
/// [filterSheetDestinations].
@visibleForTesting
List<MoreSheetResolvedItem> buildSheetItems({
  required Persona persona,
  required WidgetRef ref,
}) {
  final navRoutes = personaNavConfig[persona]!.map((s) => s.route).toSet();
  final user = ref.read(authNotifierProvider).valueOrNull;
  return filterSheetDestinations(navRoutes: navRoutes, user: user, ref: ref);
}

// ─── Public API ───────────────────────────────────────────────────────────────

/// Opens the «Más» bottom sheet for the current persona.
///
/// Call from any entry point (dashboard action bar, profile tile, etc.):
/// ```dart
/// showMoreSheet(context: context, ref: ref);
/// ```
void showMoreSheet({required BuildContext context, required WidgetRef ref}) {
  // Capture the parent container before the sheet opens so that the sheet
  // inherits all provider overrides from the calling scope.
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _MoreSheetContent(),
    ),
  );
}

// ─── Sheet content widget ─────────────────────────────────────────────────────

class _MoreSheetContent extends ConsumerWidget {
  const _MoreSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(currentPersonaProvider);
    // Use ref.watch so the sheet reactively updates if auth state changes.
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final navRoutes =
        personaNavConfig[persona]!.map((s) => s.route).toSet();
    final items = filterSheetDestinations(
      navRoutes: navRoutes,
      user: user,
      ref: ref,
    );
    final c = context.sac;

    return Semantics(
      label: 'nav.more_sheet_title'.tr(),
      child: Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // DraggableScrollableSheet constraints: min 30% screen, max 85%.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title row ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'nav.more_sheet_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'common.close'.tr(),
                    button: true,
                    child: IconButton(
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'common.close'.tr(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Items list ─────────────────────────────────────────────
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'common.no_results'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _MoreSheetTile(
                      item: item.dest,
                      resolvedRoute: item.resolvedRoute,
                    );
                  },
                ),
              ),

            // ── Safe-area bottom padding ───────────────────────────────
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ─── Individual tile ──────────────────────────────────────────────────────────

class _MoreSheetTile extends StatelessWidget {
  final MoreSheetDestination item;
  final String resolvedRoute;

  const _MoreSheetTile({
    required this.item,
    required this.resolvedRoute,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveColor = item.color ?? c.text;

    return Semantics(
      button: true,
      label: item.labelKey.tr(),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(resolvedRoute);
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    size: 20,
                    color: effectiveColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Label
              Expanded(
                child: Text(
                  item.labelKey.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
              // Chevron
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
