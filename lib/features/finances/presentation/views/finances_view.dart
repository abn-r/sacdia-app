import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../widgets/balance_header_card.dart';
import '../widgets/closed_period_banner.dart';
import '../widgets/finance_line_chart.dart';
import '../widgets/finances_loading_skeleton.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_sheet.dart';
import 'all_transactions_view.dart';
import 'transaction_detail_view.dart';

/// Pantalla principal del módulo de Finanzas.
///
/// Muestra el saldo acumulado, el resumen del mes seleccionado,
/// un gráfico de líneas con selector de período y la lista agrupada
/// de transacciones por fecha.
class FinancesView extends ConsumerWidget {
  const FinancesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeMonthAsync = ref.watch(financeMonthProvider);
    final summaryAsync = ref.watch(financeSummaryProvider);
    final canManageAsync = ref.watch(canManageFinancesProvider);

    final isOpen = financeMonthAsync.valueOrNull?.isOpen ?? true;
    final canManage = canManageAsync.valueOrNull ?? false;
    final showFab = canManage && isOpen;

    return Scaffold(
      backgroundColor: context.sac.background,
      floatingActionButton: showFab
          ? _AddFab(onTap: () => _openAddSheet(context, ref))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              // ── App bar ───────────────────────────────────────────────────
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

              // ── Body ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: financeMonthAsync.when(
                  loading: () => const FinancesLoadingSkeleton(),
                  error: (e, _) => _ErrorBody(
                    message: e.toString().replaceFirst('Exception: ', ''),
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
    final transactions = financeMonth?.transactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance header — centered layout
        BalanceHeaderCard(
          financeMonth: financeMonth,
          totalBalance: totalBalance,
        ),

        // Closed period banner
        if (!isOpen) const ClosedPeriodBanner(),

        // Separator
        const _DashedSeparator(),

        // Area line chart with period selector
        const FinanceLineChart(),

        // Separator
        const _DashedSeparator(),

        // Transactions section header
        _TransactionsSectionHeader(
          onViewAll: () => _openFullTransactionList(context),
        ),

        // Transactions or empty state
        if (transactions.isEmpty)
          _EmptyTransactions()
        else
          ..._buildGroupedTransactions(context, transactions),

        // "Ver todo" link at the bottom
        if (transactions.isNotEmpty)
          _VerTodoLink(onTap: () => _openFullTransactionList(context)),

        // FAB clearance
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Grouped transactions builder ──────────────────────────────────────────

  List<Widget> _buildGroupedTransactions(
    BuildContext context,
    List<FinanceTransaction> transactions,
  ) {
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final tx in transactions) {
      final dateKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    var globalIndex = 0;

    for (final date in sortedDates) {
      final dayTransactions = grouped[date]!;
      final dailyTotal = dayTransactions.fold<double>(
        0,
        (sum, tx) =>
            sum +
            (tx.type == TransactionType.income ? tx.amount : -tx.amount),
      );

      widgets.add(_DateGroupHeader(date: date, dailyTotal: dailyTotal));

      for (final tx in dayTransactions) {
        widgets.add(
          StaggeredListItem(
            index: globalIndex++,
            child: TransactionTile(
              transaction: tx,
              onTap: () => _openTransactionDetail(context, tx),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _openTransactionDetail(BuildContext context, FinanceTransaction t) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => TransactionDetailView(transaction: t),
      ),
    );
  }

  void _openFullTransactionList(BuildContext context) {
    Navigator.of(context).push(
      SacSharedAxisRoute(
        builder: (_) => const AllTransactionsView(),
      ),
    );
  }
}

// ── Empty transactions ─────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMoneyReceive01,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos este mes',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pulsa + para agregar el primer registro.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textTertiary,
                ),
          ),
        ],
      ),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Dashed separator ───────────────────────────────────────────────────────────

class _DashedSeparator extends StatelessWidget {
  const _DashedSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: CustomPaint(
        size: const Size(double.infinity, 1.5),
        painter: _DashedLinePainter(color: context.sac.border),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

// ── Transactions section header ────────────────────────────────────────────────

class _TransactionsSectionHeader extends StatelessWidget {
  final VoidCallback onViewAll;

  const _TransactionsSectionHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Transacciones Recientes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          GestureDetector(
            onTap: onViewAll,
            child: Text(
              'Ver todo →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
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
    final capitalizedDate = dateLabel[0].toUpperCase() + dateLabel.substring(1);
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

// ── Ver todo link ──────────────────────────────────────────────────────────────

class _VerTodoLink extends StatelessWidget {
  final VoidCallback onTap;

  const _VerTodoLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            'Ver todas las transacciones →',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.sac.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: context.sac.textTertiary,
            ),
          ),
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
