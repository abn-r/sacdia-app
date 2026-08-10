import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../utils/monthly_report_period.dart';
import '../widgets/monthly_report_motion.dart';
import 'monthly_report_detail_view.dart';

class MonthlyReportsVisibleListView extends ConsumerWidget {
  const MonthlyReportsVisibleListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(visibleMonthlyReportsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        title: Text(
          'monthly_reports.visible.title'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => context.go(RouteNames.homeDashboard),
        ),
      ),
      body: reportsAsync.when(
        loading: () => const MonthlyReportSkeletonList(),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(visibleMonthlyReportsProvider),
        ),
        data: (page) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(visibleMonthlyReportsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              MonthlyReportEntrance(child: _NextActionBar(reports: page.items)),
              const SizedBox(height: 22),
              MonthlyReportEntrance(
                index: 1,
                child: Text(
                  'monthly_reports.visible.history_title'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: c.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (page.items.isEmpty)
                MonthlyReportEntrance(index: 2, child: _EmptyHistory(c: c))
              else
                MonthlyReportEntrance(
                  index: 2,
                  child: _GroupedHistoryList(reports: page.items),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NextActionKind { prepare, continueDraft, allSet }

class _NextActionBar extends ConsumerWidget {
  final List<VisibleMonthlyReport> reports;

  const _NextActionBar({required this.reports});

  VisibleMonthlyReport? _periodReport() {
    final target = MonthlyReportPeriod.forPreparation();
    for (final report in reports) {
      if (report.month == target.month && report.year == target.year) {
        return report;
      }
    }
    return null;
  }

  _NextActionKind _kind(VisibleMonthlyReport? period) {
    if (period == null) return _NextActionKind.prepare;
    if (period.reportStatus == MonthlyReportStatus.draft) {
      return _NextActionKind.continueDraft;
    }
    return _NextActionKind.allSet;
  }

  Future<void> _prepareOrOpen(
    BuildContext context,
    WidgetRef ref, {
    VisibleMonthlyReport? existing,
  }) async {
    if (existing != null &&
        existing.reportStatus != MonthlyReportStatus.draft) {
      Navigator.push(
        context,
        SacSharedAxisRoute(
          builder: (_) => MonthlyReportDetailView(reportId: existing.id),
        ),
      );
      return;
    }

    final enrollment = await ref.read(currentEnrollmentProvider.future);
    if (!context.mounted) return;
    final enrollmentId = enrollment?.endpointId;
    if (enrollmentId == null || enrollmentId == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        monthlyReportSnackBar(
          content: Text('monthly_reports.visible.no_enrollment'.tr()),
        ),
      );
      return;
    }

    if (existing != null &&
        existing.reportStatus == MonthlyReportStatus.draft) {
      Navigator.push(
        context,
        SacSharedAxisRoute(
          builder: (_) => MonthlyReportDetailView(reportId: existing.id),
        ),
      );
      return;
    }

    final target = MonthlyReportPeriod.forPreparation();
    final report =
        await ref.read(monthlyReportMutationProvider.notifier).getOrCreateDraft(
              MonthlyReportDraftParams(
                enrollmentId: enrollmentId,
                month: target.month,
                year: target.year,
              ),
            );
    if (!context.mounted) return;
    if (report == null) {
      final state = ref.read(monthlyReportMutationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        monthlyReportSnackBar(
          content: Text(
            state.errorMessage ?? 'monthly_reports.visible.prepare_error'.tr(),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => MonthlyReportDetailView(reportId: report.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final mutation = ref.watch(monthlyReportMutationProvider);
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final target = MonthlyReportPeriod.forPreparation();
    final period = _periodReport();
    final kind = _kind(period);
    final monthRaw = DateFormat.MMMM(
      context.locale.toString(),
    ).format(DateTime(target.year, target.month));
    final monthLabel = monthRaw.isEmpty
        ? monthRaw
        : '${monthRaw[0].toUpperCase()}${monthRaw.substring(1)}';
    final busy = mutation.isLoading || enrollmentAsync.isLoading;

    final String statusLabel;
    final String? ctaLabel;
    switch (kind) {
      case _NextActionKind.prepare:
        statusLabel = 'monthly_reports.visible.next_action_pending'.tr();
        ctaLabel = busy
            ? 'monthly_reports.visible.preparing'.tr()
            : 'monthly_reports.visible.prepare_report'.tr();
      case _NextActionKind.continueDraft:
        statusLabel = 'monthly_reports.visible.next_action_continue'.tr();
        ctaLabel = busy
            ? 'monthly_reports.visible.preparing'.tr()
            : 'monthly_reports.visible.continue_report'.tr();
      case _NextActionKind.allSet:
        statusLabel = 'monthly_reports.visible.next_action_all_set'.tr();
        ctaLabel = null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kind == _NextActionKind.allSet
                  ? const Color(0xFFDCFCE7)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: HugeIcon(
              icon: kind == _NextActionKind.allSet
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedNoteEdit,
              color: kind == _NextActionKind.allSet
                  ? const Color(0xFF15803D)
                  : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthLabel ${target.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: c.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(width: 10),
            SacButton(
              text: ctaLabel,
              size: SacButtonSize.small,
              fullWidth: false,
              icon: kind == _NextActionKind.continueDraft
                  ? HugeIcons.strokeRoundedArrowRight01
                  : HugeIcons.strokeRoundedNoteEdit,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onPressed: busy
                  ? null
                  : () => _prepareOrOpen(context, ref, existing: period),
            ),
          ] else ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'monthly_reports.visible.view_period'.tr(),
              onPressed: period == null
                  ? null
                  : () => _prepareOrOpen(context, ref, existing: period),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textSecondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupedHistoryList extends StatelessWidget {
  final List<VisibleMonthlyReport> reports;

  const _GroupedHistoryList({required this.reports});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: c.border.withValues(alpha: 0.55),
              ),
            _VisibleReportRow(
              report: reports[i],
              onTap: () => Navigator.push(
                context,
                SacSharedAxisRoute(
                  builder: (_) =>
                      MonthlyReportDetailView(reportId: reports[i].id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisibleReportRow extends StatelessWidget {
  final VisibleMonthlyReport report;
  final VoidCallback? onTap;

  const _VisibleReportRow({required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(report.reportStatus);
    final generatedAt = report.generatedAt;
    final clubContext = [
      report.clubName,
      report.clubType,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

    return MonthlyReportPressable(
      onTap: onTap,
      pressedScale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report.monthName} ${report.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: c.text,
                      height: 1.15,
                    ),
                  ),
                  if (clubContext.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      clubContext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                  if (generatedAt != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'monthly_reports.visible.generated_on'.tr(
                        namedArgs: {
                          'date': DateFormat(
                            'd MMM yyyy',
                            context.locale.toString(),
                          ).format(generatedAt.toLocal()),
                        },
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _VisibleStatusChip(
              label: report.reportStatus.label,
              config: statusCfg,
            ),
            const SizedBox(width: 6),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: c.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibleStatusChip extends StatelessWidget {
  final String label;
  final _StatusConfig config;

  const _VisibleStatusChip({required this.label, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          color: config.fg,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final SacColors c;

  const _EmptyHistory({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFile01,
            color: c.textTertiary,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            'monthly_reports.visible.empty_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            'monthly_reports.visible.empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

_StatusConfig _statusConfig(MonthlyReportStatus status) {
  switch (status) {
    case MonthlyReportStatus.approved:
      return const _StatusConfig(bg: Color(0xFFD1FAE5), fg: Color(0xFF047857));
    case MonthlyReportStatus.rejected:
      return _StatusConfig(bg: AppColors.errorLight, fg: AppColors.errorDark);
    case MonthlyReportStatus.submitted:
      return const _StatusConfig(bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8));
    case MonthlyReportStatus.generated:
      return const _StatusConfig(bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D));
    case MonthlyReportStatus.draft:
      return _StatusConfig(bg: AppColors.accentLight, fg: AppColors.accentDark);
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
          ],
        ),
      ),
    );
  }
}
