import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/fixed_input_icon_slot.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../payment_orders/presentation/providers/payment_orders_providers.dart';
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
    final ordersContext = ref.watch(paymentOrdersContextProvider).valueOrNull;
    final ordersEnabled = ordersContext?.enabled ?? false;
    final canIssueOrders =
        ref.watch(canIssuePaymentOrdersProvider).valueOrNull ?? false;

    final showAdd = ordersEnabled ? canIssueOrders : canManage;

    return Scaffold(
      backgroundColor: context.sac.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(membersInsuranceProvider);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                leading: sacAutoBackButton(context),
                pinned: true,
                expandedHeight: 0,
                backgroundColor: context.sac.background.withValues(alpha: 0.92),
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0.5,
                title: Text(
                  'insurance.view.title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                        letterSpacing: -0.2,
                      ),
                ),
                centerTitle: false,
                actions: [
                  if (ordersEnabled)
                    IconButton(
                      tooltip: 'payment_orders.list.title'.tr(),
                      onPressed: () => context.push(
                        '${RouteNames.paymentOrders}?purpose=INSURANCE',
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedInvoice01,
                        color: context.sac.text,
                        size: 22,
                      ),
                    ),
                  if (showAdd)
                    IconButton(
                      tooltip: 'insurance.view.fab_register'.tr(),
                      onPressed: () {
                        if (ordersEnabled && canIssueOrders) {
                          context.push(RouteNames.paymentOrderIssueInsurance);
                          return;
                        }
                        _openAddSheet(context, null);
                      },
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: filteredAsync.when(
                  loading: () => const InsuranceLoadingSkeleton(),
                  error: (e, _) => _ErrorBody(
                    message: e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(membersInsuranceProvider),
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

  void _onMemberTap(BuildContext context, MemberInsurance mi, bool canManage) {
    if (mi.status == InsuranceStatus.sinSeguro) {
      if (canManage) {
        _openAddSheet(context, mi.memberId);
      }
      return;
    }
    Navigator.push(
      context,
      SacSharedAxisRoute(builder: (_) => InsuranceDetailView(insurance: mi)),
    );
  }

  void _openAddSheet(BuildContext context, String? preselectedMemberId) {
    showSacSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          InsuranceFormSheet(preselectedMemberId: preselectedMemberId),
    );
  }
}

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
        if (summary != null)
          InsuranceSummaryHeader(
            summary: summary!,
            selectedFilter: filters.statusFilter,
            onFilterChanged: onStatusFilterChanged,
          )
        else
          const SizedBox(height: 8),
        expiringAsync.whenOrNull(
              data: (expiring) => expiring.isNotEmpty
                  ? _ExpiringBanner(count: expiring.length)
                  : null,
            ) ??
            const SizedBox.shrink(),
        _SearchBar(controller: searchController, onChanged: onSearchChanged),
        _SortCountRow(
          count: items.length,
          sortOrder: filters.sortOrder,
          onSortChanged: onSortChanged,
        ),
        if (items.isEmpty)
          _EmptyState(
            hasFilters: filters.hasActiveFilters,
            canManage: canManage,
          )
        else
          _MemberGroup(
            items: items,
            canManage: canManage,
            onItemTap: onItemTap,
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _MemberGroup extends StatelessWidget {
  final List<MemberInsurance> items;
  final bool canManage;
  final ValueChanged<MemberInsurance> onItemTap;

  const _MemberGroup({
    required this.items,
    required this.canManage,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: c.borderLight),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _staggeredRow(
                  index: i,
                  child: MemberInsuranceCard(
                    insurance: items[i],
                    showSeparator: i < items.length - 1,
                    onTap: _rowTap(items[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staggeredRow({required int index, required Widget child}) {
    if (index >= 6) return child;
    return StaggeredListItem(
      index: index,
      staggerDelay: SacMotion.stagger,
      duration: SacMotion.standard,
      slideOffset: 8,
      child: child,
    );
  }

  VoidCallback? _rowTap(MemberInsurance mi) {
    if (mi.status == InsuranceStatus.sinSeguro && !canManage) {
      return null;
    }
    return () => onItemTap(mi);
  }
}

class _ExpiringBanner extends StatelessWidget {
  final int count;

  const _ExpiringBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final key = count == 1
        ? 'insurance.view.expiring_banner_one'
        : 'insurance.view.expiring_banner_other';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 16,
            color: c.onWarning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              key.tr(namedArgs: {'count': '$count'}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.onWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 16, color: c.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'insurance.view.search_hint'.tr(),
          hintStyle: TextStyle(color: c.textTertiary, fontSize: 16),
          prefixIconConstraints: FixedInputIconSlot.constraints,
          prefixIcon: FixedInputIconSlot(
            icon: HugeIcons.strokeRoundedSearch01,
            iconSize: 18,
            color: c.textTertiary,
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
                    color: c.textTertiary,
                  ),
                )
              : null,
          filled: true,
          fillColor: c.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

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
    final c = context.sac;
    final key = count == 1
        ? 'insurance.view.member_count_one'
        : 'insurance.view.member_count_other';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Text(
            key.tr(namedArgs: {'count': '$count'}).toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showSortMenu(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: c.textSecondary,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSortByUp01,
                  size: 14,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  sortOrder.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showSacSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _SortSheet(current: sortOrder, onSelected: onSortChanged),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final InsuranceSortOrder current;
  final ValueChanged<InsuranceSortOrder> onSelected;

  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'insurance.view.sort_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
          ),
          ...InsuranceSortOrder.values.map((so) {
            final isSelected = so == current;
            return ListTile(
              title: Text(
                so.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : c.text,
                ),
              ),
              trailing: isSelected
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 18,
                      color: AppColors.primary,
                    )
                  : null,
              onTap: () {
                onSelected(so);
                Navigator.pop(context);
              },
            );
          }),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 48,
            color: c.error,
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
                  color: c.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SacButton(
            text: 'common.retry'.tr(),
            onPressed: onRetry,
            icon: HugeIcons.strokeRoundedRefresh,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final bool canManage;

  const _EmptyState({required this.hasFilters, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedShield01,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'insurance.view.empty_filtered_title'.tr()
                : 'insurance.view.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c.textSecondary,
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
                  color: c.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
