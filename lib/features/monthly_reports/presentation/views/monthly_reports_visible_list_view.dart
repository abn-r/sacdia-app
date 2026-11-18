import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../utils/monthly_report_period.dart';
import '../widgets/monthly_report_history.dart';
import '../widgets/monthly_report_motion.dart';
import 'monthly_report_detail_view.dart';

/// Inicio de Reportes: arriba «Por atender» con el borrador del mes en curso,
/// debajo el historial agrupado por año.
class MonthlyReportsVisibleListView extends ConsumerWidget {
  const MonthlyReportsVisibleListView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(visibleMonthlyReportsProvider);
    ref.invalidate(monthlyReportsByEnrollmentProvider);
    try {
      await ref.read(monthlyReportsHistoryProvider.future);
    } catch (_) {
      // El error queda en el provider y la vista lo muestra.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(monthlyReportsHistoryProvider);
    final hasClubContext = ref.watch(clubContextProvider).value != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'monthly_reports.visible.title'.tr(),
        onBack: () => context.go(RouteNames.homeDashboard),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => reportsAsync.when(
            loading: () => const MonthlyReportSkeletonList(),
            error: (e, _) => SacErrorState(
              title: 'common.error_state.title'.tr(),
              message: userErrorMessage(e),
              onRetry: () => _refresh(ref),
            ),
            data: (reports) => RefreshIndicator(
              color: SacAccent.of(context).color,
              onRefresh: () => _refresh(ref),
              child: _HomeBody(
                reports: reports,
                hasClubContext: hasClubContext,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final List<VisibleMonthlyReport> reports;
  final bool hasClubContext;

  const _HomeBody({required this.reports, required this.hasClubContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = MonthlyReportPeriod.forPreparation();
    VisibleMonthlyReport? current;
    for (final report in reports) {
      if (report.month == target.month && report.year == target.year) {
        current = report;
      }
    }
    final draft =
        current?.reportStatus == MonthlyReportStatus.draft ? current : null;
    // Sin informe del mes: quien tiene club puede empezarlo. Una lista
    // multi-club (coordinación) no tiene un club propio que preparar.
    final canStart = current == null && hasClubContext;
    final showAttention = draft != null || canStart;
    final history =
        draft == null ? reports : reports.where((r) => r != draft).toList();

    final children = <Widget>[
      if (showAttention)
        MonthlyReportEntrance(
          child: _AttentionSection(
            draft: draft,
            month: target.month,
            year: target.year,
          ),
        ),
      if (history.isNotEmpty)
        MonthlyReportEntrance(
          index: 1,
          child: MonthlyReportYearGroups(
            reports: history,
            showClub: !hasClubContext,
            onOpen: (report) => Navigator.push(
              context,
              SacSharedAxisRoute(
                builder: (_) => MonthlyReportDetailView(reportId: report.id),
              ),
            ),
          ),
        )
      else if (!showAttention)
        MonthlyReportEntrance(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: SacEmptyState(
              icon: HugeIcons.strokeRoundedFile01,
              title: 'monthly_reports.visible.empty_title'.tr(),
              body: 'monthly_reports.visible.empty_subtitle'.tr(),
            ),
          ),
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: SacTopBar.paddingBelowBar(
          context, const EdgeInsets.only(top: 0, bottom: 32)),
      children: children,
    );
  }
}

/// «Por atender»: solo el borrador del mes en curso. Si el informe del mes
/// todavía no existe, la fila lo crea al tocarla.
class _AttentionSection extends ConsumerWidget {
  final VisibleMonthlyReport? draft;
  final int month;
  final int year;

  const _AttentionSection({
    required this.draft,
    required this.month,
    required this.year,
  });

  void _open(BuildContext context, String reportId) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => MonthlyReportDetailView(reportId: reportId),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    Enrollment? enrollment;
    try {
      enrollment = await ref.read(currentEnrollmentProvider.future);
    } on Failure {
      enrollment = null;
    }
    if (!context.mounted) return;
    final enrollmentId = enrollment?.endpointId;
    if (enrollmentId == null || enrollmentId == '0') {
      SacSnackBar.show(context, 'monthly_reports.visible.no_enrollment'.tr(),
          behavior: SnackBarBehavior.fixed);
      return;
    }

    final report =
        await ref.read(monthlyReportMutationProvider.notifier).getOrCreateDraft(
              MonthlyReportDraftParams(
                enrollmentId: enrollmentId,
                month: month,
                year: year,
              ),
            );
    if (!context.mounted) return;
    if (report == null) {
      final state = ref.read(monthlyReportMutationProvider);
      SacSnackBar.show(context,
          state.errorMessage ?? 'monthly_reports.visible.prepare_error'.tr(),
          behavior: SnackBarBehavior.fixed);
      return;
    }
    _open(context, report.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = this.draft;
    final busy = ref.watch(monthlyReportMutationProvider).isLoading;
    final monthName = monthlyReportMonthName(month);
    final pending = draft?.pendingSections;

    final String subtitle;
    if (draft == null) {
      subtitle = 'monthly_reports.attention.not_started'.tr();
    } else if (pending != null && pending > 0) {
      subtitle = 'monthly_reports.attention.draft_pending'.plural(pending);
    } else {
      subtitle = 'monthly_reports.attention.draft'.tr();
    }

    return SacGroupedSection(
      label: 'monthly_reports.attention.title'.tr(),
      count: 1,
      children: [
        MonthlyReportAttentionRow(
          key: const Key('monthly-report-attention-row'),
          title: '$monthName $year',
          subtitle: subtitle,
          busy: busy,
          onTap: busy
              ? null
              : () => draft != null
                  ? _open(context, draft.id)
                  : _start(context, ref),
        ),
      ],
    );
  }
}
