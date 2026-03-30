import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../domain/entities/activity.dart';

/// 2×3 metadata grid — date, time, place, type, club section, platform.
///
/// Each cell is a mini-card with a subtle colored tint, a prominent icon,
/// and a large watermark icon for visual personality.
class ActivityMetadataGrid extends StatelessWidget {
  final Activity activity;

  const ActivityMetadataGrid({super.key, required this.activity});

  String _formatDateRange() {
    final start = activity.activityDate;
    final end = activity.activityEndDate;

    if (start == null) return '—';

    final startFmt = DateFormat('d MMM yyyy', 'es').format(start.toLocal());

    if (end != null && !_isSameDay(start, end)) {
      final endFmt = DateFormat('d MMM', 'es').format(end.toLocal());
      return '$startFmt – $endFmt';
    }

    return startFmt;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _platformLabel() {
    switch (activity.platform) {
      case 1:
        return 'Virtual';
      case 2:
        return 'Híbrido';
      default:
        return 'Presencial';
    }
  }

  String _typeLabel() {
    final name = activity.activityTypeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    switch (activity.activityType) {
      case 1:
        return 'Regular';
      case 2:
        return 'Especial';
      case 3:
        return 'Camporee';
      default:
        return 'Actividad';
    }
  }

  Color _typeColor() {
    switch (activity.activityType) {
      case 1:
        return AppColors.sacBlue;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Per-card accent colors — each card has its own visual identity
    const dateColor = Color(0xFF2EA0DA);    // Blue — calendar/time
    const timeColor = Color(0xFF9B59B6);    // Purple — clock
    const placeColor = Color(0xFF4FBF9F);   // Green — location
    final typeColor = _typeColor();          // Dynamic — activity type
    const sectionColor = Color(0xFFF06151); // Red (primary) — club
    const platformColor = Color(0xFFFBBD5E); // Yellow — connectivity

    final cells = [
      _MetaCell(
        icon: HugeIcons.strokeRoundedCalendar01,
        label: 'Fecha',
        value: _formatDateRange(),
        accentColor: dateColor,
      ),
      _MetaCell(
        icon: HugeIcons.strokeRoundedClock01,
        label: 'Hora',
        value: activity.activityTime ?? '—',
        accentColor: timeColor,
      ),
      _MetaCell(
        icon: HugeIcons.strokeRoundedLocation01,
        label: 'Lugar',
        value: activity.activityPlace.isNotEmpty
            ? activity.activityPlace
            : '—',
        accentColor: placeColor,
      ),
      _MetaCell(
        icon: HugeIcons.strokeRoundedCalendarAdd01,
        label: 'Tipo',
        value: _typeLabel(),
        accentColor: typeColor,
        highlightValue: true,
      ),
      _MetaCell(
        icon: HugeIcons.strokeRoundedUserGroup,
        label: 'Sección',
        value: 'Club ${activity.clubSectionId}',
        accentColor: sectionColor,
      ),
      _MetaCell(
        icon: HugeIcons.strokeRoundedWifi01,
        label: 'Modalidad',
        value: _platformLabel(),
        accentColor: platformColor,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.8,
      children: cells,
    );
  }
}

// ── _MetaCell ─────────────────────────────────────────────────────────────────

class _MetaCell extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final Color? accentColor;
  // When true, renders the value text in the accentColor instead of default
  final bool highlightValue;

  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
    this.highlightValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    final color = accentColor ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        // Subtle tinted background matching the card's accent color
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: Stack(
          children: [
            // Watermark icon — large, very low opacity background personality
            Positioned(
              right: -6,
              bottom: -8,
              child: HugeIcon(
                icon: icon,
                size: 48,
                color: color.withValues(alpha: 0.08),
              ),
            ),
            // Foreground content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Prominent icon in a tinted circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: icon,
                        size: 17,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: color.withValues(alpha: 0.75),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: highlightValue ? color : sac.text,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
