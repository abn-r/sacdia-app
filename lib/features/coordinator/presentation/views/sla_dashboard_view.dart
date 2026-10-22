import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';

/// Most recent weeks plotted in the throughput chart (two bars per week).
const int _kMaxChartWeeks = 8;

/// Response-time dashboard of the coordinator.
///
/// Evidence KPIs (pending, average days, overdue) and weekly approved/rejected
/// throughput. Camporee and investiture figures (including the retired
/// investiture pipeline) are not part of the mobile coordination surface.
/// Auto-refreshes every 60 seconds and supports pull-to-refresh.
class SLADashboardView extends ConsumerStatefulWidget {
  const SLADashboardView({super.key});

  @override
  ConsumerState<SLADashboardView> createState() => _SLADashboardViewState();
}

class _SLADashboardViewState extends ConsumerState<SLADashboardView> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ref.invalidate(slaDashboardProvider),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(slaDashboardProvider);
    try {
      await ref.read(slaDashboardProvider.future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final slaAsync = ref.watch(slaDashboardProvider);
    final c = context.sac;
    final accent = SacAccent.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.sla.dashboard.title'.tr(),
        frosted: true,
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedAnalytics01,
          size: 22,
          color: accent.color,
        ),
        actions: [
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              onPressed: () => ref.invalidate(slaDashboardProvider),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 20,
                color: c.textTertiary,
              ),
              tooltip: 'coordinator.sla.dashboard.refresh_tooltip'.tr(),
            ),
          ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: slaAsync.when(
              skipLoadingOnReload: slaAsync.hasValue,
              loading: () => const _SlaScroll(
                onRefresh: null,
                children: [_SlaSkeleton()],
              ),
              error: (error, _) => isCoordinatorForbidden(error)
                  ? SacErrorState.forbidden(
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    )
                  : SacErrorState(
                      title: 'coordinator.sla.dashboard.error_title'.tr(),
                      message: 'coordinator.sla.dashboard.error_message'.tr(),
                      onRetry: () => ref.invalidate(slaDashboardProvider),
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    ),
              data: (sla) {
                if (!slaHasData(sla)) {
                  return RefreshIndicator(
                    color: accent.color,
                    edgeOffset: SacTopBar.frostedInset(context),
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: SacTopBar.frostedInset(context),
                            ),
                            child: SacEmptyState(
                              icon: HugeIcons.strokeRoundedAnalytics01,
                              title:
                                  'coordinator.sla.dashboard.empty_title'.tr(),
                              body: 'coordinator.sla.dashboard.empty_body'.tr(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _SlaScroll(
                  onRefresh: _refresh,
                  children: [_SlaContent(sla: sla)],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether [sla] has anything worth drawing. Camporee, investiture and
/// pipeline figures are ignored on purpose: they are not shown on this screen.
@visibleForTesting
bool slaHasData(SlaDashboard sla) {
  final e = sla.evidence;
  return e.pending > 0 ||
      e.overdue > 0 ||
      e.avgDays > 0 ||
      sla.throughput.any((p) => p.approved + p.rejected > 0);
}

class _SlaScroll extends StatelessWidget {
  const _SlaScroll({required this.onRefresh, required this.children});

  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: SacTopBar.paddingBelowBar(
            context,
            EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh!,
      child: scroll,
    );
  }
}

// ── Content ─────────────────────────────────────────────────────────────────

class _SlaContent extends StatelessWidget {
  const _SlaContent({required this.sla});

  final SlaDashboard sla;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final stat = sla.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'coordinator.sla.dashboard.current_status'.tr(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SacStatTile(
                  icon: HugeIcons.strokeRoundedFolder01,
                  value: stat.pending,
                  label: 'coordinator.sla.stat.pending'.tr(),
                  tone: stat.pending > 0
                      ? SacStatTone.accent
                      : SacStatTone.neutral,
                  animate: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SacStatTile(
                  icon: HugeIcons.strokeRoundedClock01,
                  value: stat.avgDays,
                  decimals: 1,
                  label: 'coordinator.sla.stat.avg_days'.tr(),
                  animate: true,
                  animationDelay: const Duration(milliseconds: 80),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SacStatTile(
                  icon: HugeIcons.strokeRoundedAlert02,
                  value: stat.overdue,
                  label: 'coordinator.sla.stat.overdue'.tr(),
                  tone: stat.overdue > 0
                      ? SacStatTone.error
                      : SacStatTone.neutral,
                  animate: true,
                  animationDelay: const Duration(milliseconds: 160),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ThroughputCard(points: sla.throughput),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 12,
                color: c.textTertiary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'coordinator.sla.dashboard.auto_refresh_note'.tr(),
                  style: textTheme.labelSmall?.copyWith(color: c.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Throughput chart ────────────────────────────────────────────────────────

class _ThroughputCard extends StatelessWidget {
  const _ThroughputCard({required this.points});

  final List<ThroughputPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final visible = points.length > _kMaxChartWeeks
        ? points.sublist(points.length - _kMaxChartWeeks)
        : points;
    final canChart = visible.length >= 2;
    final approvedTotal = visible.fold<int>(0, (sum, p) => sum + p.approved);
    final rejectedTotal = visible.fold<int>(0, (sum, p) => sum + p.rejected);

    return SacCard(
      animate: true,
      animationDelay: const Duration(milliseconds: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'coordinator.sla.throughput.title'.tr(),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (canChart) ...[
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendItem(
                  color: c.success,
                  label: 'coordinator.sla.throughput.approved'.tr(),
                  total: approvedTotal,
                ),
                _LegendItem(
                  color: c.error,
                  label: 'coordinator.sla.throughput.rejected'.tr(),
                  total: rejectedTotal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ThroughputChart(points: visible),
          ] else
            Text(
              'coordinator.sla.throughput.not_enough'.tr(),
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.total,
  });

  final Color color;
  final String label;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $total',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _ThroughputChart extends StatelessWidget {
  const _ThroughputChart({required this.points});

  final List<ThroughputPoint> points;

  static String _weekLabel(String week) {
    final match = RegExp(r'(\d{1,2})$').firstMatch(week.trim());
    if (match == null) return week;
    return 'coordinator.sla.throughput.week_short'
        .tr(namedArgs: {'week': '${int.parse(match.group(1)!)}'});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: c.textTertiary);

    final maxValue = points.fold<int>(
      0,
      (m, p) => math.max(m, math.max(p.approved, p.rejected)),
    );
    final step = math.max(1, (maxValue / 4).ceil());
    final maxY = (step * 4).toDouble();

    const radius = BorderRadius.vertical(top: Radius.circular(4));

    return RepaintBoundary(
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step.toDouble(),
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: c.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: labelStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length || value != i) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _weekLabel(points[i].week),
                        style: labelStyle,
                        maxLines: 1,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.surfaceVariant,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                  rod.toY.toInt().toString(),
                  TextStyle(
                    color: rod.color ?? c.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].approved.toDouble(),
                      color: c.success,
                      width: 10,
                      borderRadius: radius,
                    ),
                    BarChartRodData(
                      toY: points[i].rejected.toDouble(),
                      color: c.error,
                      width: 10,
                      borderRadius: radius,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ────────────────────────────────────────────────────────────────

class _SlaSkeleton extends StatelessWidget {
  const _SlaSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    Widget bone(double? width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bone(120, 18),
          const SizedBox(height: 12),
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SacStatTile.skeleton()),
                SizedBox(width: 10),
                Expanded(child: SacStatTile.skeleton()),
                SizedBox(width: 10),
                Expanded(child: SacStatTile.skeleton()),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SacCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bone(150, 14),
                const SizedBox(height: 12),
                bone(180, 12),
                const SizedBox(height: 16),
                bone(double.infinity, 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
