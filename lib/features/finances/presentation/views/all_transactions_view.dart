import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_view.dart';

// ── Filter enum ────────────────────────────────────────────────────────────────

enum _TxFilter { all, income, expense }

// ── View ───────────────────────────────────────────────────────────────────────

/// Pantalla que muestra TODAS las transacciones del mes seleccionado.
///
/// Reutiliza [financeMonthProvider] — sin llamadas adicionales al backend.
/// Incluye un control segmentado (Todo / Ingresos / Egresos) para filtrar
/// client-side, agrupación por fecha y el mismo FAB de la pantalla principal.
class AllTransactionsView extends ConsumerStatefulWidget {
  const AllTransactionsView({super.key});

  @override
  ConsumerState<AllTransactionsView> createState() =>
      _AllTransactionsViewState();
}

class _AllTransactionsViewState extends ConsumerState<AllTransactionsView> {
  _TxFilter _filter = _TxFilter.all;

  @override
  Widget build(BuildContext context) {
    final financeMonthAsync = ref.watch(financeMonthProvider);
    final canManageAsync = ref.watch(canManageFinancesProvider);
    final selected = ref.watch(selectedMonthProvider);

    final isOpen = financeMonthAsync.valueOrNull?.isOpen ?? true;
    final canManage = canManageAsync.valueOrNull ?? false;
    final showFab = canManage && isOpen;

    // Month subtitle: "Marzo 2026"
    final monthLabel = DateFormat('MMMM yyyy', 'es')
        .format(DateTime(selected.year, selected.month));
    final capitalizedMonth =
        monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton: showFab
          ? _AddFab(onTap: () => _openAddSheet(context))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(financeMonthProvider),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── App bar ─────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 0,
                backgroundColor: context.sac.background,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 22,
                    color: context.sac.text,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transacciones',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.sac.text,
                              ),
                    ),
                    Text(
                      capitalizedMonth,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.sac.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ],
                ),
                centerTitle: false,
              ),

              // ── Filter tabs ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _FilterTabs(
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),

              // ── Body ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: financeMonthAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: SacLoading()),
                  ),
                  error: (e, _) => _ErrorBody(
                    message: e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(financeMonthProvider),
                  ),
                  data: (financeMonth) {
                    final all = financeMonth?.transactions ?? [];
                    final filtered = _applyFilter(all);
                    if (filtered.isEmpty) {
                      return _EmptyState(filter: _filter);
                    }
                    return Column(
                      children: [
                        ..._buildGroupedTransactions(context, filtered),
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter logic ─────────────────────────────────────────────────────────

  List<FinanceTransaction> _applyFilter(List<FinanceTransaction> all) {
    switch (_filter) {
      case _TxFilter.all:
        return all;
      case _TxFilter.income:
        return all.where((t) => t.type.isIncome).toList();
      case _TxFilter.expense:
        return all.where((t) => t.type.isExpense).toList();
    }
  }

  // ── Grouped transactions builder ─────────────────────────────────────────

  List<Widget> _buildGroupedTransactions(
    BuildContext context,
    List<FinanceTransaction> transactions,
  ) {
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final tx in transactions) {
      final key = DateTime(
          tx.date.toLocal().year, tx.date.toLocal().month, tx.date.toLocal().day);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    var globalIndex = 0;

    for (final date in sortedDates) {
      final dayTx = grouped[date]!;
      final dailyTotal = dayTx.fold<double>(
        0,
        (sum, tx) =>
            sum + (tx.type.isIncome ? tx.amount : -tx.amount),
      );

      widgets.add(_DateGroupHeader(date: date, dailyTotal: dailyTotal));

      for (final tx in dayTx) {
        widgets.add(
          StaggeredListItem(
            index: globalIndex++,
            child: TransactionTile(
              transaction: tx,
              onTap: () => _openDetail(context, tx),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _openDetail(BuildContext context, FinanceTransaction t) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => TransactionDetailView(transaction: t),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }
}

// ── Filter tabs ────────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final _TxFilter selected;
  final ValueChanged<_TxFilter> onChanged;

  const _FilterTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _Tab(
              label: 'Todo',
              isSelected: selected == _TxFilter.all,
              onTap: () => onChanged(_TxFilter.all),
            ),
            _Tab(
              label: 'Ingresos',
              isSelected: selected == _TxFilter.income,
              onTap: () => onChanged(_TxFilter.income),
            ),
            _Tab(
              label: 'Egresos',
              isSelected: selected == _TxFilter.expense,
              onTap: () => onChanged(_TxFilter.expense),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? context.sac.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.sac.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? context.sac.text
                  : context.sac.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date group header ──────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  final DateTime date;
  final double dailyTotal;

  const _DateGroupHeader({required this.date, required this.dailyTotal});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateLabel = DateFormat('EEEE, d MMMM', 'es').format(date);
    final capitalizedDate =
        dateLabel[0].toUpperCase() + dateLabel.substring(1);
    final totalFormatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(dailyTotal.abs());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            capitalizedDate,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          Text(
            totalFormatted,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _TxFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _TxFilter.all => 'Sin movimientos este mes',
      _TxFilter.income => 'Sin ingresos este mes',
      _TxFilter.expense => 'Sin egresos este mes',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMoneyReceive01,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Error body ─────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar transacciones',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 18,
              color: Colors.white,
            ),
            label: const Text('Reintentar'),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
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
