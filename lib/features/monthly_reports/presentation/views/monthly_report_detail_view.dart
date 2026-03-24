import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';

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
          'Detalle del informe',
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
      tooltip: 'Descargar PDF',
      onPressed: () => _openPdf(context, ref),
    );
  }

  Future<void> _openPdf(BuildContext context, WidgetRef ref) async {
    try {
      final pdfUrlAsync =
          await ref.read(monthlyReportPdfUrlProvider(reportId).future);
      final uri = Uri.parse(pdfUrlAsync);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el PDF'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al obtener el PDF: ${e.toString().replaceFirst("Exception: ", "")}',
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
    final c = context.sac;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ─────────────────────────────────────────────────────
        _ReportHeaderCard(report: report),
        const SizedBox(height: 20),

        // ── Datos automáticos ───────────────────────────────────────────
        _SectionTitle(title: 'Datos calculados automáticamente'),
        const SizedBox(height: 12),
        _AutoDataGrid(report: report),
        const SizedBox(height: 20),

        // ── Datos manuales ──────────────────────────────────────────────
        if (report.newMembers != null ||
            report.droppedMembers != null ||
            report.notes != null) ...[
          _SectionTitle(title: 'Datos adicionales'),
          const SizedBox(height: 12),
          _ManualDataCard(report: report),
          const SizedBox(height: 20),
        ],

        // ── PDF button at bottom ────────────────────────────────────────
        SacButton.outline(
          text: 'Descargar PDF',
          icon: HugeIcons.strokeRoundedPdf01,
          onPressed: () async {
            try {
              final url = await ref
                  .read(monthlyReportPdfUrlProvider(reportId).future);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            } catch (_) {}
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          icon: HugeIcons.strokeRoundedCalendar01,
          label: 'Actividades',
          value: report.totalActivities?.toString() ?? '—',
        ),
        _StatCard(
          icon: HugeIcons.strokeRoundedUserMultiple,
          label: 'Asistencia total',
          value: report.totalAttendance?.toString() ?? '—',
        ),
        _StatCard(
          icon: HugeIcons.strokeRoundedUser,
          label: 'Miembros',
          value: report.totalMembers?.toString() ?? '—',
        ),
        _StatCard(
          icon: HugeIcons.strokeRoundedAnalytics01,
          label: 'Tasa asistencia',
          value: report.attendanceRate != null
              ? '${report.attendanceRate!.toStringAsFixed(1)}%'
              : '—',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final dynamic icon;
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
              label: 'Nuevos miembros',
              value: report.newMembers.toString(),
              valueColor: AppColors.secondary,
            ),
          if (report.newMembers != null &&
              report.droppedMembers != null)
            Divider(height: 20, color: c.divider),
          if (report.droppedMembers != null)
            _InfoRow(
              icon: HugeIcons.strokeRoundedCancel01,
              label: 'Bajas',
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
                        'Notas',
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
  final dynamic icon;
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
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
