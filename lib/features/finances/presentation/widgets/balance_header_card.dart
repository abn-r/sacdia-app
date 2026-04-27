import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_month.dart';
import '../providers/finances_providers.dart';

/// Header de saldo sin contenedor — layout centrado directamente
/// sobre el fondo de la pantalla.
///
/// Muestra: etiqueta SALDO TOTAL → monto → navegación de mes →
/// resumen de ingresos/egresos del período.
class BalanceHeaderCard extends ConsumerWidget {
  final FinanceMonth? financeMonth;
  final double? totalBalance;

  const BalanceHeaderCard({
    super.key,
    required this.financeMonth,
    this.totalBalance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = ref.watch(selectedMonthProvider);
    final canGoNext = !selected.isCurrentMonth;

    final balance = totalBalance ?? financeMonth?.totalBalance ?? 0;
    final income = financeMonth?.totalIncome ?? 0;
    final expense = financeMonth?.totalExpense ?? 0;

    final monthLabel = _monthLabel(selected.year, selected.month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1 — "SALDO TOTAL" label
          Text(
            'finances.widgets.balance_total'.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: c.textTertiary,
            ),
          ),

          const SizedBox(height: 6),

          // 2 — Balance amount
          Text(
            _formatCurrency(balance),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: c.text,
            ),
          ),

          const SizedBox(height: 20),

          // 3 — Month navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavChevron(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                enabled: true,
                onTap: () =>
                    ref.read(selectedMonthProvider.notifier).goToPrevious(),
              ),
              const SizedBox(width: 16),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: c.text,
                ),
              ),
              const SizedBox(width: 16),
              _NavChevron(
                icon: HugeIcons.strokeRoundedArrowRight01,
                enabled: canGoNext,
                onTap: canGoNext
                    ? () => ref.read(selectedMonthProvider.notifier).goToNext()
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4 — Activity summary
          _ActivitySummary(
            income: income,
            expense: expense,
            isDark: isDark,
            textColor: c.textSecondary,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(value);
  }

  String _monthLabel(int year, int month) {
    final label = DateFormat('MMMM yyyy', 'es').format(DateTime(year, month));
    return label[0].toUpperCase() + label.substring(1);
  }
}

// ── Nav chevron ───────────────────────────────────────────────────────────────

class _NavChevron extends StatelessWidget {
  final HugeIconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavChevron({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? c.surfaceVariant : c.borderLight,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 16,
            color: enabled ? c.text : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── Activity summary ──────────────────────────────────────────────────────────

class _ActivitySummary extends StatelessWidget {
  final double income;
  final double expense;
  final bool isDark;
  final Color textColor;

  const _ActivitySummary({
    required this.income,
    required this.expense,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final incomeGreen =
        isDark ? const Color(0xFF4FBF9F) : const Color(0xFF2D8A70);
    const expenseRed = Color(0xFFDC2626);

    final base = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: textColor,
    );

    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(text: 'finances.widgets.month_summary_prefix'.tr(), style: base),
          TextSpan(
            text: formatter.format(income),
            style: base.copyWith(
              color: incomeGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: 'finances.widgets.month_summary_connector'.tr(), style: base),
          TextSpan(
            text: formatter.format(expense),
            style: base.copyWith(
              color: expenseRed,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: 'finances.widgets.month_summary_suffix'.tr(), style: base),
        ],
      ),
    );
  }
}
