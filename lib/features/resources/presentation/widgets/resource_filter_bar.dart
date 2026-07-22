import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Opciones de filtro de tipo de recurso.
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

/// Barra horizontal de chips para filtrar recursos por tipo.
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
      padding: const EdgeInsets.only(right: 20),
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

class _FilterChip extends StatefulWidget {
  final ResourceTypeFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final radius = BorderRadius.circular(AppTheme.radiusFull);
    final reduce = SacMotion.reduceMotionOf(context);

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: widget.filter.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.97 : 1,
          duration: SacMotion.press,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive ? AppColors.primary : c.surface,
              borderRadius: radius,
              border: Border.all(
                color: widget.isActive ? AppColors.primary : c.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: widget.filter.icon,
                  size: 15,
                  color: widget.isActive ? Colors.white : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.filter.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isActive ? Colors.white : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
