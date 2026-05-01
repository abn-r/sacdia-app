import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction.dart';

/// Segmented tab control for filtering transactions by type:
/// Todo / Ingresos / Egresos.
///
/// [selected] is `null` for "Todo", [TransactionType.income] for "Ingresos",
/// and [TransactionType.expense] for "Egresos".
class TransactionTypeTabs extends StatelessWidget {
  final TransactionType? selected;
  final ValueChanged<TransactionType?> onChanged;

  const TransactionTypeTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static List<(String, TransactionType?)> get _tabs => [
    ('finances.widgets.tab_all'.tr(), null),
    ('finances.widgets.tab_income'.tr(), TransactionType.income),
    ('finances.widgets.tab_expense'.tr(), TransactionType.expense),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9);
    final activeColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (label, type) in _tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == type
                        ? activeColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected == type
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == type
                          ? context.sac.text
                          : context.sac.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
