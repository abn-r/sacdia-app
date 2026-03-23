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
  _QuickAccessItemConfig(
    label: 'Miembros',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: AppColors.primary,
    route: RouteNames.homeMembers,
    requiredPermissions: {'clubs:read'},
    legacyRoles: {'director', 'subdirector', 'secretario', 'consejero'},
  ),
  _QuickAccessItemConfig(
    label: 'Club',
    icon: HugeIcons.strokeRoundedBuilding01,
    color: AppColors.secondary,
    route: RouteNames.homeClub,
    requiredPermissions: {'clubs:read'},
    legacyRoles: {'director', 'subdirector', 'secretario'},
  ),
  _QuickAccessItemConfig(
    label: 'Carpeta de Evidencias',
    icon: HugeIcons.strokeRoundedFolder01,
    color: AppColors.accent,
    route: RouteNames.homeEvidences,
    requiredPermissions: {'users:read_detail'},
  ),
  _QuickAccessItemConfig(
    label: 'Finanzas',
    icon: HugeIcons.strokeRoundedCreditCard,
    color: AppColors.info,
    route: RouteNames.homeFinances,
    requiredPermissions: {'finances:read'},
    legacyRoles: {'director', 'tesorero'},
  ),
  _QuickAccessItemConfig(
    label: 'Unidades',
    icon: HugeIcons.strokeRoundedCompass01,
    color: AppColors.secondary,
    route: RouteNames.homeUnits,
    requiredPermissions: {'units:read'},
    legacyRoles: {'director', 'subdirector', 'consejero'},
  ),
  _QuickAccessItemConfig(
    label: 'Clase Agrupada',
    icon: HugeIcons.strokeRoundedBookOpen01,
    color: AppColors.primary,
    route: RouteNames.homeGroupedClass,
    requiredPermissions: {'classes:read'},
    legacyRoles: {'conquistador', 'aventurero', 'guia_mayor'},
  ),
  _QuickAccessItemConfig(
    label: 'Seguros del Club',
    icon: HugeIcons.strokeRoundedShield01,
    color: AppColors.secondaryDark,
    route: RouteNames.homeInsurance,
    requiredPermissions: {'clubs:read'},
    legacyRoles: {'director', 'subdirector', 'secretario'},
  ),
  _QuickAccessItemConfig(
    label: 'Inventario',
    icon: HugeIcons.strokeRoundedPackage,
    color: AppColors.accent,
    route: RouteNames.homeInventory,
    requiredPermissions: {'inventory:read'},
    legacyRoles: {'director', 'subdirector'},
  ),
  _QuickAccessItemConfig(
    label: 'Recursos',
    icon: HugeIcons.strokeRoundedFiles01,
    route: RouteNames.homeResources,
  ),
];

/// Grid 2xN de acceso rápido a los módulos principales del sistema.
///
/// Watches [authNotifierProvider] scoped to the authorization sub-state so
/// the grid rebuilds reactively when permissions change (e.g. context switch).
class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final authorization = user?.authorization;

    final List<_QuickAccessItemConfig> filteredItems;
    if (authorization == null) {
      filteredItems = const [];
    } else {
      filteredItems = _quickAccessItemsConfig.where((item) {
        if (item.requiredPermissions.isEmpty) return true;
        return canByPermissionOrLegacyRole(
          user,
          requiredPermissions: item.requiredPermissions,
          legacyRoles: item.legacyRoles,
        );
      }).toList();
    }

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
                child: HugeIcon(
                  icon: item.icon,
                  size: 24,
                  color: effectiveColor,
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
