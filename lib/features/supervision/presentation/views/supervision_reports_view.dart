import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_reports_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_reports_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';

/// What the list under the month shows.
enum _Tab { clubs, reports }

/// Monthly reports of the territory, one month at a time: how many came in,
/// which clubs are behind, and the PDF of each report.
class SupervisionReportsView extends ConsumerStatefulWidget {
  const SupervisionReportsView({super.key});

  @override
  ConsumerState<SupervisionReportsView> createState() =>
      _SupervisionReportsViewState();
}

class _SupervisionReportsViewState
    extends ConsumerState<SupervisionReportsView> {
  /// Month picked by hand; null follows the default of the server.
  SupervisionPeriodKey? _picked;
  _Tab _tab = _Tab.clubs;

  /// Report whose PDF is being fetched.
  String? _openingId;

  Future<void> _refreshPeriods() async {
    ref.invalidate(supervisionReportPeriodsProvider);
    try {
      await ref.read(supervisionReportPeriodsProvider.future);
    } catch (_) {
      // The body renders the error.
    }
  }

  Future<void> _refresh(SupervisionPeriodKey period) async {
    await Future.wait([
      _refreshPeriods(),
      ref.read(supervisionComplianceProvider(period).notifier).refresh(),
      // The tab count needs the list even when the other tab is shown.
      ref.read(supervisionMonthlyReportsProvider(period).notifier).refresh(),
    ]);
  }

  Future<void> _pickPeriod(
    SupervisionReportPeriods periods,
    SupervisionPeriodKey current,
  ) async {
    final picked = await showSupervisionPeriodSheet(
      context,
      periods: periods.started,
      current: current,
    );
    if (picked == null || !mounted) return;
    setState(() => _picked = picked);
  }

  Future<void> _openPdf(SupervisionMonthlyReport report) async {
    if (_openingId != null) return;
    setState(() => _openingId = report.id);
    final result = await ref
        .read(supervisionReportsRepositoryProvider)
        .downloadReportPdf(report.id);
    if (!mounted) return;
    setState(() => _openingId = null);
    result.fold(
      (failure) => SacSnackBar.show(
        context,
        isForbiddenFailure(failure)
            ? 'supervision.reports.pdf_forbidden'.tr()
            : 'supervision.reports.pdf_error'.tr(),
        isError: true,
      ),
      (path) => SacPdfViewer.show(
        context,
        pdfSource: path,
        title: report.clubName.isEmpty ? null : report.clubName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final async = ref.watch(supervisionReportPeriodsProvider);
    final periods = async.value;

    // A month picked earlier stays valid only while the server offers it.
    SupervisionPeriodKey? current;
    if (periods != null && periods.started.isNotEmpty) {
      final offered = periods.started.map((p) => p.key).toSet();
      current = _picked != null && offered.contains(_picked)
          ? _picked
          : periods.defaultPeriod?.key ?? periods.started.first.key;
    }
    final canPick = periods != null && periods.started.length > 1;

    final Widget body;
    if (periods == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: _refreshPeriods,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.reports.error_title'.tr(),
                message: supervisionErrorMessage(null),
                onRetry: _refreshPeriods,
              ),
      );
    } else if (periods == null) {
      body = SupervisionScroll(
        onRefresh: _refreshPeriods,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 6,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (current == null) {
      body = SupervisionScroll(
        onRefresh: _refreshPeriods,
        fill: true,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedCalendar03,
          title: 'supervision.reports.no_periods_title'.tr(),
          body: 'supervision.reports.no_periods_body'.tr(),
        ),
      );
    } else {
      final key = current;
      body = _PeriodBody(
        // A new month starts at the top with its own lists.
        key: ValueKey(key),
        period: periods.started.firstWhere((p) => p.key == key),
        tab: _tab,
        openingId: _openingId,
        onTab: (tab) => setState(() => _tab = tab),
        onRefresh: () => _refresh(key),
        onOpenPdf: _openPdf,
      );
    }

    final title = 'supervision.reports.title'.tr();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: current == null
          ? SacTopBar(title: title, frosted: true)
          : SacTopBar(
              // The month is the subject: tapping it opens the month sheet.
              title: supervisionCapitalizedMonth(
                context,
                current.year,
                current.month,
              ),
              subtitle: title,
              titleTrailing: canPick
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 20,
                      color: c.textSecondary,
                    )
                  : null,
              onTitleTap: canPick ? () => _pickPeriod(periods, current!) : null,
              frosted: true,
            ),
      body: SacFrostedVeil(child: body),
    );
  }
}

// ── One month ───────────────────────────────────────────────────────────────

class _PeriodBody extends ConsumerWidget {
  const _PeriodBody({
    super.key,
    required this.period,
    required this.tab,
    required this.openingId,
    required this.onTab,
    required this.onRefresh,
    required this.onOpenPdf,
  });

