import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';

/// «Octubre de 2026» with the first letter in capitals.
String supervisionCapitalizedMonth(BuildContext context, int year, int month) {
  final text = supervisionMonthYear(context, year, month);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

// ── The month at a glance ───────────────────────────────────────────────────

/// «Entregados · 25 de 30 · 83%» with the delivered / pending / overdue bar
/// and, when the server gives the deadline, «límite 12 nov».
class SupervisionReportsMonthBox extends StatelessWidget {
  const SupervisionReportsMonthBox({
    super.key,
    required this.counts,
    required this.dueAt,
  });

  final SupervisionReportCounts counts;
  final DateTime? dueAt;

  @override
  Widget build(BuildContext context) {
    final due = dueAt;
    final meta = due == null
        ? null
        : 'supervision.reports.due_meta'
            .tr(args: [supervisionDayMonth(context, due.toLocal())]);
    final label = 'supervision.reports.box_title'.tr();
    const padding = EdgeInsets.fromLTRB(20, 16, 20, 0);
    if (counts.expected == 0) {
      return SupervisionSummaryBox(
        label: label,
        value: '—',
        caption: 'supervision.reports.none_expected'.tr(),
        meta: meta,
        padding: padding,
      );
    }
    final percent =
        supervisionPercent(counts.submitted * 100 / counts.expected);
    SacStatusSegment segment(SacTone tone, int count, String key) {
      return SacStatusSegment(
        count: count,
        color: SacTonePalette.of(context, tone).solid,
        label: key.tr(args: [supervisionCount(context, count)]),
      );
    }

    return SupervisionSummaryBox(
      label: label,
      value: 'supervision.reports.fraction'.tr(
        args: [
          supervisionCount(context, counts.submitted),
          supervisionCount(context, counts.expected),
        ],
      ),
      caption: percent,
      meta: meta,
      padding: padding,
      segments: [
        segment(SacTone.success, counts.submitted,
            'supervision.reports.legend_delivered'),
        segment(SacTone.warning, counts.pending,
            'supervision.reports.legend_pending'),
        segment(SacTone.error, counts.overdue,
            'supervision.reports.legend_overdue'),
      ],
    );
  }
}

// ── Clubs tab ───────────────────────────────────────────────────────────────

/// Clubs of the loaded pages in the groups a supervisor acts on: with overdue
/// reports, with pending ones, up to date, and last the clubs that expected
/// no report this month (they are not «al día»: nothing was due). The server
/// order is kept inside each group; empty groups are left out.
List<({String labelKey, List<SupervisionClubCompliance> clubs})>
    groupSupervisionClubCompliance(List<SupervisionClubCompliance> clubs) {
  final overdue = <SupervisionClubCompliance>[];
  final pending = <SupervisionClubCompliance>[];
  final upToDate = <SupervisionClubCompliance>[];
  final noneExpected = <SupervisionClubCompliance>[];
  for (final club in clubs) {
    if (club.counts.expected == 0) {
      noneExpected.add(club);
    } else if (club.counts.overdue > 0) {
      overdue.add(club);
    } else if (club.counts.pending > 0) {
      pending.add(club);
    } else {
      upToDate.add(club);
    }
  }
  return [
    if (overdue.isNotEmpty)
      (labelKey: 'supervision.reports.group_overdue', clubs: overdue),
    if (pending.isNotEmpty)
      (labelKey: 'supervision.reports.group_pending', clubs: pending),
    if (upToDate.isNotEmpty)
      (labelKey: 'supervision.reports.group_up_to_date', clubs: upToDate),
    if (noneExpected.isNotEmpty)
      (labelKey: 'supervision.reports.none_expected', clubs: noneExpected),
  ];
}

class SupervisionClubComplianceGroup extends StatelessWidget {
  const SupervisionClubComplianceGroup({
    super.key,
    required this.label,
    required this.clubs,
    required this.showCount,
  });

  final String label;
  final List<SupervisionClubCompliance> clubs;

  /// False while more pages are coming: the count would still change.
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: label,
      dividerIndent: 16,
      count: clubs.length,
      action: showCount ? null : const SizedBox.shrink(),
      children: [for (final club in clubs) _ClubRow(club: club)],
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club});

  final SupervisionClubCompliance club;

  @override
  Widget build(BuildContext context) {
    final counts = club.counts;
    final place = [
      club.sectionNames.join(', '),
      club.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final SacTone tone;
    final HugeIconData icon;
    if (counts.expected == 0) {
      tone = SacTone.muted;
      icon = HugeIcons.strokeRoundedMinusSign;
    } else if (counts.overdue > 0) {
      tone = SacTone.error;
      icon = HugeIcons.strokeRoundedAlert02;
    } else if (counts.pending > 0) {
      tone = SacTone.warning;
      icon = HugeIcons.strokeRoundedClock01;
    } else {
      tone = SacTone.success;
      icon = HugeIcons.strokeRoundedTick02;
    }
    final label = counts.expected == 0
        ? 'supervision.reports.none_expected'.tr()
        : 'supervision.reports.fraction'.tr(
            args: [
              supervisionCount(context, counts.submitted),
              supervisionCount(context, counts.expected),
            ],
          );
    return SacListRow(
      leading: SupervisionMonogram(name: club.clubName),
      title: club.clubName,
      subtitle: place,
      // In the «sin informes esperados» group the eyebrow already says it.
      trailing: counts.expected == 0
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.34,
              ),
              child:
                  SupervisionStatusChip(label: label, icon: icon, tone: tone),
            ),
    );
  }
}

