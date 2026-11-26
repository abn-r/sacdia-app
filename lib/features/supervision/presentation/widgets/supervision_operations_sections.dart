import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_figures_card.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';

// ── Reports of the month: the box a supervisor reads first ─────────────────

/// «Informes de octubre»: percent, «X de Y secciones» and the delivered /
/// not delivered bar. There is no deadline in the dashboard answer, so the
/// box has no «límite» meta.
class SupervisionOperationsReportsBox extends StatelessWidget {
  const SupervisionOperationsReportsBox({
    super.key,
    required this.summary,
    required this.period,
  });

  final SupervisionOperationsMetrics summary;
  final SupervisionOperationsPeriod period;

  @override
  Widget build(BuildContext context) {
    final month = period.hasReportingMonth
        ? supervisionMonthName(context, period.reportMonth!)
        : null;
    final coverage = summary.reportsCoveragePct;
    final success = SacTonePalette.of(context, SacTone.success).solid;
    final warning = SacTonePalette.of(context, SacTone.warning).solid;

    if (month == null) {
      return SupervisionSummaryBox(
        label: 'supervision.operations.reports'.tr(),
        value: '—',
        caption: 'supervision.operations.reports_none'.tr(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      );
    }
    final expected = summary.reportsExpected;
    return SupervisionSummaryBox(
      label: 'supervision.operations.reports_box_title'.tr(args: [month]),
      value: coverage == null ? '—' : supervisionPercent(coverage),
      caption: expected == 0
          ? 'supervision.operations.reports_not_expected'.tr(args: [month])
          : 'supervision.operations.reports_box_caption'.tr(
              args: [
                supervisionCount(context, summary.reportsSubmitted),
                supervisionCount(context, expected),
              ],
            ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      segments: expected == 0
          ? const []
          : [
              SacStatusSegment(
                count: summary.reportsSubmitted,
                color: success,
                label: 'supervision.operations.legend_delivered'.tr(
                  args: [supervisionCount(context, summary.reportsSubmitted)],
                ),
              ),
              SacStatusSegment(
                count: summary.reportsNotSubmitted,
                color: warning,
                label: 'supervision.operations.legend_undelivered'.tr(
                  args: [
                    supervisionCount(context, summary.reportsNotSubmitted),
                  ],
                ),
              ),
            ],
    );
  }
}

// ── The four figures ────────────────────────────────────────────────────────

/// 2×2 card: operating clubs, active people, people with an app account and
/// class enrollments (the last one opens the by-class sheet).
class SupervisionOperationsFigures extends StatelessWidget {
  const SupervisionOperationsFigures({super.key, required this.summary});

  final SupervisionOperationsMetrics summary;

  @override
  Widget build(BuildContext context) {
    final clubs = summary.operationalClubs + summary.nonOperationalClubs;
    final hasClasses = summary.classes.any((item) => item.enrollmentCount > 0);
    return SupervisionFiguresCard(
      figures: [
        SupervisionFigure(
          value: supervisionCount(context, summary.operationalClubs),
          suffix: 'supervision.operations.of_total'
              .tr(args: [supervisionCount(context, clubs)]),
          label: 'supervision.operations.figure_clubs'.tr(),
        ),
        SupervisionFigure(
          value: supervisionCount(context, summary.peopleActive),
          label: 'supervision.operations.figure_people'.tr(),
        ),
        SupervisionFigure(
          value: supervisionCount(context, summary.accountsActive),
          label: 'supervision.operations.figure_accounts'.tr(),
        ),
        SupervisionFigure(
          value: supervisionCount(context, summary.classEnrollments),
          label: 'supervision.operations.figure_classes'.tr(),
          // The breakdown by class is one tap away, not on the dashboard.
          onTap: hasClasses
              ? () => showSupervisionClassesSheet(context, summary)
              : null,
        ),
      ],
    );
  }
}

// ── One level down ──────────────────────────────────────────────────────────

/// The territories (or clubs) right below the one on screen. The server sorts
/// the ones with gaps first; that order is kept.
class SupervisionOperationsChildren extends StatelessWidget {
  const SupervisionOperationsChildren({
    super.key,
    required this.children,
    required this.canOpenClubs,
  });

  final List<SupervisionOperationsChild> children;
  final bool canOpenClubs;

  @override
  Widget build(BuildContext context) {
    final label = switch (children.first.level) {
      SupervisionTerritoryLevel.division =>
        'supervision.operations.children_division',
      SupervisionTerritoryLevel.union =>
        'supervision.operations.children_union',
      SupervisionTerritoryLevel.localField =>
        'supervision.operations.children_local_field',
      _ => 'supervision.operations.children_club',
    };
    return SacGroupedSection(
      label: label.tr(),
      dividerIndent: 16,
      children: [
        for (final child in children)
          child.level == SupervisionTerritoryLevel.club
              ? _ClubRow(child: child, canOpen: canOpenClubs)
              : _TerritoryRow(child: child),
      ],
    );
  }
}

class _TerritoryRow extends StatelessWidget {
  const _TerritoryRow({required this.child});

  final SupervisionOperationsChild child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final m = child.metrics;
    final clubs = m.operationalClubs + m.nonOperationalClubs;
    final coverage = m.reportsCoveragePct;
    final gaps = m.reportsNotSubmitted;
    final reports = m.reportsExpected == 0
        ? 'supervision.operations.child_reports_none'.tr()
        : 'supervision.operations.child_reports_counts'.tr(
            args: [
              supervisionCount(context, m.reportsSubmitted),
              supervisionCount(context, m.reportsExpected),
            ],
          );
    final operational = 'supervision.operations.child_operational_short'.tr(
      args: [
        supervisionCount(context, m.operationalClubs),
        supervisionCount(context, clubs),
      ],
    );
    final String? route = switch (child.level) {
      SupervisionTerritoryLevel.division =>
        RouteNames.supervisionOperationsScope(divisionId: child.id),
      SupervisionTerritoryLevel.union =>
        RouteNames.supervisionOperationsScope(unionId: child.id),
      SupervisionTerritoryLevel.localField =>
        RouteNames.supervisionOperationsScope(localFieldId: child.id),
      _ => null,
    };
    return SacListRow(
      leading: SacListRowIcon(
        HugeIcons.strokeRoundedBuilding01,
        tone: gaps > 0 ? SacTone.warning : SacTone.accent,
      ),
      title: child.name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$reports · $operational',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              color: c.textSecondary,
            ),
          ),
          if (gaps > 0) ...[
            const SizedBox(height: 6),
            _GapChip(count: gaps),
          ],
        ],
      ),
      trailing: coverage == null ? null : _PercentValue(value: coverage),
      onTap: route == null ? null : () => context.push(route),
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.child, required this.canOpen});

  final SupervisionOperationsChild child;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final m = child.metrics;
    final inactive = m.nonOperationalClubs > 0;
    final gaps = m.reportsNotSubmitted;
    final reports = m.reportsExpected == 0
        ? 'supervision.operations.child_reports_none'.tr()
        : 'supervision.operations.child_club_reports'.tr(
            args: [
              supervisionCount(context, m.reportsSubmitted),
              supervisionCount(context, m.reportsExpected),
            ],
          );
    final activity = (inactive
            ? 'supervision.operations.child_club_inactive'
            : 'supervision.operations.child_club_active')
        .tr();
    return SacListRow(
      leading: SupervisionMonogram(name: child.name),
      title: child.name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$reports · $activity',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              color: c.textSecondary,
            ),
          ),
          if (gaps > 0) ...[
            const SizedBox(height: 6),
            _GapChip(count: gaps),
          ] else if (m.reportsExpected > 0) ...[
            const SizedBox(height: 6),
            SupervisionStatusChip(
              label: 'supervision.hub.up_to_date'.tr(),
              icon: HugeIcons.strokeRoundedTick02,
              tone: SacTone.success,
            ),
          ],
        ],
      ),
      onTap: canOpen
          ? () => context.push(RouteNames.supervisionClubDetail('${child.id}'))
          : null,
    );
  }
}

