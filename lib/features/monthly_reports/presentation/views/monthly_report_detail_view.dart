import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../widgets/monthly_report_motion.dart';
import 'monthly_report_manual_data_form_view.dart';

const _tag = 'MonthlyReportDetailView';

class MonthlyReportDetailView extends ConsumerWidget {
  final String reportId;

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
              fontWeight: FontWeight.w700, fontSize: 18, color: c.text),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: c.text,
              size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: reportAsync.when(
        loading: () => const MonthlyReportDetailSkeleton(),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(monthlyReportDetailProvider(reportId)),
        ),
        data: (report) => _ReportDetail(report: report),
      ),
    );
  }
}

class _ReportDetail extends ConsumerWidget {
  final MonthlyReport report;

  const _ReportDetail({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = report.snapshot;
    final manual = report.manualData;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(monthlyReportDetailProvider(report.id)),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MonthlyReportEntrance(child: _ReportHeaderCard(report: report)),
          const SizedBox(height: 16),
          MonthlyReportEntrance(index: 1, child: _ActionPanel(report: report)),
          const SizedBox(height: 18),
          MonthlyReportEntrance(index: 2, child: _KpiGrid(report: report)),
          const SizedBox(height: 18),
          MonthlyReportEntrance(
            index: 3,
            child: _SectionCard(
              title: 'monthly_reports.detail.section_administration'.tr(),
              icon: HugeIcons.strokeRoundedUserMultiple,
              children: [
                _InfoRow(
                    label: 'monthly_reports.detail.stat_members'.tr(),
                    value: _dash(snapshot?.memberCount)),
                _InfoRow(
                    label: 'monthly_reports.detail.meeting_days'.tr(),
                    value: snapshot?.meetingDays ?? '—'),
                _InfoRow(
                    label: 'monthly_reports.detail.planning_meetings'.tr(),
                    value: _dash(manual?.planningMeetings)),
                _InfoRow(
                    label: 'monthly_reports.detail.parent_meetings'.tr(),
                    value: _dash(manual?.parentMeetings)),
                _InfoRow(
                    label:
                        'monthly_reports.detail.youth_council_attendance'.tr(),
                    value: _dash(manual?.youthCouncilAttendance)),
                _InfoRow(
                    label:
                        'monthly_reports.detail.church_board_attendance'.tr(),
                    value: _dash(manual?.churchBoardAttendance)),
                if ((snapshot?.directiva ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...snapshot!.directiva.map((leader) =>
                      _InfoRow(label: leader.role, value: leader.name)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          MonthlyReportEntrance(
            index: 4,
            child: _SectionCard(
              title: 'monthly_reports.detail.section_honors'.tr(),
              icon: HugeIcons.strokeRoundedNoteEdit,
              children: [
                _InfoRow(
                    label: 'monthly_reports.detail.honors_started'.tr(),
                    value: _dash(snapshot?.honors.started)),
                _InfoRow(
                    label: 'monthly_reports.detail.honors_completed'.tr(),
                    value: _dash(snapshot?.honors.completed)),
                if ((snapshot?.honors.items ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...snapshot!.honors.items.map((honor) =>
                      _MiniListTile(title: honor.name, subtitle: honor.status)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          MonthlyReportEntrance(
            index: 5,
            child: _SectionCard(
              title: 'monthly_reports.detail.section_activities'.tr(),
              icon: HugeIcons.strokeRoundedCalendar01,
              children: [
                _InfoRow(
                    label: 'monthly_reports.detail.stat_activities'.tr(),
                    value: _dash(
                        snapshot?.activities.total ?? report.totalActivities)),
                if ((snapshot?.activities.items ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...snapshot!.activities.items.map((activity) => _MiniListTile(
                        title: activity.name,
                        subtitle: [
                          if (activity.type != null) activity.type,
                          if (activity.date != null)
                            DateFormat('dd/MM/yyyy')
                                .format(activity.date!.toLocal()),
                          if (activity.attendees != null)
                            '${activity.attendees} asistentes',
                        ].join(' · '),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          MonthlyReportEntrance(
            index: 6,
            child: _FinancesCard(finances: snapshot?.finances),
          ),
          const SizedBox(height: 14),
          MonthlyReportEntrance(
            index: 7,
            child: _SectionCard(
              title: 'monthly_reports.detail.section_mission'.tr(),
              icon: HugeIcons.strokeRoundedUserAdd01,
              children: [
                _InfoRow(
                    label: 'monthly_reports.detail.soul_target'.tr(),
                    value: _dash(manual?.soulTarget)),
                _InfoRow(
                    label: 'monthly_reports.detail.unbaptized_members'.tr(),
                    value: _dash(manual?.unbaptizedMembers)),
                _InfoRow(
                    label:
                        'monthly_reports.detail.bible_studies_receiving'.tr(),
                    value: _dash(manual?.bibleStudiesReceiving)),
                _InfoRow(
                    label: 'monthly_reports.detail.weekly_instruction'.tr(),
                    value: _yesNo(manual?.hasWeeklyBibleInstruction)),
                _InfoRow(
                    label: 'monthly_reports.detail.studies_given'.tr(),
                    value: _yesNo(manual?.bibleStudiesGiven)),
                _InfoRow(
                    label: 'monthly_reports.detail.literature'.tr(),
                    value: _yesNo(manual?.literatureDistributed)),
                _InfoRow(
                    label: 'monthly_reports.detail.baptized_this_month'.tr(),
                    value: _dash(manual?.baptizedThisMonth)),
                _InfoRow(
                    label: 'monthly_reports.detail.total_baptized'.tr(),
                    value: _dash(manual?.totalBaptized)),
                if (manual?.clubParticipationDescription?.isNotEmpty == true)
                  _Paragraph(
                      label: 'monthly_reports.detail.club_participation'.tr(),
                      value: manual!.clubParticipationDescription!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          MonthlyReportEntrance(
            index: 8,
            child: _SectionCard(
              title: 'monthly_reports.detail.section_service'.tr(),
              icon: HugeIcons.strokeRoundedNoteEdit,
              children: [
                _Paragraph(
                  label: 'monthly_reports.detail.community_service'.tr(),
                  value: manual?.communityServiceDescription ?? '—',
                ),
                _InfoRow(
                    label: 'monthly_reports.detail.certificates'.tr(),
                    value: _yesNo(manual?.certificatesDelivered)),
                _InfoRow(
                    label: 'monthly_reports.detail.booklets'.tr(),
                    value: _yesNo(manual?.membersHaveBooklet)),
                _InfoRow(
                    label: 'monthly_reports.detail.booklets_signed'.tr(),
                    value: _yesNo(manual?.bookletRequirementsSigned)),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _ActionPanel extends ConsumerStatefulWidget {
  final MonthlyReport report;

  const _ActionPanel({required this.report});

  @override
  ConsumerState<_ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends ConsumerState<_ActionPanel> {
  bool _isOpeningPdf = false;

  Future<void> _editManualData(BuildContext context, WidgetRef ref) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MonthlyReportManualDataFormView(report: widget.report)),
    );
    if (changed == true) {
      ref.invalidate(monthlyReportDetailProvider(widget.report.id));
    }
  }

  Future<void> _openPdf(BuildContext context, WidgetRef ref) async {
    setState(() => _isOpeningPdf = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('monthly_reports.detail.downloading_pdf'.tr()),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final localPath =
          await ref.read(monthlyReportPdfProvider(widget.report.id).future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      SacPdfViewer.show(context,
          pdfSource: localPath,
          title: 'monthly_reports.detail.pdf_viewer_title'.tr());
    } catch (e) {
      AppLogger.w('Error al abrir PDF del informe mensual',
          tag: _tag, error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('monthly_reports.detail.pdf_error'.tr(namedArgs: {
              'error': e.toString().replaceFirst('Exception: ', '')
            })),
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthlyReportMutationProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey('${state.isLoading}-$_isOpeningPdf'),
        children: [
          if (widget.report.canEditManualData) ...[
            SacButton.primary(
              text: 'monthly_reports.detail.edit_manual_data'.tr(),
              icon: HugeIcons.strokeRoundedNoteEdit,
              onPressed:
                  state.isLoading ? null : () => _editManualData(context, ref),
            ),
          ] else if (widget.report.canDownloadPdf)
            SacButton.primary(
              text: _isOpeningPdf
                  ? 'monthly_reports.detail.downloading_pdf'.tr()
                  : 'monthly_reports.detail.view_pdf_button'.tr(),
              icon: HugeIcons.strokeRoundedPdf01,
              onPressed: _isOpeningPdf ? null : () => _openPdf(context, ref),
            ),
        ],
      ),
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  final MonthlyReport report;

  const _ReportHeaderCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final period = '${report.monthName} ${report.year}';
    final clubContext =
        [report.clubName, report.clubType].whereType<String>().join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PeriodPill(label: period),
              _StatusPill(status: report.reportStatus),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _trWithFallback(
              'monthly_reports.detail.report_heading',
              'Resumen del informe mensual',
            ),
            style: TextStyle(
              color: c.text,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.55,
              height: 1.04,
            ),
          ),
          if (clubContext.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              clubContext,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (report.generatedAt != null) ...[
            const SizedBox(height: 14),
            _GeneratedNote(date: report.generatedAt!),
          ],
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;

  const _PeriodPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _GeneratedNote extends StatelessWidget {
  final DateTime date;

  const _GeneratedNote({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCalendarCheckOut01,
            color: AppColors.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'monthly_reports.visible.generated_on'.tr(namedArgs: {
                'date': DateFormat('dd/MM/yyyy').format(date.toLocal()),
              }),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final MonthlyReport report;

  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final finances = report.snapshot?.finances;
    return Column(children: [
      Row(children: [
        Expanded(
            child: _KpiCard(
                label: 'monthly_reports.detail.stat_activities'.tr(),
                value: _dash(report.snapshot?.activities.total ??
                    report.totalActivities),
                icon: HugeIcons.strokeRoundedCalendar01)),
        const SizedBox(width: 12),
        Expanded(
            child: _KpiCard(
                label: 'monthly_reports.detail.stat_members'.tr(),
                value:
                    _dash(report.snapshot?.memberCount ?? report.totalMembers),
                icon: HugeIcons.strokeRoundedUserMultiple)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _KpiCard(
                label: 'monthly_reports.detail.month_balance'.tr(),
                value: _money(finances?.balance),
                icon: HugeIcons.strokeRoundedAnalytics01)),
        const SizedBox(width: 12),
        Expanded(
            child: _KpiCard(
                label: 'monthly_reports.detail.club_total_balance'.tr(),
                value: _money(finances?.totalBalance),
                icon: HugeIcons.strokeRoundedAnalytics01)),
      ]),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;

  const _KpiCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            HugeIcon(icon: icon, color: AppColors.primary, size: 18),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: c.text,
                      height: 1)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 11, color: c.textTertiary)),
            ]),
          ]),
    );
  }
}

class _FinancesCard extends StatelessWidget {
  final MonthlyReportFinancesSummary? finances;

  const _FinancesCard({required this.finances});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'monthly_reports.detail.section_finances'.tr(),
      icon: HugeIcons.strokeRoundedAnalytics01,
      children: [
        _InfoRow(
            label: 'monthly_reports.detail.income'.tr(),
            value: _money(finances?.income),
            valueColor: AppColors.secondary),
        _InfoRow(
            label: 'monthly_reports.detail.expenses'.tr(),
            value: _money(finances?.expenses),
            valueColor: AppColors.error),
        _InfoRow(
            label: 'monthly_reports.detail.month_balance'.tr(),
            value: _money(finances?.balance)),
        _InfoRow(
            label: 'monthly_reports.detail.club_total_balance'.tr(),
            value: _money(finances?.totalBalance),
            valueColor: AppColors.primary),
        _InfoRow(
            label: 'monthly_reports.detail.transactions'.tr(),
            value: _dash(finances?.transactions)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final dynamic icon;
  final List<Widget> children;

  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HugeIcon(icon: icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.text)))
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      label: '$label: $value',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: c.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 16,
                height: 1.28,
                fontWeight: FontWeight.w800,
                color: valueColor ?? c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String label;
  final String value;

  const _Paragraph({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.55)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.25,
            color: c.textTertiary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 15, color: c.text, height: 1.5),
        ),
      ]),
    );
  }
}

class _MiniListTile extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _MiniListTile({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withValues(alpha: 0.6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(subtitle!,
              style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final MonthlyReportStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: cfg.fg,
          letterSpacing: 0.1,
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
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry),
        ]),
      ),
    );
  }
}

String _trWithFallback(String key, String fallback) {
  final translated = key.tr();
  return translated == key ? fallback : translated;
}

String _dash(Object? value) => value?.toString() ?? '—';
String _yesNo(bool? value) =>
    value == null ? '—' : (value ? 'common.yes'.tr() : 'common.no'.tr());
String _money(num? value) =>
    value == null ? '—' : NumberFormat.currency(symbol: r'$').format(value);
