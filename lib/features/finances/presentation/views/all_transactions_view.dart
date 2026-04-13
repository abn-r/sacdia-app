import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../widgets/date_group_header.dart';
import '../widgets/range_bottom_sheet.dart';
import '../widgets/sort_bottom_sheet.dart';
import '../widgets/transaction_search_field.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_type_tabs.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_view.dart';

// ── View ───────────────────────────────────────────────────────────────────────

/// Full-screen view listing ALL club transactions with server-side search,
/// type filtering, date range, sort, and infinite scroll pagination.
///
/// Pushed from [FinancesView] via `SacSharedAxisRoute`.
/// [initialMonth] seeds the first range filter to that month.
class AllTransactionsView extends ConsumerStatefulWidget {
  final SelectedMonth initialMonth;

  const AllTransactionsView({
    super.key,
    required this.initialMonth,
  });

  @override
  ConsumerState<AllTransactionsView> createState() =>
      _AllTransactionsViewState();
}

class _AllTransactionsViewState extends ConsumerState<AllTransactionsView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Seed the filter with the month selected in FinancesView.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(allTransactionsFilterNotifierProvider.notifier)
          .initWithMonth(widget.initialMonth);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    final state = ref.read(allTransactionsFilterNotifierProvider);
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        state.hasNextPage &&
        !state.isLoadingMore) {
      ref
          .read(allTransactionsFilterNotifierProvider.notifier)
          .loadNextPage();
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _openDetail(FinanceTransaction t) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => TransactionDetailView(transaction: t),
      ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    ).then((_) {
      // Refresh the list after adding a transaction.
      ref
          .read(allTransactionsFilterNotifierProvider.notifier)
          .reset();
    });
  }

  void _openSortSheet() {
    final filter =
        ref.read(allTransactionsFilterNotifierProvider).filter;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SortBottomSheet(
        currentSortBy: filter.sortBy,
        currentSortOrder: filter.sortOrder,
        onApply: (sortBy, sortOrder) {
          ref
              .read(allTransactionsFilterNotifierProvider.notifier)
              .updateSort(sortBy: sortBy, sortOrder: sortOrder);
        },
      ),
    );
  }

  void _openRangeSheet() {
    final filter =
        ref.read(allTransactionsFilterNotifierProvider).filter;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RangeBottomSheet(
        currentPreset: filter.rangePreset,
        currentStart: filter.startDate,
        currentEnd: filter.endDate,
        onApply: (preset, start, end) {
          ref
              .read(allTransactionsFilterNotifierProvider.notifier)
              .updateRange(
                preset: preset,
                startDate: start,
                endDate: end,
              );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(allTransactionsFilterNotifierProvider);
    final canManage = ref.watch(canManageFinancesProvider).valueOrNull ?? false;
    final financeMonth = ref.watch(financeMonthProvider).valueOrNull;
    final isOpen = financeMonth?.isOpen ?? true;
    final showFab = canManage && isOpen;
    final rangeLabel = ref.watch(allTransactionsRangeLabelProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton:
          showFab ? _AddFab(onTap: _openAddSheet) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom App Bar ────────────────────────────────────────
            _AllTransactionsAppBar(
              rangeLabel: rangeLabel,
              onSortTap: _openSortSheet,
              onRangeTap: _openRangeSheet,
            ),

            // ── Search field (always visible) ─────────────────────────
            TransactionSearchField(
              initialValue: txState.filter.search ?? '',
              onSearch: (value) => ref
                  .read(allTransactionsFilterNotifierProvider.notifier)
                  .updateSearch(value),
            ),

            // ── Segmented tabs ────────────────────────────────────────
            TransactionTypeTabs(
              selected: txState.filter.type,
              onChanged: (type) => ref
                  .read(allTransactionsFilterNotifierProvider.notifier)
                  .updateType(type),
            ),

            // ── Transaction list ──────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref
                      .read(allTransactionsFilterNotifierProvider
                          .notifier)
                      .reset();
                },
                child: _TransactionListBody(
                  txState: txState,
                  scrollController: _scrollController,
                  onTransactionTap: _openDetail,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────────

class _AllTransactionsAppBar extends StatelessWidget {
  final String rangeLabel;
  final VoidCallback onSortTap;
  final VoidCallback onRangeTap;

  const _AllTransactionsAppBar({
    required this.rangeLabel,
    required this.onSortTap,
    required this.onRangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.sac.background,
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 22,
              color: context.sac.text,
            ),
          ),
          // Title + range subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transacciones',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.sac.text,
                  ),
                ),
                Text(
                  rangeLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.sac.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Sort icon
          IconButton(
            onPressed: onSortTap,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSortByDown02,
              size: 22,
              color: context.sac.textSecondary,
            ),
          ),
          // Range icon
          IconButton(
            onPressed: onRangeTap,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 22,
              color: context.sac.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction list body ──────────────────────────────────────────────────────

class _TransactionListBody extends StatelessWidget {
  final AllTransactionsState txState;
  final ScrollController scrollController;
  final ValueChanged<FinanceTransaction> onTransactionTap;

  const _TransactionListBody({
    required this.txState,
    required this.scrollController,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    // Full-page loading (first page fetch)
    if (txState.isLoading) {
      return const Center(child: SacLoading());
    }

    // Full-page error
    if (txState.errorMessage != null && txState.transactions.isEmpty) {
      return _ErrorState(
        message: txState.errorMessage!,
        onRetry: () {}, // pull-to-refresh handles this
      );
    }

    // Empty state
    if (txState.transactions.isEmpty) {
      return _EmptyState(
        hasActiveSearch: txState.filter.search != null &&
            txState.filter.search!.isNotEmpty,
      );
    }

    // Build grouped list
    final grouped = _groupByDate(txState.transactions);
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final items = <_ListItem>[];
    for (final date in sortedDates) {
      final dayTx = grouped[date]!;
      final dailyTotal = dayTx.fold<double>(
        0,
        (sum, tx) => sum + (tx.type.isIncome ? tx.amount : -tx.amount),
      );
      items.add(_ListItem.header(date: date, dailyTotal: dailyTotal));
      for (final tx in dayTx) {
        items.add(_ListItem.transaction(tx));
      }
    }

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: items.length + (txState.isLoadingMore ? 1 : 1), // +1 for bottom clearance
      itemBuilder: (context, index) {
        // Bottom clearance / load-more indicator
        if (index == items.length) {
          if (txState.isLoadingMore) {
            return const _LoadMoreIndicator();
          }
          return const SizedBox(height: 80);
        }

        final item = items[index];
        if (item.isHeader) {
          return DateGroupHeader(
            date: item.date!,
            dailyTotal: item.dailyTotal!,
          );
        }
        return TransactionTile(
          transaction: item.transaction!,
          onTap: () => onTransactionTap(item.transaction!),
        );
      },
    );
  }

  Map<DateTime, List<FinanceTransaction>> _groupByDate(
    List<FinanceTransaction> transactions,
  ) {
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final tx in transactions) {
      final local = tx.date.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    return grouped;
  }
}

/// Simple discriminated union for list items to avoid two separate lists.
class _ListItem {
  final bool isHeader;
  final DateTime? date;
  final double? dailyTotal;
  final FinanceTransaction? transaction;

  const _ListItem._({
    required this.isHeader,
    this.date,
    this.dailyTotal,
    this.transaction,
  });

  factory _ListItem.header({
    required DateTime date,
    required double dailyTotal,
  }) =>
      _ListItem._(isHeader: true, date: date, dailyTotal: dailyTotal);

  factory _ListItem.transaction(FinanceTransaction tx) =>
      _ListItem._(isHeader: false, transaction: tx);
}

// ── Load more indicator ────────────────────────────────────────────────────────

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Cargando más\u2026',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.sac.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasActiveSearch;

  const _EmptyState({required this.hasActiveSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 56,
              color: context.sac.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontraron transacciones',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.sac.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveSearch
                  ? 'Probá con otros términos o cambiá el rango de fechas.'
                  : 'No hay transacciones para el rango seleccionado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: context.sac.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar transacciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.sac.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.sac.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Deslizá hacia abajo para reintentar.',
              style: TextStyle(
                fontSize: 12,
                color: context.sac.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB ────────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333EA).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

