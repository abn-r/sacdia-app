import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_summary_header.dart';
import 'add_inventory_item_sheet.dart';
import 'inventory_filter_sheet.dart';
import 'inventory_item_detail_view.dart';

/// Pantalla principal del módulo de Inventario del club.
///
/// Muestra stats compactas, búsqueda, chips de categoría inline y la lista
/// de artículos con SliverList.builder (no spread en Column). El FAB solo
/// aparece para roles autorizados.
class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key});

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
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
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 0,
                backgroundColor: context.sac.background,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'inventory.view.title'.tr(),
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

              // ── Stats row ────────────────────────────────────────────────
              if (summaryAsync != null)
                SliverToBoxAdapter(
                  child: InventoryStatsRow(summary: summaryAsync),
                ),

              // ── Search + filter button ───────────────────────────────────
              SliverToBoxAdapter(
                child: InventoryFilterBar(
                  searchController: _searchController,
                  onSearchChanged: (query) {
                    ref.read(inventoryFiltersProvider.notifier).state =
                        filters.copyWith(searchQuery: query);
                  },
                  onFilterTap: () => _openFilterSheet(context),
                  hasActiveFilters: filters.hasActiveFilters,
                ),
              ),

              // ── Category chips (inline) ──────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: InventoryCategoryChips(),
                ),
              ),

              // ── Active filter tags (condition / search) ──────────────────
              SliverToBoxAdapter(
                child: _ActiveFiltersRow(filters: filters),
              ),

              // ── Body (loading / error / list) ────────────────────────────
              filteredAsync.when(
                loading: () => const SliverToBoxAdapter(child: _SkeletonBody()),
                error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorBody(
                    message: e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(inventoryItemsProvider),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(
                        canAdd: canManage && !filters.hasActiveFilters,
                        onAddTap: canManage
                            ? () => _openAddSheet(context)
                            : null,
                      ),
                    );
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      // Item count label
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                          child: Text(
                            'inventory.view.item_count'
                                .plural(items.length),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: context.sac.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),

                      // Item list — SliverList.builder instead of Column spread
                      SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return StaggeredListItem(
                            index: index,
                            child: InventoryItemCard(
                              item: item,
                              onTap: () => _openDetail(context, item),
                              onEdit: canManage
                                  ? () => _openEdit(context, item)
                                  : null,
                              onDelete: canManage
                                  ? () => _confirmDelete(context, item)
                                  : null,
                            ),
                          );
                        },
                      ),

                      // FAB clearance
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 88),
                      ),
                    ],
                  );
                },
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

  void _openEdit(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddInventoryItemSheet(existing: item),
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
      SacSharedAxisRoute(
        builder: (_) => InventoryItemDetailView(item: item),
      ),
    );
  }

  void _confirmDelete(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.detail.delete_title'.tr()),
        content: Text('inventory.detail.delete_confirm'.tr(
            namedArgs: {'name': item.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          Consumer(
            builder: (consumerContext, ref, _) {
              final deleteState =
                  ref.watch(inventoryDeleteNotifierProvider);
              return FilledButton(
                onPressed: deleteState.isLoading
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final success = await ref
                            .read(inventoryDeleteNotifierProvider.notifier)
                            .deleteItem(item.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'inventory.detail.deleted_success'.tr()
                                    : 'inventory.detail.delete_error'.tr(),
                              ),
                              backgroundColor: success
                                  ? AppColors.secondary
                                  : AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: Text('common.delete'.tr()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Active filters row ──────────────────────────────────────────────────────────

class _ActiveFiltersRow extends ConsumerWidget {
  final InventoryFilters filters;

  const _ActiveFiltersRow({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show condition filter tag — category is now handled by chips
    if (filters.condition == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _FilterTag(
            label: 'inventory.view.filter_status'
                .tr(namedArgs: {'status': filters.condition!.shortLabel}),
            onRemove: () {
              ref.read(inventoryFiltersProvider.notifier).state =
                  filters.copyWith(clearCondition: true);
            },
          ),
        ],
      ),
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

// ── Skeleton loading body ───────────────────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skeleton stat chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _SkeletonBox(width: 110, height: 48, color: c.surfaceVariant),
              const SizedBox(width: 8),
              _SkeletonBox(width: 110, height: 48, color: c.surfaceVariant),
              const SizedBox(width: 8),
              _SkeletonBox(width: 120, height: 48, color: c.surfaceVariant),
            ],
          ),
        ),
        // Skeleton cards
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  _SkeletonBox(width: 60, height: 60, color: c.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                            width: double.infinity,
                            height: 14,
                            color: c.border),
                        const SizedBox(height: 8),
                        _SkeletonBox(width: 120, height: 10, color: c.border),
                        const SizedBox(height: 6),
                        _SkeletonBox(width: 80, height: 10, color: c.border),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 36,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'inventory.view.error_load'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.sac.text,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 18,
              color: Colors.white,
            ),
            label: Text('common.retry'.tr()),
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
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          // Composed icon illustration
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
              ),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedBoxingBag,
                size: 48,
                color: AppColors.primary,
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'inventory.view.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            canAdd
                ? 'inventory.view.empty_subtitle_can_add'.tr()
                : 'inventory.view.empty_subtitle_cannot_add'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),

          if (canAdd && onAddTap != null) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddTap,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'inventory.view.add_first_item'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
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
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedAdd01,
        size: 20,
        color: Colors.white,
      ),
      label: Text(
        'inventory.view.add_button'.tr(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
