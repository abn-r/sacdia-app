import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import 'monthly_report_detail_view.dart';

/// Vista de lista de informes mensuales de un enrollment.
class MonthlyReportsListView extends ConsumerWidget {
  final int enrollmentId;

  const MonthlyReportsListView({
    super.key,
    required this.enrollmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync =
        ref.watch(monthlyReportsByEnrollmentProvider(enrollmentId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Informes Mensuales',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref
              .invalidate(monthlyReportsByEnrollmentProvider(enrollmentId)),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return _EmptyBody();
          }

          // Group reports by year
          final byYear = <int, List<MonthlyReport>>{};
          for (final r in reports) {
            byYear.putIfAbsent(r.year, () => []).add(r);
          }
          final sortedYears = byYear.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(
                monthlyReportsByEnrollmentProvider(enrollmentId)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final year in sortedYears) ...[
                  _YearHeader(year: year),
                  const SizedBox(height: 8),
                  ...byYear[year]!.map(
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
              fontSize: 14,
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
    final statusCfg = _statusConfig(report.reportStatus);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  report.month.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 18,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (report.totalActivities != null)
                    Text(
                      '${report.totalActivities} actividades · '
                      '${report.totalMembers ?? 0} miembros',
                      style: TextStyle(
                        fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusCfg.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.reportStatus.label,
                    style: TextStyle(
                      fontSize: 11,
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

  _StatusConfig _statusConfig(MonthlyReportStatus status) {
    switch (status) {
      case MonthlyReportStatus.approved:
        return _StatusConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
        );
      case MonthlyReportStatus.rejected:
        return _StatusConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
        );
      case MonthlyReportStatus.submitted:
        return _StatusConfig(
          bg: AppColors.primaryLight,
          fg: AppColors.primaryDark,
        );
      case MonthlyReportStatus.draft:
        return _StatusConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
        );
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFile01,
              color: c.textTertiary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin informes mensuales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los informes mensuales aparecerán aquí una vez que estén disponibles.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
