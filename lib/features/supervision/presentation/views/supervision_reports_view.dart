import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_reports_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_load_more_footer.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

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
      if (_tab == _Tab.reports)
        ref.read(supervisionMonthlyReportsProvider(period).notifier).refresh(),
    ]);
  }

  Future<void> _pickPeriod(
    SupervisionReportPeriods periods,
    SupervisionPeriodKey current,
  ) async {
    final picked = await showSacSheet<SupervisionPeriodKey>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PeriodSheet(periods: periods.started, current: current),
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
    } else {
      // A month picked earlier stays valid only while the server offers it.
      final offered = periods.started.map((p) => p.key).toSet();
      final current = _picked != null && offered.contains(_picked)
          ? _picked
          : periods.defaultPeriod?.key ??
              (periods.started.isEmpty ? null : periods.started.first.key);
      if (current == null) {
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
        body = _PeriodBody(
          // A new month starts at the top with its own lists.
          key: ValueKey(current),
          period: periods.started.firstWhere((p) => p.key == current),
          tab: _tab,
          openingId: _openingId,
          canPick: periods.started.length > 1,
          onPick: () => _pickPeriod(periods, current),
          onTab: (tab) => setState(() => _tab = tab),
          onRefresh: () => _refresh(current),
          onOpenPdf: _openPdf,
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'supervision.reports.title'.tr(),
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
    required this.canPick,
    required this.onPick,
    required this.onTab,
    required this.onRefresh,
    required this.onOpenPdf,
  });

  final SupervisionReportPeriod period;
  final _Tab tab;
  final String? openingId;
  final bool canPick;
  final VoidCallback onPick;
  final ValueChanged<_Tab> onTab;
  final Future<void> Function() onRefresh;
  final ValueChanged<SupervisionMonthlyReport> onOpenPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compliance = ref.watch(supervisionComplianceProvider(period.key));

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
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.only(top: 12),
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kSupervisionMaxContentWidth,
                    ),
                    child: _PeriodHeader(
                      period: period,
                      // The page of clubs carries the totals of the month;
                      // until it lands the selector's own figures stand in.
                      counts: compliance.totals ?? period.counts,
                      canPick: canPick,
                      onPick: onPick,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TabChips(selected: tab, onSelected: onTab),
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

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.period,
    required this.counts,
    required this.canPick,
    required this.onPick,
  });

  final SupervisionReportPeriod period;
  final SupervisionReportCounts counts;
  final bool canPick;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final month = Text(
      _capitalize(supervisionMonthYear(context, period.year, period.month)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.headlineMedium,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.2,
        color: c.text,
      ),
    );
    final due = period.dueAt;
    final strong = TextStyle(color: c.text, fontWeight: FontWeight.w500);

    // Full width: under a `Center` a bare column shrinks to its widest line
    // and drifts away from the gutter.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPick)
            Semantics(
              button: true,
              hint: 'supervision.reports.change_month'.tr(),
              child: SacPressable(
                onTap: onPick,
                semanticButton: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: month),
                      const SizedBox(width: 6),
                      ExcludeSemantics(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 20,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(alignment: Alignment.centerLeft, child: month),
            ),
          const SizedBox(height: 2),
          // The month in one sentence; what is late reads darker.
          Text.rich(
            TextSpan(
              children: [
                if (counts.expected == 0)
                  TextSpan(text: 'supervision.reports.none_expected'.tr())
                else ...[
                  TextSpan(
                    text: 'supervision.reports.submitted_of'.tr(
                      args: [
                        supervisionCount(context, counts.submitted),
                        supervisionCount(context, counts.expected),
                      ],
                    ),
                  ),
                  if (counts.overdue > 0) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: 'supervision.reports.overdue_count'.tr(
                        args: [supervisionCount(context, counts.overdue)],
                      ),
                      style: strong,
                    ),
                  ],
                  if (counts.pending > 0) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: 'supervision.reports.pending_count'.tr(
                        args: [supervisionCount(context, counts.pending)],
                      ),
                    ),
                  ],
                ],
              ],
            ),
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              height: 1.35,
              color: c.textSecondary,
            ),
          ),
          if (due != null) ...[
            const SizedBox(height: 2),
            Text(
              'supervision.reports.due_on'.tr(
                args: [supervisionShortDate(context, due.toLocal())],
              ),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.3,
                color: c.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

class _TabChips extends StatelessWidget {
  const _TabChips({required this.selected, required this.onSelected});

  final _Tab selected;
  final ValueChanged<_Tab> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (_Tab.clubs, 'supervision.reports.tab_clubs'),
      (_Tab.reports, 'supervision.reports.tab_reports'),
    ];
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (tab, labelKey) = options[index];
          return Center(
            child: SacFilterChip(
              label: labelKey.tr(),
              selected: tab == selected,
              onTap: () => onSelected(tab),
            ),
          );
        },
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

    final clubs = state.clubs;
    return SliverPadding(
      padding: _kListPadding,
      sliver: SliverList.builder(
        itemCount: clubs.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= clubs.length) {
            return SupervisionLoadMoreFooter(
              loading: state.isLoadingMore,
              failed: state.error != null,
              errorMessage: 'supervision.reports.load_more_error'.tr(),
              onLoadMore: notifier.loadMore,
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClubComplianceCard(club: clubs[index]),
          );
        },
      ),
    );
  }
}

