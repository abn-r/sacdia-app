import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../providers/inventory_providers.dart';

/// Removable pills for the filters chosen in the sheet (categories and a
/// non-default order), plus "Limpiar". Renders nothing when there are none.
class InventoryActivePills extends ConsumerWidget {
  const InventoryActivePills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(inventoryFiltersProvider);
    if (filters.sheetFilterCount == 0) return const SizedBox.shrink();

    final options = ref.watch(inventoryCategoryOptionsProvider);
    final notifier = ref.read(inventoryFiltersProvider.notifier);
    final accent = SacAccent.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final option in options)
            if (filters.categoryIds.contains(option.category.id))
              _Pill(
                key: ValueKey('inventory-pill-category-${option.category.id}'),
                label: option.category.name,
                onRemove: () => notifier.state = filters.copyWith(
                  categoryIds: {...filters.categoryIds}
                    ..remove(option.category.id),
                ),
              ),
          if (filters.sortOrder != InventorySortOrder.nameAsc)
            _Pill(
              key: const ValueKey('inventory-pill-sort'),
              label: 'inventory.view.sort_pill'
                  .tr(namedArgs: {'order': filters.sortOrder.label}),
              onRemove: () => notifier.state =
                  filters.copyWith(sortOrder: InventorySortOrder.nameAsc),
            ),
          SacPressable(
            onTap: () => notifier.state = filters.copyWith(
              clearCategories: true,
              sortOrder: InventorySortOrder.nameAsc,
            ),
            semanticLabel: 'inventory.filter_sheet.clear'.tr(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'inventory.filter_sheet.clear'.tr(),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w700,
                    color: accent.dark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _Pill({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);

    return SacPressable(
      onTap: onRemove,
      semanticLabel: 'inventory.view.remove_filter'.tr(
        namedArgs: {'name': label},
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
            decoration: BoxDecoration(
              color: accent.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: accent.color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: accent.dark,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 14,
                  color: accent.dark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
