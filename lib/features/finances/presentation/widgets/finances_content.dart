import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../views/all_transactions_view.dart';
import '../views/transaction_detail_view.dart';
import 'category_breakdown_section.dart';
import 'closed_period_banner.dart';
import 'date_group_header.dart';
import 'finance_line_chart.dart';
import 'transaction_tile.dart';

/// Todo lo de Finanzas bajo el encabezado de saldo: aviso de periodo cerrado,
/// gráfico, totales por categoría y movimientos del mes.
class FinancesContent extends ConsumerWidget {
  final FinanceMonth? financeMonth;

  const FinancesContent({super.key, required this.financeMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClosed = ref.watch(financePeriodClosedProvider);
    final transactions = financeMonth?.transactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Closed period banner
        if (isClosed) const ClosedPeriodBanner(),

        // Separator
        const _DashedSeparator(),

        // Area line chart with period selector
        const FinanceLineChart(),

        // Separator
        const _DashedSeparator(),

        // Totals by category for the selected month
        const CategoryBreakdownSection(),

        // Separator
        const _DashedSeparator(),

        // Transactions section header
        _TransactionsSectionHeader(
          onViewAll: () => _openFullTransactionList(context),
        ),

        // Transactions or empty state
        if (transactions.isEmpty)
          SacEmptyState(
            icon: HugeIcons.strokeRoundedMoneyReceive01,
            title: 'finances.view.empty_title'.tr(),
            body: 'finances.view.empty_subtitle'.tr(),
          )
        else
          ..._buildGroupedTransactions(context, transactions),

        // Bottom navigation clearance
        const SizedBox(height: 40),
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

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    var globalIndex = 0;

    for (final date in sortedDates) {
      final dayTransactions = grouped[date]!;
      final dailyTotal = dayTransactions.fold<double>(
        0,
        (sum, tx) =>
            sum + (tx.type == TransactionType.income ? tx.amount : -tx.amount),
      );

      widgets.add(DateGroupHeader(date: date, dailyTotal: dailyTotal));

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
      SacSharedAxisRoute(builder: (_) => TransactionDetailView(transaction: t)),
    );
  }

  void _openFullTransactionList(BuildContext context) {
    // Pass the currently selected month so AllTransactionsView seeds its
    // date range filter to that month on first open.
    final selected = ProviderScope.containerOf(
      context,
    ).read(selectedMonthProvider);
    Navigator.of(context).push(
      SacSharedAxisRoute(
        builder: (_) => AllTransactionsView(initialMonth: selected),
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
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, 1.5),
          painter: _DashedLinePainter(color: context.sac.border),
        ),
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
            'finances.view.recent_transactions'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          SacButton.text(
            text: 'finances.view.view_all'.tr(),
            onPressed: onViewAll,
            color: c.textSecondary,
          ),
        ],
      ),
    );
  }
}
