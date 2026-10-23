import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_report.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/report_compliance.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_reports_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/coordinator_bone.dart';

const Duration _kStagger = Duration(milliseconds: 60);

/// Read-only club reports of the coordinator.
///
/// Report kind and period chips, the period's compliance totals and one card
/// per club with its status (submitted / pending / overdue) and the PDFs the
/// backend serves. No finalize, regenerate or submit actions: coordinators
/// review, they do not run the clubs' reports.
class CoordinatorReportsView extends ConsumerWidget {
  const CoordinatorReportsView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(reportComplianceProvider);
    ref.invalidate(coordinatorReportListProvider);
    try {
      await ref.read(reportComplianceProvider(kWholeYearCompliance).future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final yearAsync = ref.watch(reportComplianceProvider(kWholeYearCompliance));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.reports.title'.tr(),
        frosted: true,
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedChartBarLine,
          size: 22,
          color: accent.color,
        ),
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: yearAsync.when(
              skipLoadingOnReload: yearAsync.hasValue,
              loading: () => const _ReportsScroll(
                onRefresh: null,
                children: [_ReportsSkeleton()],
              ),
              error: (error, _) => isCoordinatorForbidden(error)
                  ? SacErrorState.forbidden(
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    )
                  : SacErrorState(
                      title: 'coordinator.reports.error_title'.tr(),
                      message: 'coordinator.reports.error_message'.tr(),
                      onRetry: () => ref.invalidate(reportComplianceProvider),
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        const EdgeInsets.all(32),
                      ),
                    ),
              data: (year) {
                if (year.clubs.isEmpty) {
                  return RefreshIndicator(
                    color: accent.color,
                    edgeOffset: SacTopBar.frostedInset(context),
                    onRefresh: () => _refresh(ref),
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
                              icon: HugeIcons.strokeRoundedChartBarLine,
                              title: 'coordinator.reports.empty_title'.tr(),
                              body: 'coordinator.reports.empty_body'.tr(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _ReportsScroll(
                  onRefresh: () => _refresh(ref),
                  children: [_ReportsContent(year: year)],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportsScroll extends StatelessWidget {
  const _ReportsScroll({required this.onRefresh, required this.children});

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

// ── Labels ──────────────────────────────────────────────────────────────────

String reportKindLabel(CoordinatorReportKind kind) => switch (kind) {
      CoordinatorReportKind.monthly => 'coordinator.reports.kind.monthly'.tr(),
      CoordinatorReportKind.quarterly =>
        'coordinator.reports.kind.quarterly'.tr(),
      CoordinatorReportKind.annual => 'coordinator.reports.kind.annual'.tr(),
    };

/// "oct 2026" (monthly, UI locale) or "T3 2026" (quarterly).
String reportPeriodLabel(
  BuildContext context,
  CoordinatorReportKind kind,
  ReportPeriodKey period,
) {
  if (kind == CoordinatorReportKind.quarterly) {
    return 'coordinator.reports.quarter_label'.tr(
      namedArgs: {'quarter': '${period.index}', 'year': '${period.year}'},
    );
  }
  final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
  return intl.DateFormat.yMMM(locale)
      .format(DateTime(period.year, period.index));
}

// ── Content ─────────────────────────────────────────────────────────────────

class _ReportsContent extends ConsumerWidget {
  const _ReportsContent({required this.year});

  /// Whole-year compliance: periods for the chips and the defaults.
  final ReportCompliance year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(coordinatorReportKindProvider);
    final picked = ref.watch(coordinatorReportPeriodProvider);
    final periods = year.startedPeriodsFor(kind);
    final fallback = year.defaultPeriodFor(kind);
    final ReportPeriodKey? period = kind.hasPeriods
        ? (picked ??
            (fallback == null
                ? null
                : (year: fallback.year, index: fallback.index)))
        : null;

    final complianceAsync =
        ref.watch(reportComplianceProvider(complianceQueryFor(kind, period)));
    final listQuery = (
      kind: kind,
      year: period?.year,
      period: period?.index,
      ecclesiasticalYearId: kind == CoordinatorReportKind.annual
          ? year.ecclesiasticalYearId
          : null,
    );
    final reportsAsync = ref.watch(coordinatorReportListProvider(listQuery));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KindChips(selected: kind),
        if (kind.hasPeriods && periods.isNotEmpty) ...[
          const SizedBox(height: 4),
          _PeriodChips(kind: kind, periods: periods, selected: period),
        ],
        const SizedBox(height: 16),
        complianceAsync.when(
          skipLoadingOnReload: complianceAsync.hasValue,
          loading: () => const _PeriodSkeleton(),
          error: (error, _) => isCoordinatorForbidden(error)
              ? SacErrorState.forbidden()
              : SacErrorState(
                  title: 'coordinator.reports.error_title'.tr(),
                  message: 'coordinator.reports.error_message'.tr(),
                  onRetry: () => ref.invalidate(reportComplianceProvider),
                ),
          data: (compliance) => _PeriodBody(
            kind: kind,
            compliance: compliance,
            dueAt: _dueAtFor(year, kind, period),
            reportsAsync: reportsAsync,
            onRetryReports: () =>
                ref.invalidate(coordinatorReportListProvider(listQuery)),
          ),
        ),
      ],
    );
  }

  static DateTime? _dueAtFor(
    ReportCompliance year,
    CoordinatorReportKind kind,
    ReportPeriodKey? period,
  ) {
    if (period == null) return null;
    for (final p in year.periodsFor(kind)) {
      if (p.year == period.year && p.index == period.index) return p.dueAt;
    }
    return null;
  }
}

class _KindChips extends ConsumerWidget {
  const _KindChips({required this.selected});

  final CoordinatorReportKind selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CoordinatorReportKind.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kind = CoordinatorReportKind.values[index];
          return SacFilterChip(
            label: reportKindLabel(kind),
            selected: kind == selected,
            onTap: () {
              if (kind == selected) return;
              ref.read(coordinatorReportKindProvider.notifier).state = kind;
              ref.read(coordinatorReportPeriodProvider.notifier).state = null;
            },
          );
        },
      ),
    );
  }
}

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({
    required this.kind,
    required this.periods,
    required this.selected,
  });

