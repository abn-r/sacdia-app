import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../domain/entities/activity.dart';

/// Primary info strip for the activity detail screen.
///
/// Top: compact "meta line" — muted text with dot separators showing
/// countdown + section. Non-pill styling avoids visual competition with
/// the colored identity chips (type / platform) directly above.
///
/// Bottom: fecha/hora card, the P0 "when" answer.
///
/// Tipo and Modalidad are intentionally absent — they live in the title
/// chip row above.
class ActivityInfoStrip extends StatelessWidget {
  final Activity activity;

  const ActivityInfoStrip({super.key, required this.activity});

  // ── formatting helpers ─────────────────────────────────────────────────────

  String _formatDate() {
    final start = activity.activityDate;
    if (start == null) return '—';
    final startFmt = DateFormat('d MMM yyyy', 'es').format(start.toLocal());
    final end = activity.activityEndDate;
    if (end != null && !_isSameDay(start, end)) {
      final endFmt = DateFormat('d MMM', 'es').format(end.toLocal());
      return '$startFmt – $endFmt';
    }
    return startFmt;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _effectiveDateTime() {
    final date = activity.activityDate?.toLocal();
    if (date == null) return null;
    final time = activity.activityTime;
    if (time == null || !time.contains(':')) return date;
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  ({String text, bool isPast, bool isUrgent})? _countdown() {
    final target = _effectiveDateTime();
    if (target == null) return null;
    final now = DateTime.now();
    final diff = target.difference(now);

    if (diff.isNegative) {
      final past = now.difference(target);
      final String text;
      if (past.inMinutes < 60) {
        text = 'activities.widgets.countdown_finished'.tr();
      } else if (past.inHours < 24) {
        text = 'activities.widgets.countdown_finished_hours'
            .tr(namedArgs: {'hours': '${past.inHours}'});
      } else if (past.inDays == 1) {
        text = 'activities.widgets.countdown_finished_yesterday'.tr();
      } else if (past.inDays < 7) {
        text = 'activities.widgets.countdown_finished_days'
            .tr(namedArgs: {'days': '${past.inDays}'});
      } else {
        text = 'activities.widgets.countdown_finished'.tr();
      }
      return (text: text, isPast: true, isUrgent: false);
    }

    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return (
        text: 'activities.widgets.countdown_minutes'
            .tr(namedArgs: {'minutes': '$m'}),
        isPast: false,
        isUrgent: true
      );
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final text = m > 0
          ? 'activities.widgets.countdown_hours_minutes'
              .tr(namedArgs: {'hours': '$h', 'minutes': '$m'})
          : 'activities.widgets.countdown_hours'
              .tr(namedArgs: {'hours': '$h'});
      return (text: text, isPast: false, isUrgent: false);
    }
    if (diff.inDays == 1) {
      return (
        text: 'activities.widgets.countdown_tomorrow'.tr(),
        isPast: false,
        isUrgent: false
      );
    }
    if (diff.inDays < 7) {
      return (
        text: 'activities.widgets.countdown_days'
            .tr(namedArgs: {'days': '${diff.inDays}'}),
        isPast: false,
        isUrgent: false
      );
    }
    return null;
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta line: muted text, dot-separated. Single row, no pills.
        _buildMetaLine(context),
        const SizedBox(height: 16),
        // Fecha / Hora card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: sac.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sac.borderLight, width: 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    label: 'activities.widgets.date_label_short'.tr(),
                    value: _formatDate(),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: sac.borderLight,
                ),
                Expanded(
                  child: _InfoCell(
                    icon: HugeIcons.strokeRoundedClock01,
                    label: 'activities.widgets.time_label_short'.tr(),
                    value: activity.activityTime ?? '—',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaLine(BuildContext context) {
    final sac = context.sac;
    final countdown = _countdown();

    final items = <_MetaItem>[];

    if (countdown != null) {
      items.add(_MetaItem(
        icon: countdown.isPast
            ? Icons.check_circle_rounded
            : Icons.schedule_rounded,
        text: countdown.text,
        // Urgent: primary color to keep attention. Otherwise muted.
        color: countdown.isUrgent
            ? AppColors.primaryDark
            : sac.textSecondary,
        weight: countdown.isUrgent ? FontWeight.w700 : FontWeight.w600,
      ));
    }

    final sectionLabel = (activity.clubTypeName != null &&
            activity.clubTypeName!.trim().isNotEmpty)
        ? activity.clubTypeName!.trim()
        : 'activities.widgets.section_fallback'
            .tr(namedArgs: {'section': '${activity.clubSectionId}'});

    items.add(_MetaItem(
      icon: Icons.groups_rounded,
      text: sectionLabel,
      color: sac.textSecondary,
      weight: FontWeight.w600,
    ));

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sac.textTertiary,
              height: 1,
            ),
          ),
        ));
      }
      children.add(items[i].build(context));
    }

    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String text;
  final Color color;
  final FontWeight weight;

  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
    required this.weight,
  });

  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: weight,
            letterSpacing: 0.1,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: sac.textTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: sac.text,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
