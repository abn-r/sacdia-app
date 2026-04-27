import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

class _QuickAccessItemConfig {
  /// Translation key resolved at render time via tr(labelKey).
  final String labelKey;
  final List<List<dynamic>> icon;
  final Color? color;
  final String route;
  final Set<String> requiredPermissions;

  /// Canonical role names to gate against when the item is not permission-based.
  /// Only used for global roles whose authority cannot be modeled as a single
  /// permission (e.g. `coordinator`, `admin`). Leave empty when the item is
  /// gated purely by [requiredPermissions].
  final Set<String> requiredRoles;

  const _QuickAccessItemConfig({
    required this.labelKey,
    required this.icon,
    this.color,
    required this.route,
    this.requiredPermissions = const {},
    this.requiredRoles = const {},
  });
}

const List<_QuickAccessItemConfig> _quickAccessItemsConfig = [
  // Coordination hub — gated by GLOBAL role only. The concept "is the user a
  // coordinator / admin" does not map to a single permission, because club
  // directors also hold operational permissions like `investiture:validate`;
  // using those would incorrectly reveal the hub to directors.
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.coordination',
    icon: HugeIcons.strokeRoundedAnalytics01,
    color: AppColors.info,
    route: RouteNames.coordinator,
    requiredRoles: {'coordinator', 'admin', 'super_admin', 'assistant_admin'},
  ),
  // Administrative: member list — users:read_detail is held by counselor+
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.members',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: AppColors.primary,
    route: RouteNames.homeMembers,
    requiredPermissions: {'users:read_detail'},
  ),
  // Administrative: club management — clubs:update is held by secretary+
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.club',
    icon: HugeIcons.strokeRoundedBuilding01,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    requiredPermissions: {'clubs:update'},
  ),
  // Administrative: evidence folder management — uses users:read_detail.
  // Members access their OWN evidence via the profile screen, not this view.
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.evidence_folder',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    requiredPermissions: {'users:read_detail'},
  ),
  // Administrative: financial records — finances:read is held by treasurer+
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.finances',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    requiredPermissions: {'finances:read'},
  ),
  // Administrative: unit management — units:update is held by counselor+
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.units',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    requiredPermissions: {'units:update'},
  ),
  // Administrative: group class management — classes:submit_progress is held by counselor+
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.grouped_class',
    icon: HugeIcons.strokeRoundedBookOpen01,
    color: AppColors.primary,
    route: RouteNames.homeGroupedClass,
    requiredPermissions: {'classes:submit_progress'},
  ),
  // Administrative: insurance management
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.insurance',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    requiredPermissions: {'insurance:read'},
  ),
  // Administrative: inventory management
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.inventory',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    requiredPermissions: {'inventory:read'},
  ),
  // Club-wide shared resources — folders:read is granted to every club role.
  _QuickAccessItemConfig(
    labelKey: 'dashboard.quick_access.resources',
    icon: HugeIcons.strokeRoundedFiles01,
    route: RouteNames.homeResources,
    requiredPermissions: {'folders:read'},
  ),
];

/// Grid 2xN de acceso rápido a los módulos principales del sistema.
///
/// Watches the full [AsyncValue] from [authNotifierProvider] to distinguish
/// three states:
///   - loading  → show skeleton placeholders (avoids the flip-flop where
///                 `valueOrNull == null` while the Future is still in flight)
///   - data with authorization → filter items by permissions and render grid
///   - data without authorization (genuinely empty) → SizedBox.shrink()
class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    // While the auth future is still resolving, show a placeholder that
    // occupies the same vertical space as the real grid would. This prevents
    // the layout from collapsing and then jumping when permissions arrive.
    if (authAsync.isLoading) {
      return const _QuickAccessSkeleton();
    }

    final user = authAsync.valueOrNull;
    final authorization = user?.authorization;

    // Auth has settled but there is no authorization data — either the user
    // has no assigned role or the response genuinely had none. Hide the grid.
    if (authorization == null) {
      return const SizedBox.shrink();
    }

    final filteredItems = _quickAccessItemsConfig.where((item) {
      // Ungated items (no permissions AND no roles) are visible to every
      // authenticated user — used only when authorization is not a concern.
      if (item.requiredPermissions.isEmpty && item.requiredRoles.isEmpty) {
        return true;
      }
      if (item.requiredPermissions.isNotEmpty &&
          hasAnyPermission(user, item.requiredPermissions)) {
        return true;
      }
      if (item.requiredRoles.isNotEmpty &&
          hasAnyRole(user, item.requiredRoles)) {
        return true;
      }
      return false;
    }).toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('dashboard.quick_access.title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          // shrinkWrap OK: filteredItems is permission-gated from a compile-time
          // constant list (max ~8 items). Lives inside SingleChildScrollView >
          // Column — intrinsic height is required.
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _QuickAccessTile(item: item);
          },
        ),
      ],
    );
  }
}

/// Skeleton placeholder shown while auth is resolving.
///
/// Renders 4 shimmer-like boxes in a 2x2 layout so the page height stays
/// stable and the grid doesn't cause a layout jump when it appears.
class _QuickAccessSkeleton extends StatelessWidget {
  const _QuickAccessSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shimmerColor = c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title placeholder
        Container(
          height: 16,
          width: 120,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          // shrinkWrap OK: skeleton with exactly 4 placeholder tiles.
          // Lives inside SingleChildScrollView > Column — intrinsic height
          // is required and item count is compile-time constant.
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final _QuickAccessItemConfig item;

  // Shared BorderRadius to avoid repeated allocations on every build.
  static final _kTileRadius = BorderRadius.circular(16);

  const _QuickAccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveColor = item.color ?? c.text;

    return Material(
      color: c.surface,
      borderRadius: _kTileRadius,
      child: InkWell(
        borderRadius: _kTileRadius,
        onTap: () => context.push(item.route),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: _kTileRadius,
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    size: 24,
                    color: effectiveColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(item.labelKey),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
