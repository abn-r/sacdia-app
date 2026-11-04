import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import 'monthly_report_detail_view.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

final _monthlyReportsByYearProvider = Provider.autoDispose
    .family<AsyncValue<List<_YearReportsGroup>>, String>((ref, enrollmentId) {
  final reportsAsync =
      ref.watch(monthlyReportsByEnrollmentProvider(enrollmentId));
  return reportsAsync.whenData(_groupReportsByYear);
});

List<_YearReportsGroup> _groupReportsByYear(List<MonthlyReport> reports) {
  final byYear = <int, List<MonthlyReport>>{};
  for (final report in reports) {
    byYear.putIfAbsent(report.year, () => []).add(report);
  }

  final sortedYears = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final year in sortedYears)
      _YearReportsGroup(year: year, reports: byYear[year]!),
  ];
}

class _YearReportsGroup {
  final int year;
  final List<MonthlyReport> reports;

  const _YearReportsGroup({
    required this.year,
    required this.reports,
  });
}

/// Vista de lista de informes mensuales de un enrollment.
class MonthlyReportsListView extends ConsumerWidget {
  final String enrollmentId;

  const MonthlyReportsListView({
    super.key,
    required this.enrollmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(_monthlyReportsByYearProvider(enrollmentId));
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar:
          SacTopBar(title: 'monthly_reports.list.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => reportsAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (e, _) => SacErrorState(
              title: 'common.error_state.title'.tr(),
              message: userErrorMessage(e),
              onRetry: () => ref
                  .invalidate(monthlyReportsByEnrollmentProvider(enrollmentId)),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return SacEmptyState(
                  icon: HugeIcons.strokeRoundedFile01,
                  title: 'monthly_reports.list.empty_title'.tr(),
                  body: 'monthly_reports.list.empty_subtitle'.tr(),
                );
              }

              return RefreshIndicator(
                color: SacAccent.of(context).color,
                onRefresh: () async => ref.invalidate(
                    monthlyReportsByEnrollmentProvider(enrollmentId)),
                child: ListView(
                  padding: SacTopBar.paddingBelowBar(
                      context, const EdgeInsets.all(20)),
                  children: [
                    for (final group in groups) ...[
                      _YearHeader(year: group.year),
                      const SizedBox(height: 8),
                      ...group.reports.map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReportCard(
                            report: report,
                            onTap: () => Navigator.push(
                              context,
                              SacSharedAxisRoute(
                                builder: (_) => MonthlyReportDetailView(
                                  reportId: report.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Year Header ───────────────────────────────────────────────────────────────

class _YearHeader extends StatelessWidget {
  final int year;

  const _YearHeader({required this.year});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            year.toString(),
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: c.divider, height: 1)),
        ],
      ),
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final MonthlyReport report;
  final VoidCallback? onTap;

  const _ReportCard({required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(report.reportStatus, context.sac);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Month icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusCfg.bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Center(
                child: Text(
                  report.month.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: SacFontSize.headlineSmall,
                    fontWeight: FontWeight.w800,
                    color: statusCfg.fg,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report.monthName} ${report.year}',
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (report.totalActivities != null)
                    Text(
                      'monthly_reports.list.activity_summary'.tr(namedArgs: {
                        'activities': '${report.totalActivities}',
                        'members': '${report.totalMembers ?? 0}',
                      }),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textTertiary,
                      ),
                    ),
                ],
              ),
            ),

            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusCfg.bg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  ),
                  child: Text(
                    report.reportStatus.label,
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      color: statusCfg.fg,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: c.textTertiary,
                  size: 14,
                ),
              ],
            ),
          ],
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

_StatusConfig _statusConfig(MonthlyReportStatus status, SacColors c) {
  switch (status) {
    case MonthlyReportStatus.approved:
    case MonthlyReportStatus.generated:
      return _StatusConfig(bg: c.successContainer, fg: c.onSuccessContainer);
    case MonthlyReportStatus.rejected:
      return _StatusConfig(bg: c.errorContainer, fg: c.onErrorContainer);
    case MonthlyReportStatus.submitted:
      return _StatusConfig(bg: c.infoContainer, fg: c.onInfoContainer);
    case MonthlyReportStatus.draft:
      return _StatusConfig(bg: c.warningContainer, fg: c.onWarningContainer);
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────