class _GapChip extends StatelessWidget {
  const _GapChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => SupervisionStatusChip(
        label: 'supervision.operations.child_unsubmitted'
            .tr(args: [supervisionCount(context, count)]),
        icon: HugeIcons.strokeRoundedAlert02,
        tone: SacTone.warning,
      );
}

class _PercentValue extends StatelessWidget {
  const _PercentValue({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => Text(
        supervisionPercent(value),
        maxLines: 1,
        style: TextStyle(
          fontSize: SacFontSize.titleMedium,
          fontWeight: FontWeight.w600,
          color: context.sac.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

// ── The rest of the period ──────────────────────────────────────────────────

class SupervisionOperationsPeriodFacts extends StatelessWidget {
  const SupervisionOperationsPeriodFacts({super.key, required this.summary});

  final SupervisionOperationsMetrics summary;

  @override
  Widget build(BuildContext context) {
    SacValueRow row(String key, int value) => SacValueRow(
          label: 'supervision.operations.$key'.tr(),
          value: supervisionCount(context, value),
        );
    final review = summary.honorsPendingReview;
    final approved = summary.honorsApproved;
    return SacGroupedSection(
      label: 'supervision.operations.period_title'.tr(),
      dividerIndent: 16,
      action: const SizedBox.shrink(),
      children: [
        row('clubs_registered', summary.clubsTotal),
        row('sections_active', summary.operationalSections),
        row('activities', summary.activitiesRegistered),
        // A past year has no honors figures: the rows leave, not a dash.
        if (summary.honorsAvailable && review != null)
          row('honors_review', review),
        if (summary.honorsAvailable && approved != null)
          row('honors_approved', approved),
      ],
    );
  }
}

// ── Enrollments by class ────────────────────────────────────────────────────

void showSupervisionClassesSheet(
  BuildContext context,
  SupervisionOperationsMetrics summary,
) {
  showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ClassesSheet(summary: summary),
  );
}

class _ClassesSheet extends StatelessWidget {
  const _ClassesSheet({required this.summary});

  final SupervisionOperationsMetrics summary;

  @override
  Widget build(BuildContext context) {
    // Server order is club type, then the order of the classes.
    final byType = <int, List<SupervisionClassEnrollments>>{};
    for (final item in summary.classes) {
      if (item.enrollmentCount <= 0) continue;
      byType.putIfAbsent(item.clubTypeId, () => []).add(item);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: 'supervision.operations.classes_sheet_title'.tr(),
            subtitle: 'supervision.operations.classes_sheet_subtitle'.tr(
              args: [
                supervisionCount(context, summary.classEnrollments),
                supervisionCount(context, summary.classDistinctPeople),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in byType.values)
                    SacGroupedSection(
                      label: group.first.clubTypeName,
                      dividerIndent: 16,
                      // The eyebrow total is people enrolled, not rows.
                      count: group.fold<int>(
                        0,
                        (sum, item) => sum + item.enrollmentCount,
                      ),
                      children: [
                        for (final item in group)
                          SacValueRow(
                            label: item.className,
                            value: supervisionCount(
                              context,
                              item.enrollmentCount,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SacButton.outline(
              text: 'common.close'.tr(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
