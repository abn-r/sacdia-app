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
  final String label;
  final List<List<dynamic>> icon;
  final Color? color;
  final String route;
  final Set<String> requiredPermissions;
  final Set<String> legacyRoles;

  const _QuickAccessItemConfig({
    required this.label,
    required this.icon,
    this.color,
    required this.route,
    this.requiredPermissions = const {},
    this.legacyRoles = const {},
  });
}

const List<_QuickAccessItemConfig> _quickAccessItemsConfig = [
  // Coordination hub — requires coordinator or admin GLOBAL role only.
  // investiture:validate is intentionally excluded from requiredPermissions
  // because club directors also hold that permission; the gate must be
  // role-based (global grant), not permission-based.
  _QuickAccessItemConfig(
    label: 'Coordinación',
    icon: HugeIcons.strokeRoundedAnalytics01,
    color: AppColors.info,
    route: RouteNames.coordinator,
    requiredPermissions: const {},
    legacyRoles: {'coordinator', 'admin', 'super_admin', 'assistant_admin'},
  ),
  // Administrative: member list — requires users:read_detail (counselor and above)
  _QuickAccessItemConfig(
    label: 'Miembros',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: AppColors.primary,
    route: RouteNames.homeMembers,
    requiredPermissions: {'users:read_detail'},
    legacyRoles: {'director', 'subdirector', 'secretario', 'consejero'},
  ),
  // Administrative: club management — requires clubs:update (secretary and above)
  _QuickAccessItemConfig(
    label: 'Club',
    icon: HugeIcons.strokeRoundedBuilding01,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    requiredPermissions: {'clubs:update'},
    legacyRoles: {'director', 'subdirector', 'secretario'},
  ),
  // Administrative: evidence folder management — requires users:read_detail (counselor+)
  // Members access their own evidence via the profile screen, not this admin view.
  _QuickAccessItemConfig(
    label: 'Carpeta de Evidencias',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    requiredPermissions: {'users:read_detail'},
  ),
  // Administrative: financial records — requires finances:read (treasurer and above)
  _QuickAccessItemConfig(
    label: 'Finanzas',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    requiredPermissions: {'finances:read'},
    legacyRoles: {'director', 'tesorero'},
  ),
  // Administrative: unit management — requires units:update (counselor and above)
  // Members can read their own unit info but cannot manage units.
  _QuickAccessItemConfig(
    label: 'Unidades',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    requiredPermissions: {'units:update'},
    legacyRoles: {'director', 'subdirector', 'consejero'},
  ),
  // Administrative: group class management — requires classes:update (counselor and above)
  // Members track their own class progress via their profile, not this group view.
  _QuickAccessItemConfig(
    label: 'Clase Agrupada',
    icon: HugeIcons.strokeRoundedBookOpen01,
    color: AppColors.primary,
    route: RouteNames.homeGroupedClass,
    requiredPermissions: {'classes:update'},
    legacyRoles: {'conquistador', 'aventurero', 'guia_mayor'},
  ),
  // Administrative: insurance management — requires insurance:read (counselor and above)
  _QuickAccessItemConfig(
    label: 'Seguros del Club',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    requiredPermissions: {'insurance:read'},
    legacyRoles: {'director', 'subdirector', 'secretario'},
  ),
  // Administrative: inventory management — requires inventory:read (secretary and above)
  _QuickAccessItemConfig(
    label: 'Inventario',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    requiredPermissions: {'inventory:read'},
    legacyRoles: {'director', 'subdirector'},
  ),
  // Club-wide shared resources (manuals, formats, images, music) — all members can access.
  // Uses folders:read which is granted to every club role including member.
  _QuickAccessItemConfig(
    label: 'Recursos',
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
      // An item is ungated only when neither permissions nor legacy roles are
      // configured — i.e. it is visible to every authenticated user.
      if (item.requiredPermissions.isEmpty && item.legacyRoles.isEmpty) {
        return true;
      }
      return canByPermissionOrLegacyRole(
        user,
        requiredPermissions: item.requiredPermissions,
        legacyRoles: item.legacyRoles,
      );
    }).toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acceso rápido',
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
                item.label,
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
