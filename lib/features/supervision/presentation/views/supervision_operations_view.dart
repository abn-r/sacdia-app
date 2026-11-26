import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_operations_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_plain_row.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Indicators of a territory and of what sits right below it.
///
/// With an empty [query] the server answers for the actor's own territory.
/// Opening a row pushes this same screen one level down, so going back
/// climbs one level at a time.
class SupervisionOperationsView extends ConsumerWidget {
  const SupervisionOperationsView({
    super.key,
    this.query = const SupervisionOperationsQuery(),
  });

  final SupervisionOperationsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final provider = supervisionOperationsProvider(query);
    final async = ref.watch(provider);
    // A failed refresh keeps the last dashboard on screen.
    final dashboard = async.value;

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget body;
    if (dashboard == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.operations.error_title'.tr(),
                message: 'supervision.operations.error_message'.tr(),
                onRetry: refresh,
              ),
      );
    } else if (dashboard == null) {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 6,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (dashboard.summary.clubsTotal == 0 &&
        dashboard.children.isEmpty) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'supervision.operations.empty_title'.tr(),
          body: 'supervision.operations.empty_body'.tr(),
        ),
      );
    } else {
      final user = ref.watch(authNotifierProvider.select((v) => v.value));
      body = SupervisionScroll(
        onRefresh: refresh,
        child: _Dashboard(
          dashboard: dashboard,
          showPath: !query.isOwnScope,
          canOpenClubs: hasCapability(user, 'clubs.view_territory'),
        ),
      );
    }

    final scopeName = dashboard?.scope.name.trim() ?? '';
    final ownTitle = 'supervision.operations.title'.tr();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        // One level down the territory is the subject of the screen.
        title: query.isOwnScope || scopeName.isEmpty ? ownTitle : scopeName,
        subtitle: query.isOwnScope
            ? (scopeName.isEmpty ? null : scopeName)
            : _levelLabel(dashboard?.scope.level),
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

String? _levelLabel(SupervisionTerritoryLevel? level) => switch (level) {
      SupervisionTerritoryLevel.division =>
        'supervision.operations.level_division'.tr(),
      SupervisionTerritoryLevel.union =>
        'supervision.operations.level_union'.tr(),
      SupervisionTerritoryLevel.localField =>
        'supervision.operations.level_local_field'.tr(),
      SupervisionTerritoryLevel.club =>
        'supervision.operations.level_club'.tr(),
      _ => null,
    };

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.dashboard,
    required this.showPath,
    required this.canOpenClubs,
  });

  final SupervisionOperationsDashboard dashboard;
  final bool showPath;
  final bool canOpenClubs;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final summary = dashboard.summary;
    final period = dashboard.period;
    // Where this territory hangs from: every level above it.
    final parents = [
      for (final node in dashboard.scope.path)
        if (node.id != dashboard.scope.id ||
            node.level != dashboard.scope.level)
          node.name.trim(),
    ].where((name) => name.isNotEmpty).toList();
    final yearLabel = _yearLabel(period);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPath && parents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              parents.join(' › '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          ),
        _Indicators(summary: summary, period: period),
        if (dashboard.children.isNotEmpty)
          _Children(children: dashboard.children, canOpenClubs: canOpenClubs),
        _PeriodFacts(summary: summary),
        if (yearLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'supervision.operations.year_note'.tr(args: [yearLabel]),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.3,
                color: c.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// "2026", or "2026-2027" when the ecclesiastical year crosses a new year.
String? _yearLabel(SupervisionOperationsPeriod period) {
  final start = period.yearStart?.year;
  final end = period.yearEnd?.year;
  if (start == null && end == null) return null;
  if (start == null || end == null || start == end) return '${start ?? end}';
  return '$start-$end';
}

// ── The four figures a supervisor reads first ───────────────────────────────

class _Indicators extends StatelessWidget {
  const _Indicators({required this.summary, required this.period});

  final SupervisionOperationsMetrics summary;
  final SupervisionOperationsPeriod period;

  @override
  Widget build(BuildContext context) {
    final clubs = summary.operationalClubs + summary.nonOperationalClubs;
    final month = period.hasReportingMonth
        ? supervisionMonthName(context, period.reportMonth!)
        : null;
    final coverage = summary.reportsCoveragePct;
    final rate = summary.operationalRatePct;

    return SacGroupedSection(
      label: 'supervision.operations.indicators_title'.tr(),
      dividerIndent: 16,
      // A count of rows says nothing here.
      action: const SizedBox.shrink(),
      children: [
        SupervisionPlainRow(
          title: 'supervision.operations.reports'.tr(),
          subtitleSpans: [
            if (month == null)
              TextSpan(text: 'supervision.operations.reports_none'.tr())
            else if (summary.reportsExpected == 0)
              TextSpan(
                text: 'supervision.operations.reports_not_expected'
                    .tr(args: [month]),
              )
            else
              _span(
                context,
                'supervision.operations.reports_caption'.tr(
                  args: [
                    supervisionCount(context, summary.reportsSubmitted),
                    supervisionCount(context, summary.reportsExpected),
                    month,
                  ],
                ),
                strong: summary.reportsNotSubmitted > 0,
              ),
          ],
          trailing: SupervisionRowValue(
            coverage == null || month == null
                ? '—'
                : supervisionPercent(coverage),
          ),
          footer: coverage == null || month == null
              ? null
              : _Bar(fraction: coverage / 100),
        ),
        SupervisionPlainRow(
          title: 'supervision.operations.clubs'.tr(),
          subtitleSpans: [
            if (summary.nonOperationalClubs > 0)
              _span(
                context,
                'supervision.operations.clubs_gap'.tr(
                  args: [
                    supervisionCount(context, summary.nonOperationalClubs),
                  ],
                ),
                strong: true,
              )
            else if (clubs > 0)
              TextSpan(text: 'supervision.operations.clubs_all'.tr()),
          ],
          trailing: SupervisionRowValue(
            supervisionCount(context, summary.operationalClubs),
            suffix: 'supervision.operations.of_total'
                .tr(args: [supervisionCount(context, clubs)]),
          ),
          footer: rate == null ? null : _Bar(fraction: rate / 100),
        ),
        SupervisionPlainRow(
          title: 'supervision.operations.people'.tr(),
          subtitle: 'supervision.operations.people_caption'.tr(
            args: [supervisionCount(context, summary.accountsActive)],
          ),
          trailing: SupervisionRowValue(
            supervisionCount(context, summary.peopleActive),
          ),
        ),
        SupervisionPlainRow(
          title: 'supervision.operations.classes'.tr(),
          subtitle: 'supervision.operations.classes_caption'.tr(
            args: [supervisionCount(context, summary.classDistinctPeople)],
          ),
          trailing: SupervisionRowValue(
            supervisionCount(context, summary.classEnrollments),
          ),
          // The breakdown by class is one tap away, not on the dashboard.
          onTap: summary.classes.any((item) => item.enrollmentCount > 0)
              ? () => _showClasses(context, summary.classes)
              : null,
        ),
      ],
    );
  }
}

/// A caption part; [strong] marks the part that needs attention.
TextSpan _span(BuildContext context, String text, {bool strong = false}) {
  return TextSpan(
    text: text,
    style: strong
        ? TextStyle(color: context.sac.text, fontWeight: FontWeight.w500)
        : null,
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SacTweenedBar(
        value: fraction,
        color: SacAccent.of(context).color,
        backgroundColor: context.sac.surfaceVariant,
      ),
    );
  }
}