// ── Reports tab ─────────────────────────────────────────────────────────────

/// Reports of the loaded pages grouped by local field (sorted by field, the
/// server order inside each). A report with no field falls in one group of
/// its own, last.
List<({String field, List<SupervisionMonthlyReport> reports})>
    groupSupervisionReportsByField(List<SupervisionMonthlyReport> items) {
  String key(SupervisionMonthlyReport r) => r.localFieldName.trim();
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final fa = key(a.$2).toLowerCase();
      final fb = key(b.$2).toLowerCase();
      if (fa.isEmpty != fb.isEmpty) return fa.isEmpty ? 1 : -1;
      final byField = fa.compareTo(fb);
      return byField != 0 ? byField : a.$1.compareTo(b.$1);
    });
  final groups = <({String field, List<SupervisionMonthlyReport> reports})>[];
  for (final (_, report) in indexed) {
    if (groups.isNotEmpty &&
        groups.last.field.toLowerCase() == key(report).toLowerCase()) {
      groups.last.reports.add(report);
    } else {
      groups.add((field: key(report), reports: [report]));
    }
  }
  return groups;
}

class SupervisionReportGroup extends StatelessWidget {
  const SupervisionReportGroup({
    super.key,
    required this.field,
    required this.reports,
    required this.showCount,
    required this.openingId,
    required this.onOpenPdf,
  });

  final String field;
  final List<SupervisionMonthlyReport> reports;
  final bool showCount;
  final String? openingId;
  final ValueChanged<SupervisionMonthlyReport> onOpenPdf;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: field.isEmpty ? 'supervision.reports.tab_reports'.tr() : field,
      dividerIndent: 16,
      count: reports.length,
      action: showCount ? null : const SizedBox.shrink(),
      children: [
        for (final report in reports)
          SupervisionReportRow(
            report: report,
            opening: openingId == report.id,
            onOpen: report.hasPdf ? () => onOpenPdf(report) : null,
          ),
      ],
    );
  }
}

/// One report: PDF tile, club, club type and the status chip. The whole row
/// opens the PDF; a draft (no PDF) is not tappable.
class SupervisionReportRow extends StatelessWidget {
  const SupervisionReportRow({
    super.key,
    required this.report,
    required this.opening,
    required this.onOpen,
  });

  final SupervisionMonthlyReport report;
  final bool opening;

