import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Grid 2×4 de acceso rápido a los módulos principales del sistema.
class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  static const List<_QuickAccessItem> _items = [
    _QuickAccessItem(
      label: 'Miembros',
      icon: HugeIcons.strokeRoundedUserGroup,
      color: AppColors.primary,
      route: RouteNames.homeMembers,
    ),
    _QuickAccessItem(
      label: 'Club',
      icon: HugeIcons.strokeRoundedBuilding01,
      color: AppColors.secondary,
      route: RouteNames.homeClub,
    ),
    _QuickAccessItem(
      label: 'Carpeta de Evidencias',
      icon: HugeIcons.strokeRoundedFolder01,
      color: AppColors.accent,
      route: RouteNames.homeEvidences,
    ),
    _QuickAccessItem(
      label: 'Finanzas',
      icon: HugeIcons.strokeRoundedCreditCard,
      color: AppColors.info,
      route: RouteNames.homeFinances,
    ),
    _QuickAccessItem(
      label: 'Unidades',
      icon: HugeIcons.strokeRoundedCompass01,
      color: AppColors.secondary,
      route: RouteNames.homeUnits,
    ),
    _QuickAccessItem(
      label: 'Clase Agrupada',
      icon: HugeIcons.strokeRoundedBookOpen01,
      color: AppColors.primary,
      route: RouteNames.homeGroupedClass,
    ),
    _QuickAccessItem(
      label: 'Seguros del Club',
      icon: HugeIcons.strokeRoundedShield01,
      color: AppColors.secondaryDark,
      route: RouteNames.homeInsurance,
    ),
    _QuickAccessItem(
      label: 'Inventario',
      icon: HugeIcons.strokeRoundedPackage,
      color: AppColors.accent,
      route: RouteNames.homeInventory,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _QuickAccessTile(item: item);
          },
        ),
      ],
    );
  }
}

class _QuickAccessItem {
  final String label;
  // HugeIcon path data — internal format used by package:hugeicons
  final List<List<dynamic>> icon;
  final Color color;
  final String route;

  const _QuickAccessItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _QuickAccessTile extends StatelessWidget {
  final _QuickAccessItem item;

  // Shared BorderRadius to avoid repeated allocations on every build.
  static final _kTileRadius = BorderRadius.circular(16);

  const _QuickAccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Material(
      color: c.surface,
      borderRadius: _kTileRadius,
      child: InkWell(
        borderRadius: _kTileRadius,
        onTap: () => context.go(item.route),
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
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: item.icon,
                  size: 24,
                  color: item.color,
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
