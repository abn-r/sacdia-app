import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Opciones de filtro de tipo de recurso
class ResourceTypeFilter {
  final String? value; // null = "Todos"
  final String label;
  final List<List<dynamic>> icon;

  const ResourceTypeFilter({
    required this.value,
    required this.label,
    required this.icon,
  });
}

List<ResourceTypeFilter> get _filters => <ResourceTypeFilter>[
  ResourceTypeFilter(
    value: null,
    label: 'resources.filter.all'.tr(),
    icon: HugeIcons.strokeRoundedGridView,
  ),
  ResourceTypeFilter(
    value: 'document',
    label: 'resources.filter.document'.tr(),
    icon: HugeIcons.strokeRoundedFile01,
  ),
  ResourceTypeFilter(
    value: 'audio',
    label: 'resources.filter.audio'.tr(),
    icon: HugeIcons.strokeRoundedHeadphones,
  ),
  ResourceTypeFilter(
    value: 'image',
    label: 'resources.filter.image'.tr(),
    icon: HugeIcons.strokeRoundedImage01,
  ),
  ResourceTypeFilter(
    value: 'video_link',
    label: 'resources.filter.video'.tr(),
    icon: HugeIcons.strokeRoundedPlayCircle,
  ),
  ResourceTypeFilter(
    value: 'text',
    label: 'resources.filter.text'.tr(),
    icon: HugeIcons.strokeRoundedTextWrap,
  ),
];

/// Barra horizontal de chips para filtrar recursos por tipo
class ResourceFilterBar extends StatelessWidget {
  final String? activeType;
  final ValueChanged<String?> onTypeChanged;

  const ResourceFilterBar({
    super.key,
    required this.activeType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: _filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  filter: filter,
                  isActive: activeType == filter.value,
                  onTap: () => onTypeChanged(filter.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final ResourceTypeFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : c.surface,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isActive ? AppColors.primary : c.border,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: filter.icon,
              size: 15,
              color: isActive ? Colors.white : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