  /// Null when the report has no PDF yet (a draft).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = report.clubName.isEmpty
        ? 'supervision.reports.unknown_club'.tr()
        : report.clubName;
    final tapped = onOpen;
    return MergeSemantics(
      child: Semantics(
        hint: tapped != null ? 'supervision.reports.view_pdf'.tr() : null,
        child: SacListRow(
          leading: report.hasPdf
              ? const SacListRowIcon(HugeIcons.strokeRoundedPdf01)
              : const SacListRowIcon(
                  HugeIcons.strokeRoundedFile01,
                  tone: SacTone.muted,
                ),
          title: title,
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.clubTypeName.trim().isNotEmpty)
                Text(
                  report.clubTypeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.3,
                    color: c.textSecondary,
                  ),
                ),
              const SizedBox(height: 6),
              _ReportStatusChip(report: report),
            ],
          ),
          // Same footprint for the spinner and the chevron: the row does not
          // shift while the PDF downloads.
          trailing: opening
              ? const SizedBox.square(
                  dimension: 24,
                  child: SacLoadingSmall(),
                )
              : null,
          showChevron: !opening,
          onTap: tapped,
        ),
      ),
    );
  }
}

class _ReportStatusChip extends StatelessWidget {
  const _ReportStatusChip({required this.report});

  final SupervisionMonthlyReport report;

  @override
  Widget build(BuildContext context) {
    // Same tones as the club side: submitted reads info, generated the
    // accent, draft the warning.
    final when = report.submittedAt?.toLocal();
    final (label, icon, tone) = switch (report.status) {
      SupervisionReportStatus.submitted => (
          when == null
              ? 'supervision.reports.status_submitted'.tr()
              : 'supervision.reports.status_submitted_on'
                  .tr(args: [supervisionDayMonth(context, when)]),
          HugeIcons.strokeRoundedTick02,
          SacTone.info,
        ),
      SupervisionReportStatus.generated => (
          'supervision.reports.status_generated'.tr(),
          HugeIcons.strokeRoundedFile01,
          SacTone.accent,
        ),
      SupervisionReportStatus.draft => (
          'supervision.reports.status_draft'.tr(),
          HugeIcons.strokeRoundedNoteEdit,
          SacTone.warning,
        ),
      SupervisionReportStatus.unknown => (
          'supervision.reports.status_unknown'.tr(),
          HugeIcons.strokeRoundedHelpCircle,
          SacTone.muted,
        ),
    };
    return SupervisionStatusChip(label: label, icon: icon, tone: tone);
  }
}

// ── Month picker ────────────────────────────────────────────────────────────

/// Sheet to pick a month: grouped rows, a check on the selected one. Pops
/// the chosen [SupervisionPeriodKey].
class SupervisionPeriodSheet extends StatelessWidget {
  const SupervisionPeriodSheet({
    super.key,
    required this.periods,
    required this.current,
  });

  /// Newest first.
  final List<SupervisionReportPeriod> periods;
  final SupervisionPeriodKey current;

  String? _yearLabel() {
    if (periods.isEmpty) return null;
    final years = periods.map((p) => p.year);
    final first = years.reduce((a, b) => a < b ? a : b);
    final last = years.reduce((a, b) => a > b ? a : b);
    return first == last ? '$first' : '$first-$last';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final year = _yearLabel();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: 'supervision.reports.month_sheet_title'.tr(),
            subtitle: year == null
                ? null
                : 'supervision.reports.month_sheet_subtitle'.tr(args: [year]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Material(
                color: c.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  side: BorderSide(color: c.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < periods.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: c.divider),
                      _PeriodRow(
                        period: periods[i],
                        selected: periods[i].key == current,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.selected});

  final SupervisionReportPeriod period;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final counts = period.counts;
    final line = counts.expected == 0
        ? 'supervision.reports.none_expected'.tr()
        : [
            'supervision.reports.delivered_of'.tr(
              args: [
                supervisionCount(context, counts.submitted),
                supervisionCount(context, counts.expected),
              ],
            ),
            if (counts.overdue > 0)
              'supervision.reports.overdue_count'
                  .tr(args: [supervisionCount(context, counts.overdue)]),
          ].join(' · ');
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: SacInkWell(
          onTap: () => Navigator.of(context).pop(period.key),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            color: selected ? accent.light : null,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        supervisionCapitalizedMonth(
                          context,
                          period.year,
                          period.month,
                        ),
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          height: 1.3,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: accent.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the month picker; resolves to the chosen month or null.
Future<SupervisionPeriodKey?> showSupervisionPeriodSheet(
  BuildContext context, {
  required List<SupervisionReportPeriod> periods,
  required SupervisionPeriodKey current,
}) {
  return showSacSheet<SupervisionPeriodKey>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SupervisionPeriodSheet(periods: periods, current: current),
  );
}
