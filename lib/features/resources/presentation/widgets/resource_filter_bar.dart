import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';

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
                child: SacFilterChip(
                  label: filter.label,
                  selected: activeType == filter.value,
                  icon: filter.icon,
                  onTap: () => onTypeChanged(filter.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