class _ClubComplianceCard extends StatelessWidget {
  const _ClubComplianceCard({required this.club});

  final SupervisionClubCompliance club;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = club.counts;
    final place = [
      club.sectionNames.join(', '),
      club.localFieldName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final behind = counts.overdue > 0;

    return MergeSemantics(
      child: SacCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              club.clubName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                place,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.3,
                  color: c.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _complianceLine(context, counts),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: behind ? c.text : c.textSecondary,
                fontWeight: behind ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "2 de 3 entregados · 1 vencido": what is late goes last and reads darker.
String _complianceLine(BuildContext context, SupervisionReportCounts counts) {
  if (counts.expected == 0) return 'supervision.reports.none_expected'.tr();
  return [
    'supervision.reports.submitted_of'.tr(
      args: [
        supervisionCount(context, counts.submitted),
        supervisionCount(context, counts.expected),
      ],
    ),
    if (counts.pending > 0)
      'supervision.reports.pending_count'
          .tr(args: [supervisionCount(context, counts.pending)]),
    if (counts.overdue > 0)
      'supervision.reports.overdue_count'
          .tr(args: [supervisionCount(context, counts.overdue)]),
  ].join(' · ');
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

    final items = state.items;
    return SliverPadding(
      padding: _kListPadding,
      sliver: SliverList.builder(
        itemCount: items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return SupervisionLoadMoreFooter(
              loading: state.isLoadingMore,
              failed: state.error != null,
              errorMessage: 'supervision.reports.load_more_error'.tr(),
              onLoadMore: notifier.loadMore,
            );
          }
          final report = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReportCard(
              report: report,
              opening: openingId == report.id,
              onOpen: report.hasPdf ? () => onOpenPdf(report) : null,
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
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
    final place = [report.clubTypeName, report.localFieldName]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ');
    final submitted = report.status == SupervisionReportStatus.submitted;
    final when = report.submittedAt?.toLocal();
    final status = switch (report.status) {
      SupervisionReportStatus.submitted => when == null
          ? 'supervision.reports.status_submitted'.tr()
          : 'supervision.reports.status_submitted_on'
              .tr(args: [supervisionShortDate(context, when)]),
      SupervisionReportStatus.generated =>
        'supervision.reports.status_generated'.tr(),
      SupervisionReportStatus.draft => 'supervision.reports.status_draft'.tr(),
      SupervisionReportStatus.unknown =>
        'supervision.reports.status_unknown'.tr(),
    };

    return MergeSemantics(
      child: Semantics(
        button: onOpen != null,
        hint: onOpen != null ? 'supervision.reports.view_pdf'.tr() : null,
        child: SacCard(
          onTap: onOpen,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.clubName.isEmpty
                          ? 'supervision.reports.unknown_club'.tr()
                          : report.clubName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          height: 1.3,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: submitted ? c.text : c.textSecondary,
                        fontWeight:
                            submitted ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(width: 12),
                // Same footprint for the icon and the spinner: the card does
                // not shift while the PDF downloads.
                SizedBox.square(
                  dimension: 24,
                  child: opening
                      ? const SacLoadingSmall()
                      : ExcludeSemantics(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedPdf01,
                            size: 22,
                            color: c.textSecondary,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Month picker ────────────────────────────────────────────────────────────

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.periods, required this.current});

  /// Newest first.
  final List<SupervisionReportPeriod> periods;
  final SupervisionPeriodKey current;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: 'supervision.reports.month_sheet_title'.tr()),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: periods.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                indent: 24,
                color: c.divider,
              ),
              itemBuilder: (context, index) {
                final period = periods[index];
                final selected = period.key == current;
                final counts = period.counts;
                return MergeSemantics(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    child: SacInkWell(
                      onTap: () => Navigator.of(context).pop(period.key),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 20, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _capitalize(
                                        supervisionMonthYear(
                                          context,
                                          period.year,
                                          period.month,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: SacFontSize.titleMedium,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _complianceLine(context, counts),
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
                                    color: SacAccent.of(context).color,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
