import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_event_agenda.dart';

/// "Now at the camporee": the activities running right now (one or several in
/// parallel) and the ones that start next. Shown only from the camporee's
/// first day (00:00 local time) until the program is over. Refreshes every
/// 30 seconds.
class CamporeeAgendaNowGroup extends StatefulWidget {
  final List<CamporeeEvent> events;
  final DateTime startDate;
  final ValueChanged<CamporeeEvent> onOpenEvent;

  /// Space around the group; not applied while it is hidden.
  final EdgeInsetsGeometry padding;

  /// Current time; tests inject a fixed clock.
  final DateTime Function() clock;

  const CamporeeAgendaNowGroup({
    super.key,
    required this.events,
    required this.startDate,
    required this.onOpenEvent,
    this.padding = EdgeInsets.zero,
    this.clock = DateTime.now,
  });

  @override
  State<CamporeeAgendaNowGroup> createState() => _CamporeeAgendaNowGroupState();
}

class _CamporeeAgendaNowGroupState extends State<CamporeeAgendaNowGroup> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final firstDay = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    if (now.isBefore(firstDay)) return const SizedBox.shrink();

    final agenda = resolveCamporeeAgendaNow(
      buildCamporeeAgendaEntries(widget.events),
      startDate: widget.startDate,
      now: now,
    );
    if (agenda.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[
      for (final slot in agenda.current)
        _NowRow(
          key: Key(
            'camporee-now-current-${slot.entry.event.camporeeEventId}-${slot.entry.dayNumber}-${slot.entry.startsAt}',
          ),
          slot: slot,
          badge: SacBadge(
            label: 'camporees.detail.now_in_progress'.tr(),
            variant: SacBadgeVariant.secondary,
          ),
          detail: 'camporees.detail.now_until'.tr(
            namedArgs: {'time': _clock(slot.end)},
          ),
          onTap: () => widget.onOpenEvent(slot.entry.event),
        ),
      for (final slot in agenda.next)
        _NowRow(
          key: Key(
            'camporee-now-next-${slot.entry.event.camporeeEventId}-${slot.entry.dayNumber}-${slot.entry.startsAt}',
          ),
          slot: slot,
          badge: SacBadge(
            label: 'camporees.detail.now_next'.tr(),
            variant: SacBadgeVariant.info,
          ),
          detail: _startsLabel(context, slot.start, now),
          onTap: () => widget.onOpenEvent(slot.entry.event),
        ),
    ];

    return Padding(
      padding: widget.padding,
      child: SacSettingsGroup(
        key: const Key('camporee-agenda-now'),
        title: 'camporees.detail.now_title'.tr().toUpperCase(),
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SacSettingsDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  /// "En 25 min", "En 2 h 10 min", "Mañana" or "sáb 13 feb".
  static String _startsLabel(
      BuildContext context, DateTime start, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final days = startDay.difference(today).inDays;
    if (days == 0) {
      final minutes = (start.difference(now).inSeconds / 60).ceil();
      if (minutes < 60) {
        return 'camporees.detail.now_in_minutes'
            .tr(namedArgs: {'minutes': '$minutes'});
      }
      final hours = minutes ~/ 60;
      final rest = minutes % 60;
      return rest == 0
          ? 'camporees.detail.now_in_hours'.tr(namedArgs: {'hours': '$hours'})
          : 'camporees.detail.now_in_hours_minutes'.tr(
              namedArgs: {'hours': '$hours', 'minutes': '$rest'},
            );
    }
    if (days == 1) return 'camporees.detail.now_tomorrow'.tr();
    return SacDateFormatter.formatCalendar(
      start,
      'EEE d MMM',
      locale: context.locale.languageCode,
    );
  }
}

class _NowRow extends StatelessWidget {
  final CamporeeAgendaSlot slot;
  final Widget badge;
  final String detail;
  final VoidCallback onTap;

  const _NowRow({
    super.key,
    required this.slot,
    required this.badge,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final venue = slot.entry.venueName?.trim();
    final subtitle = [
      detail,
      if (venue != null && venue.isNotEmpty) venue,
    ].join(' · ');

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  _CamporeeAgendaNowGroupState._clock(slot.start),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.entry.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              badge,
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
