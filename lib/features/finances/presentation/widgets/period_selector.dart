import 'package:flutter/material.dart';
import '../../../../core/theme/sac_colors.dart';

/// Chip row for selecting a chart time range.
///
/// Emits the selected period string via [onChanged].
/// Periods: '1M', '3M', '6M', '1A', 'Todo'.
class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _periods = ['1M', '3M', '6M', '1A', 'Todo'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _periods.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _PeriodChip(
            period: _periods[i],
            isActive: _periods[i] == selected,
            isDark: isDark,
            onTap: () => onChanged(_periods[i]),
          ),
        ],
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String period;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.period,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? const Color(0xFF333333) : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          period,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.white : context.sac.textTertiary,
          ),
        ),
      ),
    );
  }
}
