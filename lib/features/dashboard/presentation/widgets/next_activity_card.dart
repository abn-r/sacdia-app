import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';

import '../../domain/entities/dashboard_summary.dart';

/// Primera actividad que no ha pasado, de una lista ordenada por fecha.
///
/// El resumen del dashboard ya viene ascendente; esto solo evita mostrar como
/// «próxima» una actividad de ayer si el servidor la dejara pasar.
UpcomingActivity? nextUpcomingActivity(
  Iterable<UpcomingActivity> activities, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  for (final activity in activities) {
    if (!activity.activityDate.isBefore(today)) return activity;
  }
  return null;
}

/// «Próxima actividad» del inicio en modo miembro: insignia de fecha, título,
/// «día · hora · lugar» y un badge con la cercanía (Hoy / Mañana / En N días).
///
/// Sin actividad muestra el estado vacío compacto del dashboard.
class NextActivityCard extends StatelessWidget {
  const NextActivityCard({super.key, required this.activity, this.onTap});

  final UpcomingActivity? activity;
  final ValueChanged<UpcomingActivity>? onTap;

  @override
  Widget build(BuildContext context) {
    final next = activity;
    if (next == null) {
      return SacCard(
        child: SacEmptyState.inline(
          title: tr('dashboard.activities.empty'),
          icon: HugeIcons.strokeRoundedCalendar04,
        ),
      );
    }

    final c = context.sac;
    final accent = SacAccent.of(context);
    final days = _daysUntil(next.activityDate);
    final meta = _meta(next, days);

    return SacCard(
      onTap: onTap == null ? null : () => onTap!(next),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: accent.light,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(next.activityDate),
                  style: TextStyle(
                    fontSize: SacFontSize.headlineLarge,
                    fontWeight: FontWeight.w700,
                    color: accent.color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM').format(next.activityDate).toUpperCase(),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    color: accent.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('dashboard.next_activity.label'),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.title,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_proximity(days) case final badge?) ...[
            const SizedBox(width: 8),
            SacBadge.info(label: badge),
          ],
        ],
      ),
    );
  }

  /// Días de calendario hasta [date] (medianoche local contra medianoche local).
  static int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(date.year, date.month, date.day).difference(today).inDays;
  }

  static String? _proximity(int days) {
    if (days < 0) return null;
    if (days == 0) return tr('dashboard.activities.today');
    if (days == 1) return tr('dashboard.activities.tomorrow');
    return 'dashboard.next_activity.in_days'.plural(days);
  }

  static String _meta(UpcomingActivity activity, int days) {
    final day = days >= 0 && days < 7
        ? DateFormat('EEEE').format(activity.activityDate)
        : DateFormat('dd MMM').format(activity.activityDate);
    final time = activity.activityTime?.trim();
    final location = activity.location?.trim();
    return [
      day,
      if (time != null && time.isNotEmpty) time,
      if (location != null && location.isNotEmpty) location,
    ].join(' · ');
  }
}
