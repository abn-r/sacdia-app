import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../providers/inventory_providers.dart';

/// Filter and sort sheet.
///
/// "Ordenar por" is a single choice, "Categoría" is a set of checkboxes with
/// counts. The condition is NOT here: it lives in the list chips, so it is
/// never in two places. Everything applies live and the button says how many
/// items remain, so there is no separate "Aplicar".
class InventoryFilterSheet extends ConsumerWidget {
  const InventoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(inventoryFiltersProvider);
    final options = ref.watch(inventoryCategoryOptionsProvider);
    final remaining =
        ref.watch(filteredInventoryItemsProvider).value?.length ?? 0;
    final notifier = ref.read(inventoryFiltersProvider.notifier);
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(
              title: 'inventory.filter_sheet.title'.tr(),
              actions: [
                SacPressable(
                  listenOnly: true,
                  child: SacButton.text(
                    key: const ValueKey('inventory-filter-clear'),
                    text: 'inventory.filter_sheet.clear'.tr(),
                    color: SacAccent.of(context).dark,
                    onPressed: filters.sheetFilterCount == 0
                        ? null
                        : () => notifier.state = filters.copyWith(
                              clearCategories: true,
                              sortOrder: InventorySortOrder.nameAsc,
                            ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow('inventory.filter_sheet.sort_by'.tr()),
                    _Group(
                      children: [
                        for (final order in InventorySortOrder.values)
                          _ChoiceRow(
                            key: ValueKey('inventory-sort-${order.name}'),
                            label: order.label,
                            isRadio: true,
                            selected: filters.sortOrder == order,
                            onTap: () => notifier.state =
                                filters.copyWith(sortOrder: order),
                          ),
                      ],
                    ),
                    if (options.isNotEmpty) ...[
                      _Eyebrow('inventory.filter_sheet.category_title'.tr()),
                      _Group(
                        children: [
                          for (final option in options)
                            _ChoiceRow(
                              key: ValueKey(
                                'inventory-category-${option.category.id}',
                              ),
                              label: option.category.name,
                              count: option.count,
                              selected: filters.categoryIds
                                  .contains(option.category.id),
                              onTap: () {
                                final next = {...filters.categoryIds};
                                if (!next.remove(option.category.id)) {
                                  next.add(option.category.id);
                                }
                                notifier.state =
                                    filters.copyWith(categoryIds: next);
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SacButton.primary(
                key: const ValueKey('inventory-filter-show'),
                text: 'inventory.filter_sheet.show_items'
                    .plural(remaining, name: 'count'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.sac.textTertiary,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: radio (single choice) or checkbox (several), with an optional
/// count at the end.
class _ChoiceRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isRadio;
  final int? count;
  final VoidCallback onTap;

  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isRadio = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final shape = isRadio ? BoxShape.circle : BoxShape.rectangle;

    return Semantics(
      inMutuallyExclusiveGroup: isRadio,
      checked: selected,
      button: true,
      label: count == null ? label : '$label $count',
      excludeSemantics: true,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: shape,
                    borderRadius: isRadio
                        ? null
                        : BorderRadius.circular(AppTheme.radiusXS),
                    color: selected && !isRadio ? accent.color : null,
                    border: Border.all(
                      color: selected ? accent.color : c.border,
                      width: selected && isRadio ? 6 : 1.5,
                    ),
                  ),
                  child: selected && !isRadio
                      ? Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedTick02,
                            size: 14,
                            color: accent.onColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w600,
                      color: c.textTertiary,
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