  final CoordinatorReportKind kind;
  final List<ReportCompliancePeriod> periods;
  final ReportPeriodKey? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = periods[index];
          final key = (year: p.year, index: p.index);
          return SacFilterChip(
            variant: SacFilterChipVariant.quiet,
            label: reportPeriodLabel(context, kind, key),
            selected: key == selected,
            count: p.counts.overdue > 0 ? p.counts.overdue : null,
            onTap: () =>
                ref.read(coordinatorReportPeriodProvider.notifier).state = key,
          );
        },
      ),
    );
  }
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({
    required this.kind,
    required this.compliance,
    required this.dueAt,
    required this.reportsAsync,
    required this.onRetryReports,
  });

  final CoordinatorReportKind kind;
  final ReportCompliance compliance;
  final DateTime? dueAt;
  final AsyncValue<List<CoordinatorReport>> reportsAsync;
  final VoidCallback onRetryReports;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final counts = compliance.countsFor(kind);
    final clubs = compliance.clubs;
    final reportsByClub = groupReportsByClub(
      clubs,
      reportsAsync.valueOrNull ?? const [],
    );
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComplianceStatTiles(counts: counts),
        if (dueAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'coordinator.reports.due_on'.tr(
              namedArgs: {
                'date': intl.DateFormat.yMMMd(locale).format(dueAt!.toLocal()),
              },
            ),
            style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'coordinator.reports.clubs_title'.tr(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (reportsAsync.hasError && !reportsAsync.isLoading) ...[
          _PdfListError(onRetry: onRetryReports),
          const SizedBox(height: 10),
        ],
        if (clubs.isEmpty)
          SacEmptyState(
            icon: HugeIcons.strokeRoundedChartBarLine,
            title: 'coordinator.reports.period_empty_title'.tr(),
            body: 'coordinator.reports.period_empty_body'.tr(),
          )
        else
          for (var i = 0; i < clubs.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            ClubReportCard(
              kind: kind,
              club: clubs[i],
              reports: reportsByClub[clubs[i].clubId] ?? const [],
              reportsLoading: reportsAsync.isLoading,
              delay: _kStagger * (i < 8 ? i : 8),
            ),
          ],
      ],
    );
  }
}

/// Submitted / pending / overdue tiles. Shared with the hub summary.
class ComplianceStatTiles extends StatelessWidget {
  const ComplianceStatTiles({super.key, required this.counts, this.onTap});

