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
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'monthly_reports.visible.title'.tr(),
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 18, color: c.text),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: c.text,
              size: 22),
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
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: page.items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const MonthlyReportEntrance(child: _ReportsHeroCard());
              }
              final report = page.items[index - 1];
              return MonthlyReportEntrance(
                index: index,
                child: _VisibleReportCard(
                  report: report,
                  onTap: () => Navigator.push(
                    context,
                    SacSharedAxisRoute(
                      builder: (_) =>
                          MonthlyReportDetailView(reportId: report.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportsHeroCard extends ConsumerWidget {
  const _ReportsHeroCard();

  Future<void> _prepare(BuildContext context, WidgetRef ref) async {
    final enrollment = await ref.read(currentEnrollmentProvider.future);
    if (!context.mounted) return;
    final enrollmentId = enrollment?.endpointId;
    if (enrollmentId == null || enrollmentId == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('monthly_reports.visible.no_enrollment'.tr()),
            behavior: SnackBarBehavior.floating),
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
        SnackBar(
            content: Text(state.errorMessage ??
                'monthly_reports.visible.prepare_error'.tr()),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.push(
      context,
      SacSharedAxisRoute(
          builder: (_) => MonthlyReportDetailView(reportId: report.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final mutation = ref.watch(monthlyReportMutationProvider);
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final target = MonthlyReportPeriod.forPreparation();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.16),
          AppColors.accent.withValues(alpha: 0.12)
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16)),
            child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                color: Colors.white,
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text('monthly_reports.visible.hero_title'.tr(),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: c.text))),
        ]),
        const SizedBox(height: 10),
        Text(
          'monthly_reports.visible.hero_subtitle'.tr(namedArgs: {
            'month': DateFormat.MMMM(context.locale.toString())
                .format(DateTime(target.year, target.month)),
            'year': target.year.toString(),
          }),
          style: TextStyle(color: c.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: SacButton.primary(
            key: ValueKey(mutation.isLoading || enrollmentAsync.isLoading),
            text: mutation.isLoading
                ? 'monthly_reports.visible.preparing'.tr()
                : 'monthly_reports.visible.prepare_report'.tr(),
            icon: HugeIcons.strokeRoundedNoteEdit,
            onPressed: mutation.isLoading || enrollmentAsync.isLoading
                ? null
                : () => _prepare(context, ref),
          ),
        ),
      ]),
    );
  }
}

class _VisibleReportCard extends StatelessWidget {
  final VisibleMonthlyReport report;
  final VoidCallback? onTap;

  const _VisibleReportCard({required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(report.reportStatus);
    final generatedAt = report.generatedAt;
    final clubContext = [report.clubName, report.clubType]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _MonthNumberBadge(month: report.month),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${report.monthName} ${report.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.25,
                              color: c.text,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _VisibleStatusChip(
                          label: report.reportStatus.label,
                          config: statusCfg,
                        ),
                      ],
                    ),
                    if (clubContext.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        clubContext,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (generatedAt != null) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendarCheckOut01,
                            color: c.textTertiary,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'monthly_reports.visible.generated_on'.tr(
                                namedArgs: {
                                  'date': DateFormat('dd/MM/yyyy')
                                      .format(generatedAt.toLocal()),
                                },
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                color: c.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border.withValues(alpha: 0.58)),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: c.textTertiary,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthNumberBadge extends StatelessWidget {
  final int month;

  const _MonthNumberBadge({required this.month});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          month.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: AppColors.primary,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
          color: config.fg,
        ),
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
      return const _StatusConfig(
        bg: Color(0xFFD1FAE5),
        fg: Color(0xFF047857),
      );
    case MonthlyReportStatus.rejected:
      return _StatusConfig(bg: AppColors.errorLight, fg: AppColors.errorDark);
    case MonthlyReportStatus.submitted:
      return const _StatusConfig(
        bg: Color(0xFFDBEAFE),
        fg: Color(0xFF1D4ED8),
      );
    case MonthlyReportStatus.generated:
      return const _StatusConfig(
        bg: Color(0xFFDCFCE7),
        fg: Color(0xFF15803D),
      );
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
        ]),
      ),
    );
  }
}
