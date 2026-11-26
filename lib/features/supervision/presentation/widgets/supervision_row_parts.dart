import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/relative_time.dart';
import 'supervision_format.dart';

/// Trailing mark of a queue row: how long ago the item arrived («hace 4
/// días») or, with [absolute], the day it was decided («12 nov»). Tertiary
/// and small; never takes more than a third of the row, so it shortens before
/// it pushes the title out.
class SupervisionRowAge extends StatelessWidget {
  const SupervisionRowAge(
      {super.key, required this.when, this.absolute = false});

  final DateTime? when;
  final bool absolute;

  @override
  Widget build(BuildContext context) {
    final date = when;
    if (date == null) return const SizedBox.shrink();
    final c = context.sac;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.3,
      ),
      child: Text(
        absolute
            ? supervisionDayMonth(context, date)
            : formatRelativeTime(date),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          color: c.textTertiary,
        ),
      ),
    );
  }
}

/// Figure at the end of a `SacListRow` (a price, a time, an amount) that never
/// takes more than [maxFraction] of the screen: a big number at a large text
/// scale shrinks to fit instead of pushing the title out of the row.
class SupervisionTrailingFit extends StatelessWidget {
  const SupervisionTrailingFit({
    super.key,
    required this.child,
    this.maxFraction = 0.4,
  });

  final Widget child;
  final double maxFraction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * maxFraction,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}