  final ReportCounts counts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SacStatTile(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              value: counts.submitted,
              label: 'coordinator.reports.stat.submitted'.tr(),
              tone: counts.submitted > 0
                  ? SacStatTone.success
                  : SacStatTone.neutral,
              onTap: onTap,
              animate: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SacStatTile(
              icon: HugeIcons.strokeRoundedClock01,
              value: counts.pending,
              label: 'coordinator.reports.stat.pending'.tr(),
              tone: counts.pending > 0
                  ? SacStatTone.warning
                  : SacStatTone.neutral,
              onTap: onTap,
              animate: true,
              animationDelay: _kStagger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SacStatTile(
              icon: HugeIcons.strokeRoundedAlert02,
              value: counts.overdue,
              label: 'coordinator.reports.stat.overdue'.tr(),
              tone:
                  counts.overdue > 0 ? SacStatTone.error : SacStatTone.neutral,
              onTap: onTap,
              animate: true,
              animationDelay: _kStagger * 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill of a club / period. Icon + text, so meaning is not color-only.
class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge({super.key, required this.status});

  final ReportComplianceStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ReportComplianceStatus.submitted => SacBadge.success(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          label: 'coordinator.reports.status.submitted'.tr(),
        ),
      ReportComplianceStatus.pending => SacBadge.warning(
          icon: HugeIcons.strokeRoundedClock01,
          label: 'coordinator.reports.status.pending'.tr(),
        ),
      ReportComplianceStatus.overdue => SacBadge.error(
          icon: HugeIcons.strokeRoundedAlert02,
          label: 'coordinator.reports.status.overdue'.tr(),
        ),
      ReportComplianceStatus.notDue => SacBadge(
          variant: SacBadgeVariant.neutral,
          icon: HugeIcons.strokeRoundedCalendar03,
          label: 'coordinator.reports.status.not_due'.tr(),
        ),
    };
  }
}

class ClubReportCard extends StatelessWidget {
  const ClubReportCard({
    super.key,
    required this.kind,
    required this.club,
    required this.reports,
    required this.reportsLoading,
    this.delay = Duration.zero,
  });

  final CoordinatorReportKind kind;
  final ClubReportCompliance club;
  final List<CoordinatorReport> reports;
  final bool reportsLoading;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final counts = club.countsFor(kind);
    final pdfs = reports.where((r) => r.hasPdf).toList();
    final showProgress = counts.expected > 1;

    return SacCard(
      animate: true,
      animationDelay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.clubName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    if (club.localFieldName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        club.localFieldName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                    if (showProgress) ...[
                      const SizedBox(height: 2),
                      Text(
                        'coordinator.reports.progress'.tr(
                          namedArgs: {
                            'submitted': '${counts.submitted}',
                            'expected': '${counts.expected}',
                          },
                        ),
                        style: textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ReportStatusBadge(status: counts.status),
            ],
          ),
          if (pdfs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: c.border),
            for (final report in pdfs)
              _PdfRow(report: report, clubName: club.clubName),
          ] else if (!reportsLoading && counts.expected > 0) ...[
            const SizedBox(height: 8),
            Text(
              'coordinator.reports.no_pdf'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfRow extends ConsumerStatefulWidget {
  const _PdfRow({required this.report, required this.clubName});

  final CoordinatorReport report;
  final String clubName;

  @override
  ConsumerState<_PdfRow> createState() => _PdfRowState();
}

class _PdfRowState extends ConsumerState<_PdfRow> {
  static const _tag = 'CoordinatorReportsView';
  bool _opening = false;

  String get _label {
    final type = widget.report.clubTypeName?.trim();
    if (widget.report.kind == CoordinatorReportKind.monthly &&
        type != null &&
        type.isNotEmpty) {
      return 'coordinator.reports.view_pdf_type'.tr(namedArgs: {'type': type});
    }
    return 'coordinator.reports.view_pdf'.tr();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final key = (kind: widget.report.kind, id: widget.report.id);
    try {
      final path = await ref.read(coordinatorReportPdfProvider(key).future);
      if (!mounted) return;
      SacPdfViewer.show(context, pdfSource: path, title: widget.clubName);
    } catch (e) {
      AppLogger.w('Error al abrir PDF de informe', tag: _tag, error: e);
      if (!mounted) return;
      SacSnackBar.show(
        context,
        isCoordinatorForbidden(e)
            ? 'coordinator.reports.errors.forbidden'.tr()
            : 'coordinator.reports.pdf_error'.tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    const HugeIconData icon = HugeIcons.strokeRoundedPdf02;

    return SacInkWell(
      onTap: _opening ? null : _open,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              HugeIcon(icon: icon, size: 20, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _label,
                  style: textTheme.bodyMedium?.copyWith(color: c.text),
                ),
              ),
              if (_opening)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SacAccent.of(context).color,
                  ),
                )
              else
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfListError extends StatelessWidget {
  const _PdfListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 20,
            color: c.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'coordinator.reports.list_error'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          SacButton.ghost(
            text: 'common.retry'.tr(),
            onPressed: onRetry,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }
}

// ── Skeletons ───────────────────────────────────────────────────────────────

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoordinatorBone(width: 84, height: 28),
              SizedBox(width: 8),
              CoordinatorBone(width: 96, height: 28),
              SizedBox(width: 8),
              CoordinatorBone(width: 72, height: 28),
            ],
          ),
          SizedBox(height: 16),
          _PeriodSkeleton(),
        ],
      ),
    );
  }
}

class _PeriodSkeleton extends StatelessWidget {
  const _PeriodSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const SacCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoordinatorBone(width: 160, height: 14),
                        SizedBox(height: 6),
                        CoordinatorBone(width: 110, height: 12),
                      ],
                    ),
                  ),
                  CoordinatorBone(width: 72, height: 22),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
