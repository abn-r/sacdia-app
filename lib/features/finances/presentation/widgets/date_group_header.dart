import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/sac_colors.dart';

/// Shared date group header for transaction lists.
///
/// Displays the day label (e.g. "Martes, 18 marzo") on the left and the
/// signed daily total on the right.  Extracted from the private
/// `_DateGroupHeader` widget that previously lived in `finances_view.dart`
/// so that both [FinancesView] and [AllTransactionsView] can reuse it.
class DateGroupHeader extends StatelessWidget {
  final DateTime date;
  final double dailyTotal;

  const DateGroupHeader({
    super.key,
    required this.date,
    required this.dailyTotal,
  });

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
