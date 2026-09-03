import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity_series.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_form_widgets.dart';

class ActivitySeriesFormSection extends StatelessWidget {
  final bool enabled;
  final bool repeat;
  final ValueChanged<bool> onRepeatChanged;
  final String kind;
  final ValueChanged<String> onKindChanged;
  final int weekday;
  final ValueChanged<int> onWeekdayChanged;
  final int intervalDays;
  final ValueChanged<int> onIntervalDaysChanged;
  final DateTime? until;
  final VoidCallback? onPickUntil;
  final VoidCallback? onClearUntil;
  final ActivitySeriesPreview? preview;
  final bool previewLoading;
  final String? previewError;

  const ActivitySeriesFormSection({
    super.key,
    required this.enabled,
    required this.repeat,
    required this.onRepeatChanged,
    required this.kind,
    required this.onKindChanged,
    required this.weekday,
    required this.onWeekdayChanged,
    required this.intervalDays,
    required this.onIntervalDaysChanged,
    required this.until,
    required this.onPickUntil,
    required this.onClearUntil,
    required this.preview,
    required this.previewLoading,
    this.previewError,
  });

  static const _weekdayKeys = {
    1: 'activities.series.weekday_1',
    2: 'activities.series.weekday_2',
    3: 'activities.series.weekday_3',
    4: 'activities.series.weekday_4',
    5: 'activities.series.weekday_5',
    6: 'activities.series.weekday_6',
    7: 'activities.series.weekday_7',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: repeat
                  ? AppColors.secondary.withValues(alpha: 0.45)
                  : c.border,
              width: repeat ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                offset: const Offset(0, 3),
                blurRadius: 12,
              ),
            ],
          ),
          child: SwitchListTile(
            value: repeat,
            onChanged: enabled ? onRepeatChanged : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              'activities.series.toggle_title'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            subtitle: Text(
              'activities.series.toggle_subtitle'.tr(),
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: repeat ? AppColors.secondaryLight : c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
                color: repeat ? AppColors.secondaryDark : c.textTertiary,
              ),
            ),
          ),
        ),
        if (repeat) ...[
          const SizedBox(height: 12),
          ActivitySegmentedSelector<String>(
            label: 'activities.series.kind_label'.tr(),
            value: kind,
            options: [
              ActivitySegmentOption(
                value: 'weekly',
                label: 'activities.series.kind_weekly'.tr(),
              ),
              ActivitySegmentOption(
                value: 'interval',
                label: 'activities.series.kind_interval'.tr(),
              ),
            ],
            onChanged: enabled ? onKindChanged : null,
          ),
          const SizedBox(height: 12),
          if (kind == 'weekly')
            Row(
              children: [
                for (final day in [1, 2, 3, 4, 5, 6, 7]) ...[
                  if (day > 1) const SizedBox(width: 4),
                  Expanded(
                    child: _WeekdayChip(
                      label: _weekdayKeys[day]!.tr(),
                      selected: weekday == day,
                      enabled: enabled,
                      onTap: () => onWeekdayChanged(day),
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'activities.series.every_days'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: enabled && intervalDays > 1
                              ? () => onIntervalDaysChanged(intervalDays - 1)
                              : null,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedRemove01,
                            size: 18,
                            color: c.text,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$intervalDays',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: enabled && intervalDays < 365
                              ? () => onIntervalDaysChanged(intervalDays + 1)
                              : null,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedAdd01,
                            size: 18,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          ActivityDatePickerField(
            label: 'activities.series.until_label'.tr(),
            value: until,
            enabled: enabled,
            onTap: onPickUntil,
            onClear: until == null ? null : onClearUntil,
          ),
          const SizedBox(height: 12),
          if (previewLoading)
            Text(
              'activities.series.preview_loading'.tr(),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            )
          else if (previewError != null)
            Text(
              'activities.series.preview_error'.tr(),
              style: TextStyle(fontSize: 13, color: AppColors.error),
            )
          else if (preview != null)
            _SeriesPreviewChips(preview: preview!),
        ],
      ],
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: selected ? AppColors.secondaryLight : c.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.secondary.withValues(alpha: 0.55)
                  : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.secondaryDark : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeriesPreviewChips extends StatelessWidget {
  final ActivitySeriesPreview preview;

  const _SeriesPreviewChips({required this.preview});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final first = preview.dates.isNotEmpty ? preview.dates.first : null;
    final last = preview.dates.length > 1 ? preview.dates.last : null;
    final middle = preview.dates.length > 2
        ? preview.dates.sublist(1, preview.dates.length - 1)
        : const <String>[];
    final visible = middle.take(5).toList();
    final remaining = middle.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'activities.series.preview_title'.tr(
            namedArgs: {'count': '${preview.count}'},
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (first != null) _DateChip(date: first, emphasis: true),
            ...visible.map((date) => _DateChip(date: date)),
            if (remaining > 0)
              Text(
                'activities.series.preview_more'.tr(
                  namedArgs: {'count': '$remaining'},
                ),
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            if (last != null) _DateChip(date: last, emphasis: true),
          ],
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String date;
  final bool emphasis;

  const _DateChip({required this.date, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis ? AppColors.secondaryLight : c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        date,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
          color: emphasis ? AppColors.secondaryDark : c.textSecondary,
        ),
      ),
    );
  }
}
