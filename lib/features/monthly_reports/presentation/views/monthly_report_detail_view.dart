import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../widgets/monthly_report_draft_index.dart';
import '../widgets/monthly_report_figures.dart';
import '../widgets/monthly_report_motion.dart';
import '../widgets/monthly_report_state_panel.dart';
import 'monthly_report_manual_data_form_view.dart';

const _tag = 'MonthlyReportDetailView';

/// La única acción fija de cada estado.
enum _PrimaryAction { fill, send, viewPdf, fix }

_PrimaryAction _primaryActionOf(MonthlyReport report) =>
    switch (report.reportStatus) {
      MonthlyReportStatus.draft => _PrimaryAction.fill,
      MonthlyReportStatus.generated => _PrimaryAction.send,
      MonthlyReportStatus.submitted ||
      MonthlyReportStatus.approved =>
        _PrimaryAction.viewPdf,
      MonthlyReportStatus.rejected => _PrimaryAction.fix,
    };

class MonthlyReportDetailView extends ConsumerStatefulWidget {
  final String reportId;

  const MonthlyReportDetailView({super.key, required this.reportId});

  @override
  ConsumerState<MonthlyReportDetailView> createState() =>
      _MonthlyReportDetailViewState();
}

class _MonthlyReportDetailViewState
    extends ConsumerState<MonthlyReportDetailView> {
  bool _isOpeningPdf = false;

  Future<void> _openForm(
    MonthlyReport report, [
    MonthlyReportManualSection? section,
  ]) async {
    final target = section ??
        report.pendingManualSections.firstOrNull ??
        MonthlyReportManualSection.values.first;
    await MonthlyReportManualDataFormView.show(
      context,
      report,
      section: target,
    );
    // El formulario guarda sin refrescar nada: se actualiza una vez al cerrar.
    ref.invalidate(monthlyReportDetailProvider(report.id));
    ref.invalidate(monthlyReportsByEnrollmentProvider);
    ref.invalidate(visibleMonthlyReportsProvider);
  }

  Future<void> _submit(MonthlyReport report) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'monthly_reports.detail.send_title'.tr(),
      content: 'monthly_reports.detail.send_body'.tr(namedArgs: {
        'period': '${report.monthName} ${report.year}',
      }),
      cancelLabel: 'common.cancel'.tr(),
      confirmLabel: 'monthly_reports.detail.send_confirm'.tr(),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(monthlyReportMutationProvider.notifier);
    final ok = await notifier.submit(report.id);
    if (!mounted) return;
    final error = ref.read(monthlyReportMutationProvider).errorMessage;
    SacSnackBar.show(
      context,
      ok
          ? 'monthly_reports.detail.sent'.tr()
          : error ?? 'monthly_reports.detail.send_error'.tr(),
      behavior: SnackBarBehavior.fixed,
      isError: !ok,
    );
  }

  Future<void> _openPdf(MonthlyReport report) async {
    setState(() => _isOpeningPdf = true);
    try {
      SacSnackBar.show(context, 'monthly_reports.detail.downloading_pdf'.tr(),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.fixed);
      final localPath = await ref.read(
        monthlyReportPdfProvider(report.id).future,
      );
      if (!mounted) return;
      SacSnackBar.hide(context);
      SacPdfViewer.show(
        context,
        pdfSource: localPath,
        title: 'monthly_reports.detail.pdf_viewer_title'.tr(),
      );
    } catch (e) {
      AppLogger.w(
        'Error al abrir PDF del informe mensual',
        tag: _tag,
        error: e,
      );
      if (!mounted) return;
      SacSnackBar.hide(context);
      SacSnackBar.show(
          context,
          'monthly_reports.detail.pdf_error'.tr(
            namedArgs: {'error': userErrorMessage(e)},
          ),
          behavior: SnackBarBehavior.fixed);
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(monthlyReportDetailProvider(widget.reportId));
    final report = reportAsync.value;
    final primary = report == null ? null : _primaryActionOf(report);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: report == null
            ? 'monthly_reports.detail.title'.tr()
            : '${report.monthName} ${report.year}',
        frosted: true,
        actions: [
          // El PDF de un informe generado sigue a un toque aunque la acción
          // fija sea «Enviar».
          if (report != null &&
              report.canDownloadPdf &&
              primary != _PrimaryAction.viewPdf)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                tooltip: 'monthly_reports.detail.download_pdf_tooltip'.tr(),
                onPressed: _isOpeningPdf ? null : () => _openPdf(report),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedPdf01,
                  size: 22,
                  color: context.sac.text,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => reportAsync.when(
            loading: () => const MonthlyReportDetailSkeleton(),
            error: (e, _) => SacErrorState(
              title: 'common.error_state.title'.tr(),
              message: userErrorMessage(e),
              onRetry: () =>
                  ref.invalidate(monthlyReportDetailProvider(widget.reportId)),
            ),
            data: (report) => Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: SacAccent.of(context).color,
                    onRefresh: () async =>
                        ref.invalidate(monthlyReportDetailProvider(report.id)),
                    child: _ReportBody(
                      report: report,
                      onOpenSection: (section) => _openForm(report, section),
                    ),
                  ),
                ),
                _PrimaryActionBar(
                  report: report,
                  isOpeningPdf: _isOpeningPdf,
                  onFill: () => _openForm(report),
                  onSend: () => _submit(report),
                  onViewPdf: () => _openPdf(report),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  final MonthlyReport report;
  final ValueChanged<MonthlyReportManualSection> onOpenSection;

  const _ReportBody({required this.report, required this.onOpenSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueDay = ref.watch(monthlyReportDueDayProvider);
    final status = report.reportStatus;
    final comment = report.reviewComment;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: MonthlyReportStatePanel(report: report, dueDay: dueDay),
      ),
      if (status == MonthlyReportStatus.draft) ...[
        MonthlyReportManualGroup(report: report, onOpen: onOpenSection),
        _DraftAutoGroup(report: report),
      ] else if (status == MonthlyReportStatus.rejected) ...[
        if (comment != null && comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: MonthlyReportReviewQuote(comment: comment),
          ),
        MonthlyReportManualGroup(report: report, onOpen: onOpenSection),
      ] else ...[
        MonthlyReportFiguresBox(report: report),
        MonthlyReportSectionGroups(report: report),
      ],
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: SacTopBar.paddingBelowBar(
          context, const EdgeInsets.only(top: 0, bottom: 32)),
      children: [
        for (var i = 0; i < children.length; i++)
          MonthlyReportEntrance(index: i, child: children[i]),
      ],
    );
  }
}

/// Lo que el sistema calcula en vivo mientras el informe es borrador.
class _DraftAutoGroup extends ConsumerWidget {
  final MonthlyReport report;

  const _DraftAutoGroup({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      monthlyReportPreviewProvider(
        MonthlyReportPreviewParams(
          enrollmentId: report.enrollmentId,
          month: report.month,
          year: report.year,
        ),
      ),
    );
    return MonthlyReportAutoGroup(snapshot: preview.value?.snapshot);
  }
}

class _PrimaryActionBar extends ConsumerWidget {
  final MonthlyReport report;
  final bool isOpeningPdf;
  final VoidCallback onFill;
  final VoidCallback onSend;
  final VoidCallback onViewPdf;

  const _PrimaryActionBar({
    required this.report,
    required this.isOpeningPdf,
    required this.onFill,
    required this.onSend,
    required this.onViewPdf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(monthlyReportMutationProvider).isLoading;
    final action = _primaryActionOf(report);

    final String text;
    final HugeIconData icon;
    final VoidCallback onPressed;
    switch (action) {
      case _PrimaryAction.fill:
        text = report.pendingManualSections.isEmpty
            ? 'monthly_reports.actions.review_data'.tr()
            : 'monthly_reports.actions.fill_pending'.tr();
        icon = HugeIcons.strokeRoundedNoteEdit;
        onPressed = onFill;
      case _PrimaryAction.send:
        text = 'monthly_reports.actions.send'.tr();
        icon = HugeIcons.strokeRoundedUpload01;
        onPressed = onSend;
      case _PrimaryAction.viewPdf:
        text = isOpeningPdf
            ? 'monthly_reports.detail.downloading_pdf'.tr()
            : 'monthly_reports.detail.view_pdf_button'.tr();
        icon = HugeIcons.strokeRoundedPdf01;
        onPressed = onViewPdf;
      case _PrimaryAction.fix:
        text = 'monthly_reports.actions.fix_and_resend'.tr();
        icon = HugeIcons.strokeRoundedNoteEdit;
        onPressed = onFill;
    }

    return MonthlyReportFrostBar(
      child: SacButton.primary(
        key: ValueKey('monthly-report-action-${action.name}'),
        text: text,
        icon: icon,
        isLoading: busy && action == _PrimaryAction.send,
        onPressed: busy || (action == _PrimaryAction.viewPdf && isOpeningPdf)
            ? null
            : onPressed,
      ),
    );
  }
}
