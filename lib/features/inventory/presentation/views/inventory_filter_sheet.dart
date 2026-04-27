import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  borderRadius: BorderRadius.circular(2),
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
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Only clear condition and sort — category managed by chips
                      ref.read(inventoryFiltersProvider.notifier).state =
                          filters.copyWith(
                        clearCondition: true,
                        sortOrder: InventorySortOrder.nameAsc,
                      );
                    },
                    child: Text(
                      'inventory.filter_sheet.clear'.tr(),
                      style: const TextStyle(color: AppColors.primary),
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
                        return _SortChip(
                          label: order.label,
                          isSelected: isSelected,
                          onTap: () {
                            ref
                                .read(inventoryFiltersProvider.notifier)
                                .state = filters.copyWith(sortOrder: order);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Condition ─────────────────────────────────────────
                    _SectionTitle('inventory.filter_sheet.condition_title'.tr()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ConditionChip(
                          label: 'inventory.filter_sheet.condition_all'.tr(),
                          isSelected: filters.condition == null,
                          color: AppColors.primary,
                          onTap: () {
                            ref
                                .read(inventoryFiltersProvider.notifier)
                                .state = filters.copyWith(
                                    clearCondition: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        ...ItemCondition.values.map((cond) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ConditionChip(
                                label: cond.shortLabel,
                                isSelected: filters.condition == cond,
                                color: _conditionColor(cond),
                                onTap: () {
                                  ref
                                      .read(inventoryFiltersProvider.notifier)
                                      .state =
                                      filters.copyWith(condition: cond);
                                },
                              ),
                            )),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                        ),
                        child: Text(
                          'inventory.filter_sheet.apply'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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

  Color _conditionColor(ItemCondition c) {
    switch (c) {
      case ItemCondition.bueno:
        return AppColors.secondary;
      case ItemCondition.regular:
        return AppColors.accent;
      case ItemCondition.malo:
        return AppColors.error;
    }
  }
}

// ── Sort chip ───────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : context.sac.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : context.sac.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Condition chip ──────────────────────────────────────────────────────────────

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
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
