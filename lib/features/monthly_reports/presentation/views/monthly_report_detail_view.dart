import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';

const _tag = 'MonthlyReportDetailView';

/// Vista de detalle de un informe mensual.
class MonthlyReportDetailView extends ConsumerWidget {
  final int reportId;

  const MonthlyReportDetailView({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(monthlyReportDetailProvider(reportId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'monthly_reports.detail.title'.tr(),
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
        actions: [
          _PdfButton(reportId: reportId),
          const SizedBox(width: 4),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(monthlyReportDetailProvider(reportId)),
        ),
        data: (report) => _ReportDetail(report: report, reportId: reportId),
      ),
    );
  }
}

// ── PDF Button ────────────────────────────────────────────────────────────────

// NOTE: The PDF call is intentionally separate from the detail call.
// The backend endpoint (GET /monthly-reports/:reportId/pdf) generates the PDF
// on demand and streams raw application/pdf bytes — it does not return a signed
// URL or a JSON payload. There is no pdfUrl field in the detail response.
// monthlyReportPdfProvider downloads the PDF via the authenticated Dio client
// (Bearer token in Authorization header, never in the URL), saves it to a temp
// file, and passes the local path to SacPdfViewer. The provider is only
// invoked on user interaction (tap), never at page load.

class _PdfButton extends ConsumerWidget {
  final int reportId;

  const _PdfButton({required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedPdf01,
        color: AppColors.primary,
        size: 22,
      ),
      tooltip: 'monthly_reports.detail.download_pdf_tooltip'.tr(),
      onPressed: () => _openPdf(context, ref),
    );
  }

  Future<void> _openPdf(BuildContext context, WidgetRef ref) async {
    try {
      // Show a loading indicator while downloading.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('monthly_reports.detail.downloading_pdf'.tr()),
            duration: const Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final localPath =
          await ref.read(monthlyReportPdfProvider(reportId).future);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        SacPdfViewer.show(
          context,
          pdfSource: localPath,
                  title: 'monthly_reports.detail.pdf_viewer_title'.tr(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'monthly_reports.detail.pdf_error'.tr(namedArgs: {
                'error': e.toString().replaceFirst('Exception: ', ''),
              }),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Report Detail ─────────────────────────────────────────────────────────────

class _ReportDetail extends ConsumerWidget {
  final MonthlyReport report;
  final int reportId;

  const _ReportDetail({required this.report, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ─────────────────────────────────────────────────────
        _ReportHeaderCard(report: report),
        const SizedBox(height: 20),

        // ── Datos automáticos ───────────────────────────────────────────
        _SectionTitle(title: 'monthly_reports.detail.section_auto_data'.tr()),
        const SizedBox(height: 12),
        _AutoDataGrid(report: report),
        const SizedBox(height: 20),

        // ── Datos manuales ──────────────────────────────────────────────
        if (report.newMembers != null ||
            report.droppedMembers != null ||
            report.notes != null) ...[
          _SectionTitle(title: 'monthly_reports.detail.section_manual_data'.tr()),
          const SizedBox(height: 12),
          _ManualDataCard(report: report),
          const SizedBox(height: 20),
        ],

        // ── PDF button at bottom ────────────────────────────────────────
        SacButton.outline(
          text: 'monthly_reports.detail.view_pdf_button'.tr(),
          icon: HugeIcons.strokeRoundedPdf01,
          onPressed: () async {
            try {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('monthly_reports.detail.downloading_pdf'.tr()),
                    duration: const Duration(seconds: 30),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              final localPath = await ref
                  .read(monthlyReportPdfProvider(reportId).future);

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                SacPdfViewer.show(
                  context,
                  pdfSource: localPath,
          title: 'monthly_reports.detail.pdf_viewer_title'.tr(),
                );
              }
            } catch (e) {
              AppLogger.w('Error al abrir PDF del informe mensual',
                  tag: _tag, error: e);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'monthly_reports.detail.pdf_error'.tr(namedArgs: {
                        'error': e.toString().replaceFirst('Exception: ', ''),
                      }),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Report Header Card ────────────────────────────────────────────────────────

class _ReportHeaderCard extends StatelessWidget {
  final MonthlyReport report;

  const _ReportHeaderCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(report.reportStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusCfg.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                report.month.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 20,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(MonthlyReportStatus status) {
    switch (status) {
      case MonthlyReportStatus.approved:
        return _StatusConfig(
            bg: AppColors.secondaryLight, fg: AppColors.secondaryDark);
      case MonthlyReportStatus.rejected:
        return _StatusConfig(
            bg: AppColors.errorLight, fg: AppColors.errorDark);
      case MonthlyReportStatus.submitted:
        return _StatusConfig(
            bg: AppColors.primaryLight, fg: AppColors.primaryDark);
      case MonthlyReportStatus.draft:
        return _StatusConfig(
            bg: AppColors.accentLight, fg: AppColors.accentDark);
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

// ── Auto Data Grid ────────────────────────────────────────────────────────────

class _AutoDataGrid extends StatelessWidget {
  final MonthlyReport report;

  const _AutoDataGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    // Replaced GridView(shrinkWrap: true) with Column+Row since this grid
    // always renders exactly 4 bounded stat cards inside a parent ListView.
    // shrinkWrap inside a ListView causes O(n²) layout — Column is O(n).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:                 _StatCard(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: 'monthly_reports.detail.stat_activities'.tr(),
                  value: report.totalActivities?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:                 _StatCard(
                  icon: HugeIcons.strokeRoundedUserMultiple,
                  label: 'monthly_reports.detail.stat_total_attendance'.tr(),
                  value: report.totalAttendance?.toString() ?? '—',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:                 _StatCard(
                  icon: HugeIcons.strokeRoundedUser,
                  label: 'monthly_reports.detail.stat_members'.tr(),
                  value: report.totalMembers?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:                 _StatCard(
                  icon: HugeIcons.strokeRoundedAnalytics01,
                  label: 'monthly_reports.detail.stat_attendance_rate'.tr(),
                  value: report.attendanceRate != null
                      ? '${report.attendanceRate!.toStringAsFixed(1)}%'
                      : '—',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HugeIcon(icon: icon, color: AppColors.primary, size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manual Data Card ──────────────────────────────────────────────────────────

class _ManualDataCard extends StatelessWidget {
  final MonthlyReport report;

  const _ManualDataCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.newMembers != null)
            _InfoRow(
              icon: HugeIcons.strokeRoundedUserAdd01,
              label: 'monthly_reports.detail.label_new_members'.tr(),
              value: report.newMembers.toString(),
              valueColor: AppColors.secondary,
            ),
          if (report.newMembers != null &&
              report.droppedMembers != null)
            Divider(height: 20, color: c.divider),
          if (report.droppedMembers != null)
            _InfoRow(
              icon: HugeIcons.strokeRoundedCancel01,
              label: 'monthly_reports.detail.label_dropped_members'.tr(),
              value: report.droppedMembers.toString(),
              valueColor: AppColors.error,
            ),
          if (report.notes != null) ...[
            Divider(height: 20, color: c.divider),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedNoteEdit,
                  color: c.textTertiary,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'monthly_reports.detail.label_notes'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: c.text,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        HugeIcon(icon: icon, color: c.textTertiary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor ?? c.text,
          ),
        ),
      ],
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: context.sac.textSecondary,
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

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
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
