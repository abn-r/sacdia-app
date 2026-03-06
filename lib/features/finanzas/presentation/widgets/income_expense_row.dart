import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

/// Fila con dos chips: Ingresos y Egresos del mes.
class IncomeExpenseRow extends StatelessWidget {
  final double income;
  final double expense;

  const IncomeExpenseRow({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: 'Ingresos',
              amount: income,
              icon: HugeIcons.strokeRoundedArrowDown01,
              color: AppColors.secondary,
              bgColor: AppColors.secondaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryChip(
              label: 'Egresos',
              amount: expense,
              icon: HugeIcons.strokeRoundedArrowUp01,
              color: AppColors.error,
              bgColor: AppColors.errorLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final List<List<dynamic>> icon;
  final Color color;
  final Color bgColor;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.compact(locale: 'es').format(amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(icon: icon, size: 17, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$$formatted',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
