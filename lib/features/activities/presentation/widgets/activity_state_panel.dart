import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

import '../../domain/entities/activity.dart';
import 'activity_countdown.dart';
import 'activity_date_format.dart';

/// Current state of an activity from its date AND time: upcoming (countdown,
/// weekday and time), in progress, or finished (how long ago and, when the
/// backend sent attendees, how many came). Read-only: no step line.
class ActivityStatePanel extends StatelessWidget {
  const ActivityStatePanel({super.key, required this.activity, this.now});

  final Activity activity;

  /// Clock for tests. Null: the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final locale = context.locale.toString();
    final phase = activity.phaseAt(clock);
    final date = activity.activityDate;
    final time = activityTimeLabel(activity.activityTime);

    String? weekdayAtTime() {
      if (date == null) return null;
      final weekday = activityWeekday(date, locale);
      if (time == null) return weekday;
      // Spanish reads "a la 1:00", not "a las 1:00".
      final key = time.startsWith('1:')
          ? 'activities.detail.panel_weekday_at_one'
          : 'activities.detail.panel_weekday_at';
      return key.tr(namedArgs: {'weekday': weekday, 'time': time});
    }

    switch (phase) {
      case ActivityPhase.upcoming:
        final start = activity.startDateTime;
        final countdown =
            start == null ? null : activityCountdown(start, clock);
        final String title;
        if (countdown != null) {
          title = countdown.key.tr(namedArgs: countdown.args);
        } else if (start != null) {
          final days = DateTime.utc(start.year, start.month, start.day)
              .difference(DateTime.utc(clock.year, clock.month, clock.day))
              .inDays;
          title = 'activities.widgets.countdown_days'
              .tr(namedArgs: {'days': '$days'});
        } else {
          title = 'activities.detail.panel_upcoming'.tr();
        }
        return SacStatePanel(
          style: SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: title,
            icon: activity.platform == 1
                ? HugeIcons.strokeRoundedComputerVideoCall
                : HugeIcons.strokeRoundedClock01,
          ),
          title: title,
          message: weekdayAtTime(),
        );
      case ActivityPhase.inProgress:
        final title = 'activities.detail.panel_in_progress'.tr();
        return SacStatePanel(
          style: SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: title,
            icon: HugeIcons.strokeRoundedPlayCircle,
          ),
          title: title,
          message: weekdayAtTime(),
        );
      case ActivityPhase.finished:
        final last = activity.lastDay;
        final countdown = last == null ? null : activityCountdown(last, clock);
        final title = countdown != null
            ? countdown.key.tr(namedArgs: countdown.args)
            : 'activities.widgets.countdown_finished'.tr();
        final attended = activity.attendees?.length ?? 0;
        return SacStatePanel(
          style: SacStatusStyle.of(
            context,
            SacStatusKind.validated,
            label: title,
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          ),
          title: title,
          message: attended > 0
              ? 'activities.detail.panel_attended'
                  .tr(namedArgs: {'count': '$attended'})
              : null,
        );
    }
  }
}