  final SupervisionReportPeriod period;
  final _Tab tab;
  final String? openingId;
  final ValueChanged<_Tab> onTab;
  final Future<void> Function() onRefresh;
  final ValueChanged<SupervisionMonthlyReport> onOpenPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compliance = ref.watch(supervisionComplianceProvider(period.key));
    final reports = ref.watch(supervisionMonthlyReportsProvider(period.key));
    // A count is shown once the list has answered; a failed list has none.
    final clubsCount = compliance.isLoading && compliance.clubs.isEmpty
        ? null
        : (compliance.error != null && compliance.clubs.isEmpty
            ? null
            : compliance.total);
    final reportsCount = reports.isLoading && reports.items.isEmpty
        ? null
        : (reports.error != null && reports.items.isEmpty
            ? null
            : reports.total);

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: SacTopBar.paddingBelowBar(context, EdgeInsets.zero),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kSupervisionMaxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SupervisionReportsMonthBox(
                          // The page of clubs carries the totals of the
                          // month; until it lands the selector's own figures
                          // stand in.
                          counts: compliance.totals ?? period.counts,
                          dueAt: period.dueAt,
                        ),
                        SupervisionSegmentedControl<_Tab>(
                          selected: tab,
                          onChanged: onTab,
                          segments: [
                            SupervisionSegment(
                              value: _Tab.clubs,
                              label: 'supervision.reports.tab_by_club'.tr(),
                              count: clubsCount,
                            ),
                            SupervisionSegment(
                              value: _Tab.reports,
                              label: 'supervision.reports.tab_reports'.tr(),
                              count: reportsCount,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Centered column on a tablet.
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final side = (constraints.crossAxisExtent -
                        kSupervisionMaxContentWidth) /
                    2;
                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: side > 0 ? side : 0,
                  ),
                  sliver: switch (tab) {
                    _Tab.clubs => _ClubsSliver(period: period.key),
                    _Tab.reports => _ReportsSliver(
                        period: period.key,
                        openingId: openingId,
                        onOpenPdf: onOpenPdf,
                      ),
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared list states ──────────────────────────────────────────────────────

const EdgeInsets _kListPadding = EdgeInsets.fromLTRB(20, 12, 20, 32);

Widget _loadingSliver() => const SliverPadding(
      padding: _kListPadding,
      sliver: SliverToBoxAdapter(
        child: SacSkeletonList(
          itemCount: 5,
          leading: false,
          scrollable: false,
        ),
      ),
    );

Widget _errorSliver(Object error, VoidCallback onRetry) => SliverFillRemaining(
      hasScrollBody: false,
      child: isForbiddenFailure(error)
          ? const ForbiddenView()
          : SacErrorState(
              title: 'supervision.reports.error_title'.tr(),
              message: supervisionErrorMessage(null),
              onRetry: onRetry,
            ),
    );

// ── Compliance by club ──────────────────────────────────────────────────────

class _ClubsSliver extends ConsumerWidget {
  const _ClubsSliver({required this.period});

  final SupervisionPeriodKey period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisionComplianceProvider(period));
    final notifier = ref.read(supervisionComplianceProvider(period).notifier);

    if (state.clubs.isEmpty && state.error != null) {
      return _errorSliver(state.error!, notifier.refresh);
    }
    if (state.clubs.isEmpty && state.isLoading) return _loadingSliver();
    if (state.clubs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: SacEmptyState(
          title: 'supervision.reports.empty_clubs_title'.tr(),
          body: 'supervision.reports.empty_clubs_body'.tr(),
        ),
      );
    }

    final groups = groupSupervisionClubCompliance(state.clubs);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 32),
      sliver: SliverList.builder(
        itemCount: groups.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= groups.length) {
            return SupervisionLoadMoreFooter(
              loading: state.isLoadingMore,
              failed: state.error != null,
              errorMessage: 'supervision.reports.load_more_error'.tr(),
              onLoadMore: notifier.loadMore,
            );
          }
          final group = groups[index];
          return SupervisionClubComplianceGroup(
            label: group.labelKey.tr(),
            clubs: group.clubs,
            // More pages can still add clubs to a group.
            showCount: !state.hasMore,
          );
        },
      ),
    );
  }
}

// ── The reports of the month ────────────────────────────────────────────────

class _ReportsSliver extends ConsumerWidget {
  const _ReportsSliver({
    required this.period,
    required this.openingId,
    required this.onOpenPdf,
  });

  final SupervisionPeriodKey period;
  final String? openingId;
  final ValueChanged<SupervisionMonthlyReport> onOpenPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisionMonthlyReportsProvider(period));
    final notifier =
        ref.read(supervisionMonthlyReportsProvider(period).notifier);

    if (state.items.isEmpty && state.error != null) {
      return _errorSliver(state.error!, notifier.refresh);
    }
    if (state.items.isEmpty && state.isLoading) return _loadingSliver();
    if (state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: SacEmptyState(
          icon: HugeIcons.strokeRoundedPdf01,
          title: 'supervision.reports.empty_reports_title'.tr(),
          body: 'supervision.reports.empty_reports_body'.tr(),
        ),
      );
    }

    final groups = groupSupervisionReportsByField(state.items);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 32),
      sliver: SliverList.builder(
        itemCount: groups.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= groups.length) {
            return SupervisionLoadMoreFooter(
              loading: state.isLoadingMore,
              failed: state.error != null,
              errorMessage: 'supervision.reports.load_more_error'.tr(),
              onLoadMore: notifier.loadMore,
            );
          }
          final group = groups[index];
          return SupervisionReportGroup(
            field: group.field,
            reports: group.reports,
            showCount: !state.hasMore,
            openingId: openingId,
            onOpenPdf: onOpenPdf,
          );
        },
      ),
    );
  }
}
