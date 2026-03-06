import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../providers/inventario_providers.dart';

/// Header con resumen estadístico del inventario.
///
/// Sigue el design system "Scout Vibrante":
/// fondo de surface con borde sutil, icono en contenedor de acento,
/// sin gradientes, tokens de color semánticos via `context.sac`.
class InventorySummaryHeader extends StatelessWidget {
  final InventorySummary summary;

  const InventorySummaryHeader({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: c.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              // Icon container — standard app pattern
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPackageAdd,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Title
              Text(
                'Resumen del Inventario',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _StatChip(
                label: 'Total',
                value: summary.totalItems.toString(),
                icon: HugeIcons.strokeRoundedPackage,
                color: c.text,
                subtitleColor: c.textSecondary,
                backgroundColor: c.surfaceVariant,
                borderColor: c.border,
              ),
              const SizedBox(width: 10),
              if (summary.totalValue > 0)
                _StatChip(
                  label: 'Valor est.',
                  value: '\$${_formatValue(summary.totalValue)}',
                  icon: HugeIcons.strokeRoundedMoney01,
                  color: AppColors.accent,
                  subtitleColor: AppColors.accentDark,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.10),
                  borderColor: AppColors.accent.withValues(alpha: 0.30),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Condition breakdown
          Row(
            children: [
              _ConditionPill(
                label: 'Bueno',
                count: summary.buenoCount,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _ConditionPill(
                label: 'Regular',
                count: summary.regularCount,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              _ConditionPill(
                label: 'Malo',
                count: summary.maloCount,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final List<List<dynamic>> icon;
  final Color color;
  final Color subtitleColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitleColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ConditionPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de barra de filtros para el listado de inventario.
class InventoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;

  const InventoryFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar artículos...',
                hintStyle:
                    TextStyle(color: context.sac.textTertiary, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 18,
                    color: context.sac.textTertiary,
                  ),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 16,
                          color: context.sac.textTertiary,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: context.sac.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.sac.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(
            onTap: onFilterTap,
            hasActiveFilters: hasActiveFilters,
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilters;

  const _FilterButton({required this.onTap, required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? AppColors.primarySurface
              : context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilters ? AppColors.primary : context.sac.border,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFilter,
                size: 20,
                color: hasActiveFilters
                    ? AppColors.primary
                    : context.sac.textSecondary,
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
