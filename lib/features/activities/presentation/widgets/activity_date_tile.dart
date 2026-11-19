import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'activity_date_format.dart';

/// Day number over a 3-letter month in an accent-light tile. Announced as
/// the full date ("Sábado 21 de noviembre").
class ActivityDateTile extends StatelessWidget {
  const ActivityDateTile({super.key, required this.date, required this.locale});

  final DateTime date;
  final String locale;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final local = date.toLocal();
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    // Same tint as SacBadge.primary: accent over the dark surface, not white.
    final fill = dark
        ? Color.alphaBlend(
            accent.color.withValues(alpha: 0.2), context.sac.surface)
        : accent.light;
    final ink =
        dark ? accent.forHighContrast(Brightness.dark).color : accent.dark;
    return Semantics(
      label: activityFullDate(local, locale),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${local.day}',
              style: TextStyle(
                fontSize: SacFontSize.titleLarge,
                fontWeight: FontWeight.w800,
                height: 1.05,
                color: ink,
              ),
            ),
            Text(
              activityShortMonth(local, locale).toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1.1,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
