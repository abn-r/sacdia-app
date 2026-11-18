import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/monthly_report.dart';
import '../utils/monthly_report_format.dart';
import 'monthly_report_status_chip.dart';

/// Línea corta bajo el mes de una fila del historial ("Enviado el 6 nov").
/// `null` cuando no hay nada útil que decir: no se escribe un guion.
String? monthlyReportDetailLine(
  BuildContext context,
  VisibleMonthlyReport report, {
  bool showClub = false,
}) {
  String? date(DateTime? value) =>
      value == null ? null : monthlyReportShortDate(context, value);

  final String? status;
  switch (report.reportStatus) {
    case MonthlyReportStatus.draft:
      final pending = report.pendingSections;
      status = pending != null && pending > 0
          ? monthlyReportPendingSections(pending)
          : null;
    case MonthlyReportStatus.generated:
      status = 'monthly_reports.history.ready_to_send'.tr();
    case MonthlyReportStatus.submitted:
    case MonthlyReportStatus.approved:
      final sent = date(report.submittedAt);
      final generated = date(report.generatedAt);
      status = sent != null
          ? 'monthly_reports.history.sent_on'.tr(namedArgs: {'date': sent})
          : generated != null
              ? 'monthly_reports.visible.generated_on'
                  .tr(namedArgs: {'date': generated})
              : null;
    case MonthlyReportStatus.rejected:
      status = 'monthly_reports.history.changes_requested'.tr();
  }

  final club = showClub
      ? [report.clubName, report.clubType]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' · ')
      : '';
  final parts = [if (club.isNotEmpty) club, if (status != null) status];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Historial agrupado por año: etiqueta en mayúsculas con su conteo y las
/// filas del año en una sola tarjeta. Lo usan el inicio de Reportes y la
/// lista por inscripción, así hay una sola versión del historial.
class MonthlyReportYearGroups extends StatelessWidget {
  const MonthlyReportYearGroups({
    super.key,
    required this.reports,
    required this.onOpen,
    this.showClub = false,
  });

  final List<VisibleMonthlyReport> reports;
  final ValueChanged<VisibleMonthlyReport> onOpen;
  final bool showClub;

  @override
  Widget build(BuildContext context) {
    final byYear = <int, List<VisibleMonthlyReport>>{};
    for (final report in reports) {
      byYear.putIfAbsent(report.year, () => []).add(report);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final year in years)
          SacGroupedSection(
            key: ValueKey('monthly-reports-year-$year'),
            label: '$year',
            dividerIndent: 16,
            children: [
              for (final report
                  in (byYear[year]!
                    ..sort((a, b) => b.month.compareTo(a.month))))
                MonthlyReportHistoryRow(
                  key: ValueKey('monthly-report-row-${report.id}'),
                  report: report,
                  showClub: showClub,
                  onTap: () => onOpen(report),
                ),
            ],
          ),
      ],
    );
  }
}

/// Una fila del historial: mes, línea corta y chip de estado.
class MonthlyReportHistoryRow extends StatelessWidget {
  const MonthlyReportHistoryRow({
    super.key,
    required this.report,
    required this.onTap,
    this.showClub = false,
  });

  final VisibleMonthlyReport report;
  final VoidCallback onTap;
  final bool showClub;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = monthlyReportDetailLine(context, report, showClub: showClub);
    final status = report.reportStatus;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: [
        '${report.monthName} ${report.year}',
        status.label,
        if (detail != null) detail,
      ].join('. '),
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.monthName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: c.text,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            height: 1.35,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MonthlyReportStatusChip(status: status),
                const SizedBox(width: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de «Por atender»: el borrador del mes en curso (o, si todavía no
/// existe, la invitación a empezarlo).
class MonthlyReportAttentionRow extends StatelessWidget {
  const MonthlyReportAttentionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = monthlyReportStatusStyle(context, MonthlyReportStatus.draft);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.container,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: HugeIcon(
                    icon: style.icon,
                    size: 18,
                    color: style.onContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: style.onContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? const SacLoadingSmall()
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 18,
                        color: c.textTertiary,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