// ── One level down ──────────────────────────────────────────────────────────

class _Children extends StatelessWidget {
  const _Children({required this.children, required this.canOpenClubs});

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
          SupervisionPlainRow(
            title: child.name,
            subtitleSpans: child.level == SupervisionTerritoryLevel.club
                ? _clubSpans(context, child.metrics)
                : _territorySpans(context, child.metrics),
            onTap: _onTap(context, child),
          ),
      ],
    );
  }

  VoidCallback? _onTap(BuildContext context, SupervisionOperationsChild child) {
    final String? route = switch (child.level) {
      SupervisionTerritoryLevel.division =>
        RouteNames.supervisionOperationsScope(divisionId: child.id),
      SupervisionTerritoryLevel.union =>
        RouteNames.supervisionOperationsScope(unionId: child.id),
      SupervisionTerritoryLevel.localField =>
        RouteNames.supervisionOperationsScope(localFieldId: child.id),
      SupervisionTerritoryLevel.club =>
        canOpenClubs ? RouteNames.supervisionClubDetail('${child.id}') : null,
      _ => null,
    };
    return route == null ? null : () => context.push(route);
  }
}

const TextSpan _dot = TextSpan(text: ' · ');

List<TextSpan> _territorySpans(
  BuildContext context,
  SupervisionOperationsMetrics m,
) {
  final clubs = m.operationalClubs + m.nonOperationalClubs;
  final coverage = m.reportsCoveragePct;
  return [
    if (coverage == null)
      TextSpan(text: 'supervision.operations.child_reports_none'.tr())
    else
      _span(
        context,
        'supervision.operations.child_reports'
            .tr(args: [supervisionPercent(coverage)]),
        strong: m.reportsNotSubmitted > 0,
      ),
    _dot,
    _span(
      context,
      'supervision.operations.child_operational'.tr(
        args: [
          supervisionCount(context, m.operationalClubs),
          supervisionCount(context, clubs),
        ],
      ),
      strong: m.nonOperationalClubs > 0,
    ),
  ];
}

List<TextSpan> _clubSpans(
  BuildContext context,
  SupervisionOperationsMetrics m,
) {
  final inactive = m.nonOperationalClubs > 0;
  return [
    if (m.reportsExpected == 0)
      TextSpan(text: 'supervision.operations.child_reports_none'.tr())
    else
      _span(
        context,
        'supervision.operations.child_club_reports'.tr(
          args: [
            supervisionCount(context, m.reportsSubmitted),
            supervisionCount(context, m.reportsExpected),
          ],
        ),
        strong: m.reportsNotSubmitted > 0,
      ),
    _dot,
    _span(
      context,
      (inactive
              ? 'supervision.operations.child_club_inactive'
              : 'supervision.operations.child_club_active')
          .tr(),
      strong: inactive,
    ),
  ];
}

// ── The rest of the period ──────────────────────────────────────────────────

class _PeriodFacts extends StatelessWidget {
  const _PeriodFacts({required this.summary});

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

void _showClasses(
  BuildContext context,
  List<SupervisionClassEnrollments> classes,
) {
  showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ClassesSheet(classes: classes),
  );
}

class _ClassesSheet extends StatelessWidget {
  const _ClassesSheet({required this.classes});

  final List<SupervisionClassEnrollments> classes;

  @override
  Widget build(BuildContext context) {
    // Server order is club type, then the order of the classes.
    final byType = <int, List<SupervisionClassEnrollments>>{};
    for (final item in classes) {
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
            showClose: true,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
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
        ],
      ),
    );
  }
}
