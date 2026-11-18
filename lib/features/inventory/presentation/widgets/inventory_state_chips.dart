import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import 'condition_style.dart';

/// Todos / Bueno / Regular / Malo, each with its icon and how many items it
/// would show. Selecting the active one again goes back to "Todos".
class InventoryStateChips extends ConsumerWidget {
  const InventoryStateChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(inventoryFiltersProvider);
    final counts = ref.watch(inventoryConditionCountsProvider);
    final c = context.sac;

    // No items at all (not just a filter yielding none): nothing to filter.
    final allItems = ref.watch(inventoryItemsProvider).value;
    if (allItems != null && allItems.isEmpty) return const SizedBox.shrink();

    void select(ItemCondition? condition) {
      ref.read(inventoryFiltersProvider.notifier).state = condition == null
          ? filters.copyWith(clearCondition: true)
          : filters.copyWith(condition: condition);
    }

    return SizedBox(
      height: SacFilterChip.barHeight,
      // Four chips only: a plain scrollable row, no lazy list.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SacFilterChip(
              key: const ValueKey('inventory-chip-all'),
              label: 'inventory.filter_sheet.condition_all'.tr(),
              icon: HugeIcons.strokeRoundedGridView,
              count: counts.of(null),
              selected: filters.condition == null,
              variant: SacFilterChipVariant.quiet,
              onTap: () => select(null),
            ),
            for (final condition in ItemCondition.values) ...[
              const SizedBox(width: 8),
              SacFilterChip(
                key: ValueKey('inventory-chip-${condition.name}'),
                label: condition.shortLabel,
                icon: condition.icon,
                count: counts.of(condition),
                selected: filters.condition == condition,
                variant: SacFilterChipVariant.quiet,
                accentBackground: condition.container(c),
                accentForeground: condition.onContainer(c),
                onTap: () => select(
                  filters.condition == condition ? null : condition,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
