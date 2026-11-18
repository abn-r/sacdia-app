import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/sac_grouped_section.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_active_pills.dart';
import '../widgets/inventory_filter_bar.dart';
import '../widgets/inventory_footer.dart';
import '../widgets/inventory_item_actions.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_list_skeleton.dart';
import '../widgets/inventory_state_chips.dart';
import 'add_inventory_item_sheet.dart';
import 'inventory_filter_sheet.dart';
import 'inventory_item_detail_view.dart';

/// Main screen of the club inventory.
///
/// Top bar with the title only. Search + filter button, state chips with
/// counts, removable pills for the sheet filters, and the items grouped by
/// category. The one primary action ("Agregar artículo") sits in a fixed
/// frosted footer for roles that can manage the inventory.
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
    final allAsync = ref.watch(inventoryItemsProvider);
    final canManage = ref.watch(canManageInventoryProvider).value ?? false;
    final filters = ref.watch(inventoryFiltersProvider);

    // With no items at all the empty state carries the action; a second
    // button in the footer would say the same thing twice.
    final isInventoryEmpty = allAsync.hasValue && allAsync.requireValue.isEmpty;
    final showFooter = canManage && !isInventoryEmpty;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'inventory.view.title'.tr(),
        frosted: true,
      ),
      bottomNavigationBar: showFooter
          ? InventoryFooter(
              child: SacButton.primary(
                key: const ValueKey('inventory-add-button'),
                text: 'inventory.view.add_item'.tr(),
                icon: HugeIcons.strokeRoundedAdd01,
                onPressed: _openAddSheet,
              ),
            )
          : null,
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => RefreshIndicator(
            color: SacAccent.of(context).color,
            edgeOffset: SacTopBar.frostedInset(context),
            onRefresh: () async => ref.invalidate(inventoryItemsProvider),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: SacTopBar.frostedInset(context)),
                ),
                SliverToBoxAdapter(
                  child: InventoryFilterBar(
                    searchController: _searchController,
                    onSearchChanged: (query) {
                      ref.read(inventoryFiltersProvider.notifier).state =
                          filters.copyWith(searchQuery: query);
                    },
                    onFilterTap: _openFilterSheet,
                    activeCount: filters.sheetFilterCount,
                  ),
                ),
                const SliverToBoxAdapter(child: InventoryActivePills()),
                const SliverToBoxAdapter(child: InventoryStateChips()),
                ..._body(context, filteredAsync, filters, canManage),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: showFooter ? InventoryFooter.height : 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AsyncValue<List<InventoryItem>> async,
    InventoryFilters filters,
    bool canManage,
  ) {
    return async.when(
      loading: () => const [
        SliverToBoxAdapter(child: InventoryListSkeleton()),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: SacErrorState(
            title: 'inventory.view.error_load'.tr(),
            message: userErrorMessage(e),
            onRetry: () => ref.invalidate(inventoryItemsProvider),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [SliverToBoxAdapter(child: _emptyState(filters, canManage))];
        }

        final groups = _groupByCategory(items);
        return [
          SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return SacGroupedSection(
                key: ValueKey('inventory-group-${group.key}'),
                label: group.name,
                dividerIndent: 72,
                children: [
                  for (final item in group.items)
                    InventoryItemCard(
                      key: ValueKey('inventory-item-${item.id}'),
                      item: item,
                      onTap: () => _openDetail(item),
                      onMore: canManage ? () => _openActions(item) : null,
                    ),
                ],
              );
            },
          ),
        ];
      },
    );
  }

  Widget _emptyState(InventoryFilters filters, bool canManage) {
    if (filters.hasActiveFilters) {
      return SacEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        title: 'inventory.view.no_results_title'.tr(),
        body: 'inventory.view.no_results_subtitle'.tr(),
      );
    }
    return SacEmptyState(
      icon: HugeIcons.strokeRoundedPackage,
      title: 'inventory.view.empty_title'.tr(),
      body: canManage
          ? 'inventory.view.empty_subtitle_can_add'.tr()
          : 'inventory.view.empty_subtitle_cannot_add'.tr(),
      actionLabel: canManage ? 'inventory.view.add_first_item'.tr() : null,
      onAction: canManage ? _openAddSheet : null,
    );
  }

  void _openAddSheet() => showInventoryItemForm(context);

  void _openFilterSheet() {
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InventoryFilterSheet(),
    );
  }

  void _openDetail(InventoryItem item) {
    Navigator.push(
      context,
      SacSharedAxisRoute(builder: (_) => InventoryItemDetailView(item: item)),
    );
  }

  Future<void> _openActions(InventoryItem item) async {
    final action = await showInventoryItemActionsSheet(
      context,
      item: item,
      canManage: true,
    );
    if (action == null || !mounted) return;
    await runInventoryItemAction(
      context,
      ref,
      item: item,
      action: action,
      onView: () => _openDetail(item),
    );
  }
}

/// Items grouped by category. Groups go A-Z by category name; inside a group
/// the items keep the order the active sort gave them.
List<_CategoryGroup> _groupByCategory(List<InventoryItem> items) {
  final byId = <int, _CategoryGroup>{};
  for (final item in items) {
    byId
        .putIfAbsent(
          item.category.id,
          () => _CategoryGroup(item.category.id, item.category.name),
        )
        .items
        .add(item);
  }
  return byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

class _CategoryGroup {
  final int key;
  final String name;
  final List<InventoryItem> items = [];

  _CategoryGroup(this.key, this.name);
}
