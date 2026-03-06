import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventario_providers.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_summary_header.dart';
import 'add_inventory_item_sheet.dart';
import 'inventory_filter_sheet.dart';
import 'inventory_item_detail_view.dart';

/// Pantalla principal del módulo de Inventario del club.
///
/// Muestra el resumen del inventario, una barra de búsqueda/filtros
/// y la lista de artículos. El FAB solo aparece para roles autorizados.
class InventarioView extends ConsumerStatefulWidget {
  const InventarioView({super.key});

  @override
  ConsumerState<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends ConsumerState<InventarioView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredInventoryItemsProvider);
    final canManageAsync = ref.watch(canManageInventoryProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final filters = ref.watch(inventoryFiltersProvider);

    final canManage = canManageAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton: canManage
          ? _AddFab(onTap: () => _openAddSheet(context))
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(inventoryItemsProvider);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // App bar
              SliverAppBar(
                pinned: true,
                expandedHeight: 0,
                backgroundColor: context.sac.background,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    onPressed: () => ref.invalidate(inventoryItemsProvider),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      size: 20,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ],
              ),

              // Body content
              SliverToBoxAdapter(
                child: filteredAsync.when(
                  loading: () => _LoadingBody(),
                  error: (e, _) => _ErrorBody(
                    message:
                        e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(inventoryItemsProvider),
                  ),
                  data: (items) => _InventoryBody(
                    items: items,
                    summary: summaryAsync,
                    filters: filters,
                    searchController: _searchController,
                    canManage: canManage,
                    onSearchChanged: (query) {
                      ref.read(inventoryFiltersProvider.notifier).state =
                          filters.copyWith(searchQuery: query);
                    },
                    onFilterTap: () => _openFilterSheet(context),
                    onItemTap: (item) => _openDetail(context, item),
                    onAddTap:
                        canManage ? () => _openAddSheet(context) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddInventoryItemSheet(),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InventoryFilterSheet(),
    );
  }

  void _openDetail(BuildContext context, InventoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryItemDetailView(item: item),
      ),
    );
  }
}

// ── Body principal ─────────────────────────────────────────────────────────────

class _InventoryBody extends StatelessWidget {
  final List<InventoryItem> items;
  final InventorySummary? summary;
  final InventoryFilters filters;
  final TextEditingController searchController;
  final bool canManage;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final ValueChanged<InventoryItem> onItemTap;
  final VoidCallback? onAddTap;

  const _InventoryBody({
    required this.items,
    required this.summary,
    required this.filters,
    required this.searchController,
    required this.canManage,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onItemTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        if (summary != null)
          InventorySummaryHeader(summary: summary!)
        else
          const SizedBox(height: 8),

        // Filter bar
        InventoryFilterBar(
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          onFilterTap: onFilterTap,
          hasActiveFilters: filters.hasActiveFilters,
        ),

        // Active filter chips
        if (filters.hasActiveFilters) _ActiveFiltersRow(filters: filters),

        const SizedBox(height: 8),

        // Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '${items.length} artículo${items.length != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),

        // List or empty state
        if (items.isEmpty)
          _EmptyState(canAdd: canManage && !filters.hasActiveFilters, onAddTap: onAddTap)
        else
          ...items.map((item) => InventoryItemCard(
                item: item,
                onTap: () => onItemTap(item),
              )),

        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }
}

// ── Active filters display ──────────────────────────────────────────────────────

class _ActiveFiltersRow extends ConsumerWidget {
  final InventoryFilters filters;

  const _ActiveFiltersRow({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];

    if (filters.condition != null) {
      chips.add(_FilterTag(
        label: filters.condition!.shortLabel,
        onRemove: () {
          ref.read(inventoryFiltersProvider.notifier).state =
              filters.copyWith(clearCondition: true);
        },
      ));
    }

    if (filters.categoryId != null) {
      chips.add(_FilterTag(
        label: 'Categoría: ${filters.categoryId}',
        onRemove: () {
          ref.read(inventoryFiltersProvider.notifier).state =
              filters.copyWith(clearCategory: true);
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }
}

class _FilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 14),
      backgroundColor: AppColors.primarySurface,
      deleteIconColor: AppColors.primaryDark,
      labelStyle: const TextStyle(color: AppColors.primaryDark),
      side: const BorderSide(color: AppColors.primary, width: 0.5),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Loading body ────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Skeleton header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          height: 140,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF183651), Color(0xFF2E5C82)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: SacLoading(color: Colors.white54)),
        ),
        const SizedBox(height: 160),
        const SacLoading(),
      ],
    );
  }
}

// ── Error body ──────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar el inventario',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 18,
              color: Colors.white,
            ),
            label: const Text('Reintentar'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool canAdd;
  final VoidCallback? onAddTap;

  const _EmptyState({required this.canAdd, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBoxingBag,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay artículos en el inventario',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            canAdd
                ? 'Registra el primer artículo usando el botón + o el botón de abajo.'
                : 'El inventario del club está vacío.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (canAdd && onAddTap != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Agregar primer artículo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── FAB ─────────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedAdd01,
        size: 20,
        color: Colors.white,
      ),
      label: const Text(
        'Agregar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
