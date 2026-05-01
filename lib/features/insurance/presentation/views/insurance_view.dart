import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/member_insurance.dart';
import '../providers/insurance_providers.dart';
import '../widgets/insurance_loading_skeleton.dart';
import '../widgets/insurance_summary_header.dart';
import '../widgets/member_insurance_card.dart';
import 'insurance_detail_view.dart';
import 'insurance_form_sheet.dart';

/// Pantalla principal del módulo de Seguros del club.
///
/// Muestra el resumen de cobertura y la lista de todos los miembros
/// con su estado de seguro (asegurado, vencido, sin seguro).
class InsuranceView extends ConsumerStatefulWidget {
  const InsuranceView({super.key});

  @override
  ConsumerState<InsuranceView> createState() => _InsuranceViewState();
}

class _InsuranceViewState extends ConsumerState<InsuranceView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredMembersInsuranceProvider);
    final canManageAsync = ref.watch(canManageInsuranceProvider);
    final summaryAsync = ref.watch(insuranceSummaryProvider);
    final filters = ref.watch(insuranceFiltersProvider);

    final canManage = canManageAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton: canManage
          ? _AddFab(onTap: () => _openAddSheet(context, null))
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(membersInsuranceProvider);
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
                  'insurance.view.title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    onPressed: () =>
                        ref.invalidate(membersInsuranceProvider),
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
                    message: e
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    onRetry: () =>
                        ref.invalidate(membersInsuranceProvider),
                  ),
                  data: (items) => _InsuranceBody(
                    items: items,
                    summary: summaryAsync,
                    filters: filters,
                    searchController: _searchController,
                    canManage: canManage,
                    onSearchChanged: (query) {
                      ref.read(insuranceFiltersProvider.notifier).state =
                          filters.copyWith(searchQuery: query);
                    },
                    onStatusFilterChanged: (sf) {
                      ref.read(insuranceFiltersProvider.notifier).state =
                          filters.copyWith(statusFilter: sf);
                    },
                    onSortChanged: (so) {
                      ref.read(insuranceFiltersProvider.notifier).state =
                          filters.copyWith(sortOrder: so);
                    },
                    onItemTap: (mi) => _onMemberTap(context, mi, canManage),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMemberTap(
      BuildContext context, MemberInsurance mi, bool canManage) {
    if (mi.status == InsuranceStatus.sinSeguro) {
      // Sin seguro: directamente abre el formulario (solo para gestores)
      if (canManage) {
        _openAddSheet(context, mi.memberId);
      }
    } else {
      // Asegurado o vencido: abre el detalle
      Navigator.push(
        context,
        SacSharedAxisRoute(
          builder: (_) => InsuranceDetailView(insurance: mi),
        ),
      );
    }
  }

  void _openAddSheet(BuildContext context, String? preselectedMemberId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InsuranceFormSheet(
        preselectedMemberId: preselectedMemberId,
      ),
    );
  }
}

// ── Main body ──────────────────────────────────────────────────────────────────

class _InsuranceBody extends ConsumerWidget {
  final List<MemberInsurance> items;
  final InsuranceSummary? summary;
  final InsuranceFilters filters;
  final TextEditingController searchController;
  final bool canManage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InsuranceStatusFilter> onStatusFilterChanged;
  final ValueChanged<InsuranceSortOrder> onSortChanged;
  final ValueChanged<MemberInsurance> onItemTap;

  const _InsuranceBody({
    required this.items,
    required this.summary,
    required this.filters,
    required this.searchController,
    required this.canManage,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onSortChanged,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringAsync = ref.watch(expiringInsuranceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        if (summary != null)
          InsuranceSummaryHeader(summary: summary!)
        else
          const SizedBox(height: 8),

        // Expiring insurance alert banner
        expiringAsync.whenOrNull(
          data: (expiring) => expiring.isNotEmpty
              ? _ExpiringBanner(count: expiring.length)
              : null,
        ) ?? const SizedBox.shrink(),

        // Search bar
        _SearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
        ),

        // Status filter chips
        _StatusFilterBar(
          current: filters.statusFilter,
          onChanged: onStatusFilterChanged,
        ),

        // Sort + count row
        _SortCountRow(
          count: items.length,
          sortOrder: filters.sortOrder,
          onSortChanged: onSortChanged,
        ),

        const SizedBox(height: 4),

        // List or empty state
        if (items.isEmpty)
          _EmptyState(
            hasFilters: filters.hasActiveFilters,
            canManage: canManage,
          )
        else
          ...items.asMap().entries.map((entry) => StaggeredListItem(
                index: entry.key,
                child: MemberInsuranceCard(
                  insurance: entry.value,
                  canManage: canManage,
                  onTap: () => onItemTap(entry.value),
                ),
              )),

        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }
}

// ── Expiring banner ────────────────────────────────────────────────────────────

/// Banner de alerta que se muestra cuando hay seguros por vencer en los
/// próximos 30 días. Solo visible cuando el backend devuelve al menos uno.
class _ExpiringBanner extends StatelessWidget {
  final int count;

  const _ExpiringBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final key = count == 1
        ? 'insurance.view.expiring_banner_one'
        : 'insurance.view.expiring_banner_other';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCA28).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 20,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              key.tr(namedArgs: {'count': '$count'}),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'insurance.view.search_hint'.tr(),
          hintStyle: TextStyle(
              color: context.sac.textTertiary, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 18,
              color: context.sac.textTertiary,
            ),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 16,
                    color: context.sac.textTertiary,
                  ),
                )
              : null,
          filled: true,
          fillColor: context.sac.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.sac.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

// ── Status filter chips ────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final InsuranceStatusFilter current;
  final ValueChanged<InsuranceStatusFilter> onChanged;

  const _StatusFilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: InsuranceStatusFilter.values.map((sf) {
          final isSelected = sf == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                sf.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(sf),
              selectedColor: AppColors.primarySurface,
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).dividerColor,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Sort + count row ───────────────────────────────────────────────────────────

class _SortCountRow extends StatelessWidget {
  final int count;
  final InsuranceSortOrder sortOrder;
  final ValueChanged<InsuranceSortOrder> onSortChanged;

  const _SortCountRow({
    required this.count,
    required this.sortOrder,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final key = count == 1
        ? 'insurance.view.member_count_one'
        : 'insurance.view.member_count_other';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            key.tr(namedArgs: {'count': '$count'}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          // Sort dropdown
          GestureDetector(
            onTap: () => _showSortMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedSortByUp01,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortOrder.label,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SortSheet(
        current: sortOrder,
        onSelected: onSortChanged,
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final InsuranceSortOrder current;
  final ValueChanged<InsuranceSortOrder> onSelected;

  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'insurance.view.sort_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...InsuranceSortOrder.values.map((so) {
            final isSelected = so == current;
            return ListTile(
              title: Text(
                so.label,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
              onTap: () {
                onSelected(so);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Loading body ──────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const InsuranceLoadingSkeleton();
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

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
            'insurance.view.error_title'.tr(),
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
            label: Text('common.retry'.tr()),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final bool canManage;

  const _EmptyState({required this.hasFilters, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedShield01,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'insurance.view.empty_filtered_title'.tr()
                : 'insurance.view.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'insurance.view.empty_filtered_subtitle'.tr()
                : canManage
                    ? 'insurance.view.empty_subtitle_manager'.tr()
                    : 'insurance.view.empty_subtitle_member'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

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
      label: Text(
        'insurance.view.fab_register'.tr(),
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
