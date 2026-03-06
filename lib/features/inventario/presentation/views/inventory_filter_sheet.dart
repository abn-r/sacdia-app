import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventario_providers.dart';

/// Bottom sheet de filtros y ordenamiento del inventario.
class InventoryFilterSheet extends ConsumerWidget {
  const InventoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(inventoryFiltersProvider);
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.sac.background,
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
                  color: context.sac.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros y Ordenamiento',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(inventoryFiltersProvider.notifier).state =
                          const InventoryFilters();
                    },
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sort ──────────────────────────────────────────────
                    _SectionTitle('Ordenar por'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: InventorySortOrder.values.map((order) {
                        final isSelected = filters.sortOrder == order;
                        return FilterChip(
                          label: Text(order.label),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(inventoryFiltersProvider.notifier)
                                .state = filters.copyWith(sortOrder: order);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : null,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).dividerColor,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Condition ─────────────────────────────────────────
                    _SectionTitle('Estado de conservación'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ConditionChip(
                          label: 'Todos',
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
                        ...ItemCondition.values.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ConditionChip(
                                label: c.shortLabel,
                                isSelected: filters.condition == c,
                                color: _conditionColor(c),
                                onTap: () {
                                  ref
                                      .read(
                                          inventoryFiltersProvider.notifier)
                                      .state = filters.copyWith(condition: c);
                                },
                              ),
                            )),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Category ──────────────────────────────────────────
                    _SectionTitle('Categoría'),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text(
                          'No se pudieron cargar las categorías'),
                      data: (cats) => Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Todas'),
                            selected: filters.categoryId == null,
                            onSelected: (_) {
                              ref
                                  .read(inventoryFiltersProvider.notifier)
                                  .state = filters.copyWith(
                                      clearCategory: true);
                            },
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.primary,
                            side: BorderSide(
                              color: filters.categoryId == null
                                  ? AppColors.primary
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          ...cats.map((cat) {
                            final isSelected =
                                filters.categoryId == cat.id;
                            return FilterChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (_) {
                                ref
                                    .read(inventoryFiltersProvider.notifier)
                                    .state =
                                    filters.copyWith(categoryId: cat.id);
                              },
                              selectedColor: AppColors.primary
                                  .withValues(alpha: 0.15),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : null,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Theme.of(context).dividerColor,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Aplicar filtros',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  size: 14,
                  color: color,
                ),
              ),
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
