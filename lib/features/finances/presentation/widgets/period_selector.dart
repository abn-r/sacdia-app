import 'package:flutter/material.dart';
import '../../../../core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
    final activeColor = isDark ? context.sac.border : context.sac.ink900;

    return Semantics(
      button: true,
      selected: isActive,
      label: period,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: SacFontSize.caption,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? context.sac.onPrimary
                      : context.sac.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
