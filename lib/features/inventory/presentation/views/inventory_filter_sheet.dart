import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';

/// Bottom sheet de filtros y ordenamiento del inventario.
///
/// Contiene únicamente: orden y estado de conservación.
/// Las categorías se manejan ahora con los chips inline en la pantalla principal.
class InventoryFilterSheet extends ConsumerWidget {
  const InventoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(inventoryFiltersProvider);
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'inventory.filter_sheet.title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  SacPressable(
                    listenOnly: true,
                    child: SacButton.text(
                      text: 'inventory.filter_sheet.clear'.tr(),
                      color: SacAccent.of(context).dark,
                      onPressed: () {
                        // Only clear condition and sort — category managed by chips
                        ref.read(inventoryFiltersProvider.notifier).state =
                            filters.copyWith(
                          clearCondition: true,
                          sortOrder: InventorySortOrder.nameAsc,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sort ──────────────────────────────────────────────
                    _SectionTitle('inventory.filter_sheet.sort_by'.tr()),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: InventorySortOrder.values.map((order) {
                        final isSelected = filters.sortOrder == order;
                        return SacFilterChip(
                          label: order.label,
                          selected: isSelected,
                          variant: SacFilterChipVariant.quiet,
                          onTap: () {
                            ref.read(inventoryFiltersProvider.notifier).state =
                                filters.copyWith(sortOrder: order);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Condition ─────────────────────────────────────────
                    _SectionTitle(
                        'inventory.filter_sheet.condition_title'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SacFilterChip(
                          label: 'inventory.filter_sheet.condition_all'.tr(),
                          selected: filters.condition == null,
                          variant: SacFilterChipVariant.quiet,
                          onTap: () {
                            ref.read(inventoryFiltersProvider.notifier).state =
                                filters.copyWith(clearCondition: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        ...ItemCondition.values.map((cond) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SacFilterChip(
                                label: cond.shortLabel,
                                selected: filters.condition == cond,
                                variant: SacFilterChipVariant.quiet,
                                accentBackground: filters.condition == cond
                                    ? _conditionContainer(cond, context.sac)
                                    : null,
                                accentForeground: filters.condition == cond
                                    ? _conditionOnContainer(cond, context.sac)
                                    : null,
                                onTap: () {
                                  ref
                                      .read(inventoryFiltersProvider.notifier)
                                      .state = filters.copyWith(condition: cond);
                                },
                              ),
                            )),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Apply button
                    SacButton.primary(
                      text: 'inventory.filter_sheet.apply'.tr(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _conditionContainer(ItemCondition c, SacColors sac) {
    switch (c) {
      case ItemCondition.bueno:
        return sac.successContainer;
      case ItemCondition.regular:
        return sac.warningContainer;
      case ItemCondition.malo:
        return sac.errorContainer;
    }
  }

  Color _conditionOnContainer(ItemCondition c, SacColors sac) {
    switch (c) {
      case ItemCondition.bueno:
        return sac.onSuccessContainer;
      case ItemCondition.regular:
        return sac.onWarningContainer;
      case ItemCondition.malo:
        return sac.onErrorContainer;
    }
  }
}

// ── Section title ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.sac.textSecondary,
          ),
    );
  }
}
