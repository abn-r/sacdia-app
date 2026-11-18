import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_states_sheet.dart';

import '../../domain/entities/monthly_report.dart';
import '../utils/monthly_report_format.dart';
import 'monthly_report_status_chip.dart';

/// Los cuatro pasos del ciclo de un informe, en orden.
const _path = [
  MonthlyReportStatus.draft,
  MonthlyReportStatus.generated,
  MonthlyReportStatus.submitted,
  MonthlyReportStatus.approved,
];

/// Posición (desde 0) del estado en el ciclo. Un informe rechazado está en el
/// paso de revisión: ahí lo frenó el campo local.
int monthlyReportStepIndex(MonthlyReportStatus status) =>
    status == MonthlyReportStatus.rejected
        ? _path.indexOf(MonthlyReportStatus.submitted)
        : _path.indexOf(status);

/// Panel con solo el estado actual del informe y qué sigue. Al tocarlo abre la
/// hoja con los cuatro estados.
class MonthlyReportStatePanel extends StatelessWidget {
  const MonthlyReportStatePanel({
    super.key,
    required this.report,
    required this.dueDay,
  });

  final MonthlyReport report;

  /// Día del mes siguiente en que el sistema genera el informe.
  final int dueDay;

  @override
  Widget build(BuildContext context) {
    final status = report.reportStatus;
    final style = monthlyReportStatusStyle(context, status);
    final generationDate = monthlyReportShortDate(
      context,
      monthlyReportGenerationDate(report.month, report.year, dueDay),
    );

    final (String title, String message) = switch (status) {
      MonthlyReportStatus.draft => (
          style.label,
          'monthly_reports.state.draft_message'
              .tr(namedArgs: {'date': generationDate}),
        ),
      MonthlyReportStatus.generated => (
          'monthly_reports.state.generated_title'.tr(),
          'monthly_reports.state.generated_message'.tr(),
        ),
      MonthlyReportStatus.submitted => (
          style.label,
          'monthly_reports.state.submitted_message'.tr(),
        ),
      MonthlyReportStatus.approved => (
          style.label,
          'monthly_reports.state.approved_message'.tr(),
        ),
      MonthlyReportStatus.rejected => (
          style.label,
          'monthly_reports.state.rejected_message'.tr(),
        ),
    };

    return SacStatePanel(
      key: const Key('monthly-report-state-panel'),
      style: style,
      title: title,
      message: message,
      stepLabel: 'monthly_reports.state.step'.tr(namedArgs: {
        'step': '${monthlyReportStepIndex(status) + 1}',
        'total': '${_path.length}',
      }),
      semanticsHint: 'monthly_reports.state.panel_hint'.tr(),
      onTap: () => showSacStatesSheet(
        context,
        title: 'monthly_reports.state.sheet_title'.tr(),
        subtitle: '${report.monthName} ${report.year}',
        steps: monthlyReportStateSteps(context, report, dueDay),
        kindLabels: SacStateKindLabels(
          done: 'monthly_reports.state.kind_done'.tr(),
          current: 'monthly_reports.state.kind_current'.tr(),
          rejected: 'monthly_reports.state.kind_rejected'.tr(),
          pending: 'monthly_reports.state.kind_pending'.tr(),
        ),
      ),
    );
  }
}

/// Los pasos de la hoja: Borrador, Generado, En revisión y Aprobado. Lo hecho
/// va con palomita, el actual resaltado con su fecha cuando se conoce y lo que
/// falta en gris. Un rechazo es el paso actual, en estilo de error.
List<SacStateStep> monthlyReportStateSteps(
  BuildContext context,
  MonthlyReport report,
  int dueDay,
) {
  final status = report.reportStatus;
  final currentIndex = monthlyReportStepIndex(status);
  final isRejected = status == MonthlyReportStatus.rejected;

  String? date(DateTime? value) =>
      value == null ? null : monthlyReportShortDate(context, value);
  final generationDate = monthlyReportShortDate(
    context,
    monthlyReportGenerationDate(report.month, report.year, dueDay),
  );

  String? detailFor(MonthlyReportStatus step, SacStateKind kind) {
    final reached = kind != SacStateKind.pending;
    switch (step) {
      case MonthlyReportStatus.draft:
        return kind == SacStateKind.done
            ? 'monthly_reports.state.draft_done'.tr()
            : 'monthly_reports.state.draft_current'.tr();
      case MonthlyReportStatus.generated:
        if (!reached) {
          return 'monthly_reports.state.generated_pending'
              .tr(namedArgs: {'date': generationDate});
        }
        final generated = date(report.generatedAt);
        return generated == null
            ? null
            : 'monthly_reports.state.generated_on'
                .tr(namedArgs: {'date': generated});
      case MonthlyReportStatus.submitted:
        if (kind == SacStateKind.rejected) {
          return 'monthly_reports.state.rejected_detail'.tr();
        }
        if (!reached) return 'monthly_reports.state.submitted_pending'.tr();
        final sent = date(report.submittedAt);
        return sent == null
            ? null
            : 'monthly_reports.state.submitted_on'
                .tr(namedArgs: {'date': sent});
      case MonthlyReportStatus.approved:
        return reached
            ? 'monthly_reports.state.approved_done'.tr()
            : 'monthly_reports.state.approved_pending'.tr();
      case MonthlyReportStatus.rejected:
        return null;
    }
  }

  return [
    for (var i = 0; i < _path.length; i++)
      () {
        final kind = i < currentIndex
            ? SacStateKind.done
            : i == currentIndex
                ? (isRejected ? SacStateKind.rejected : SacStateKind.current)
                : SacStateKind.pending;
        final step = _path[i];
        return SacStateStep(
          kind: kind,
          title: kind == SacStateKind.rejected
              ? MonthlyReportStatus.rejected.label
              : step.label,
          detail: detailFor(step, kind),
        );
      }(),
  ];
}

/// Comentario del campo local citado en una tarjeta blanca.
class MonthlyReportReviewQuote extends StatelessWidget {
  const MonthlyReportReviewQuote({super.key, required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'monthly_reports.state.review_comment'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '«$comment»',
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              height: 1.45,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}
