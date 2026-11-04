import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_month.dart';
import '../providers/finances_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: c.textTertiary,
            ),
          ),

          const SizedBox(height: 6),

          // 2 — Balance amount
          Text(
            SacMoney.format(balance),
            style: TextStyle(
              fontSize: SacFontSize.metricSmall,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: c.text,
              fontFeatures: SacMoney.tabularFigures,
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
                semanticLabel: 'finances.widgets.prev_month'.tr(),
                onTap: () =>
                    ref.read(selectedMonthProvider.notifier).goToPrevious(),
              ),
              const SizedBox(width: 16),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: c.text,
                ),
              ),
              const SizedBox(width: 16),
              _NavChevron(
                icon: HugeIcons.strokeRoundedArrowRight01,
                enabled: canGoNext,
                semanticLabel: 'finances.widgets.next_month'.tr(),
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

  String _monthLabel(int year, int month) {
    final label = DateFormat('MMMM yyyy').format(DateTime(year, month));
    return label[0].toUpperCase() + label.substring(1);
  }
}

// ── Nav chevron ───────────────────────────────────────────────────────────────

class _NavChevron extends StatelessWidget {
  final HugeIconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _NavChevron({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
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
    final incomeGreen = context.sac.onSuccessContainer;
    final expenseRed = context.sac.onErrorContainer;

    final base = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      fontWeight: FontWeight.w400,
      color: textColor,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
              text: 'finances.widgets.month_summary_prefix'.tr(), style: base),
          TextSpan(
            text: SacMoney.format(income),
            style: base.copyWith(
              color: incomeGreen,
              fontWeight: FontWeight.w700,
              fontFeatures: SacMoney.tabularFigures,
            ),
          ),
          TextSpan(
              text: 'finances.widgets.month_summary_connector'.tr(),
              style: base),
          TextSpan(
            text: SacMoney.format(expense),
            style: base.copyWith(
              color: expenseRed,
              fontWeight: FontWeight.w700,
              fontFeatures: SacMoney.tabularFigures,
            ),
          ),
          TextSpan(
              text: 'finances.widgets.month_summary_suffix'.tr(), style: base),
        ],
      ),
    );
  }
}
