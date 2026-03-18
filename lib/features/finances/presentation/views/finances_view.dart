import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../widgets/balance_header_card.dart';
import '../widgets/closed_period_banner.dart';
import '../widgets/finance_bar_chart.dart';
import '../widgets/income_expense_row.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_view.dart';

/// Pantalla principal del módulo de Finanzas.
///
/// Muestra el saldo acumulado, el resumen del mes seleccionado,
/// un gráfico de barras mensual y la lista de transacciones.
class FinancesView extends ConsumerWidget {
  const FinancesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeMonthAsync = ref.watch(financeMonthProvider);
    final summaryAsync = ref.watch(financeSummaryProvider);
    final canManageAsync = ref.watch(canManageFinancesProvider);
    final selected = ref.watch(selectedMonthProvider);

    final isOpen = financeMonthAsync.valueOrNull?.isOpen ?? true;
    final canManage = canManageAsync.valueOrNull ?? false;
    final showFab = canManage && isOpen;

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton: showFab
          ? _AddFab(
              onTap: () => _openAddSheet(context, ref),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(financeMonthProvider);
            ref.invalidate(financeSummaryProvider);
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
                  'Finanzas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                ),
                centerTitle: false,
                actions: [
                  if (financeMonthAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: () {
                        ref.invalidate(financeMonthProvider);
                        ref.invalidate(financeSummaryProvider);
                      },
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedRefresh,
                        size: 20,
                        color: context.sac.textSecondary,
                      ),
                    ),
                ],
              ),

              // Body
              SliverToBoxAdapter(
                child: financeMonthAsync.when(
                  loading: () => _LoadingBody(selected: selected),
                  error: (e, _) => _ErrorBody(
                    message:
                        e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () {
                      ref.invalidate(financeMonthProvider);
                      ref.invalidate(financeSummaryProvider);
                    },
                  ),
                  data: (financeMonth) => _FinanceBody(
                    financeMonth: financeMonth,
                    summaryAsync: summaryAsync,
                    canManage: canManage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }
}

// ── Body principal ─────────────────────────────────────────────────────────────

class _FinanceBody extends ConsumerWidget {
  final FinanceMonth? financeMonth;
  final AsyncValue summaryAsync;
  final bool canManage;

  const _FinanceBody({
    required this.financeMonth,
    required this.summaryAsync,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = financeMonth?.isOpen ?? true;
    final totalBalance = summaryAsync.valueOrNull?.totalBalance ??
        financeMonth?.totalBalance ??
        0.0;
    final barData = summaryAsync.valueOrNull?.monthlyBars ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance header card
        BalanceHeaderCard(
          financeMonth: financeMonth,
          totalBalance: totalBalance,
        ),

        // Closed banner
        if (!isOpen) const ClosedPeriodBanner(),

        // Income / expense summary chips
        IncomeExpenseRow(
          income: financeMonth?.totalIncome ?? 0,
          expense: financeMonth?.totalExpense ?? 0,
        ),

        // Bar chart
        if (barData.isNotEmpty || summaryAsync.hasValue)
          FinanceBarChart(bars: barData),

        const SizedBox(height: 16),

        // Transactions header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Movimientos del mes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.sac.text,
                ),
          ),
        ),

        // Transactions list
        if (financeMonth == null || financeMonth!.transactions.isEmpty)
          _EmptyTransactions()
        else
          ...financeMonth!.transactions.asMap().entries.map(
            (entry) => StaggeredListItem(
              index: entry.key,
              child: TransactionTile(
                transaction: entry.value,
                onTap: () => _openDetail(context, entry.value),
              ),
            ),
          ),

        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }

  void _openDetail(BuildContext context, FinanceTransaction t) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => TransactionDetailView(transaction: t),
      ),
    );
  }
}

// ── Loading body ───────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  final SelectedMonth selected;

  const _LoadingBody({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Skeleton card placeholder
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          height: 160,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E3D7C), Color(0xFF1A2456)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: SacLoading()),
        ),
        const SizedBox(height: 200),
        const SacLoading(),
      ],
    );
  }
}

// ── Empty ──────────────────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMoneyReceive01,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos este mes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pulsa + para agregar el primer registro.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────────

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
            'Error al cargar finanzas',
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
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
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
