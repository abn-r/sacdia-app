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
        backgroundColor: c.background.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        title: Text(
          'monthly_reports.detail.title'.tr(),
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
    final showSticky = report.canEditManualData || report.canDownloadPdf;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(monthlyReportDetailProvider(report.id)),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, showSticky ? 24 : 36),
              children: [
                MonthlyReportEntrance(child: _ReportHeaderCard(report: report)),
                const SizedBox(height: 18),
                MonthlyReportEntrance(
                  index: 1,
                  child: _KpiGrid(report: report),
                ),
                const SizedBox(height: 18),
                MonthlyReportEntrance(
                  index: 2,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_administration'.tr(),
                    icon: HugeIcons.strokeRoundedUserMultiple,
                    initiallyExpanded: true,
                    children: [
                      _InfoRow(
                        label: 'monthly_reports.detail.stat_members'.tr(),
                        value: _dash(snapshot?.memberCount),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.meeting_days'.tr(),
                        value: snapshot?.meetingDays ?? '—',
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.planning_meetings'.tr(),
                        value: _dash(manual?.planningMeetings),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.parent_meetings'.tr(),
                        value: _dash(manual?.parentMeetings),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.youth_council_attendance'
                            .tr(),
                        value: _dash(manual?.youthCouncilAttendance),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.church_board_attendance'
                            .tr(),
                        value: _dash(manual?.churchBoardAttendance),
                      ),
                      if ((snapshot?.directiva ?? const []).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...snapshot!.directiva.map(
                          (leader) =>
                              _InfoRow(label: leader.role, value: leader.name),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                MonthlyReportEntrance(
                  index: 3,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_honors'.tr(),
                    icon: HugeIcons.strokeRoundedNoteEdit,
                    children: [
                      _InfoRow(
                        label: 'monthly_reports.detail.honors_started'.tr(),
                        value: _dash(snapshot?.honors.started),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.honors_completed'.tr(),
                        value: _dash(snapshot?.honors.completed),
                      ),
                      if ((snapshot?.honors.items ?? const []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...snapshot!.honors.items.map(
                          (honor) => _MiniListTile(
                            title: honor.name,
                            subtitle: honor.status,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                MonthlyReportEntrance(
                  index: 4,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_activities'.tr(),
                    icon: HugeIcons.strokeRoundedCalendar01,
                    children: [
                      _InfoRow(
                        label: 'monthly_reports.detail.stat_activities'.tr(),
                        value: _dash(
                          snapshot?.activities.total ?? report.totalActivities,
                        ),
                      ),
                      if ((snapshot?.activities.items ?? const [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...snapshot!.activities.items.map(
                          (activity) => _MiniListTile(
                            title: activity.name,
                            subtitle: [
                              if (activity.type != null) activity.type,
                              if (activity.date != null)
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(activity.date!.toLocal()),
                              if (activity.attendees != null)
                                '${activity.attendees} asistentes',
                            ].join(' · '),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                MonthlyReportEntrance(
                  index: 5,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_finances'.tr(),
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    children: [
                      _InfoRow(
                        label: 'monthly_reports.detail.income'.tr(),
                        value: _money(snapshot?.finances.income),
                        valueColor: AppColors.secondary,
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.expenses'.tr(),
                        value: _money(snapshot?.finances.expenses),
                        valueColor: AppColors.error,
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.month_balance'.tr(),
                        value: _money(snapshot?.finances.balance),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.club_total_balance'.tr(),
                        value: _money(snapshot?.finances.totalBalance),
                        valueColor: AppColors.primary,
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.transactions'.tr(),
                        value: _dash(snapshot?.finances.transactions),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                MonthlyReportEntrance(
                  index: 6,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_mission'.tr(),
                    icon: HugeIcons.strokeRoundedUserAdd01,
                    children: [
                      _InfoRow(
                        label: 'monthly_reports.detail.soul_target'.tr(),
                        value: _dash(manual?.soulTarget),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.unbaptized_members'.tr(),
                        value: _dash(manual?.unbaptizedMembers),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.bible_studies_receiving'
                            .tr(),
                        value: _dash(manual?.bibleStudiesReceiving),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.weekly_instruction'.tr(),
                        value: _yesNo(manual?.hasWeeklyBibleInstruction),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.studies_given'.tr(),
                        value: _yesNo(manual?.bibleStudiesGiven),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.literature'.tr(),
                        value: _yesNo(manual?.literatureDistributed),
                      ),
                      _InfoRow(
                        label:
                            'monthly_reports.detail.baptized_this_month'.tr(),
                        value: _dash(manual?.baptizedThisMonth),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.total_baptized'.tr(),
                        value: _dash(manual?.totalBaptized),
                      ),
                      if (manual?.clubParticipationDescription?.isNotEmpty ==
                          true)
                        _Paragraph(
                          label:
                              'monthly_reports.detail.club_participation'.tr(),
                          value: manual!.clubParticipationDescription!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                MonthlyReportEntrance(
                  index: 7,
                  child: _ExpandableSection(
                    title: 'monthly_reports.detail.section_service'.tr(),
                    icon: HugeIcons.strokeRoundedNoteEdit,
                    children: [
                      _Paragraph(
                        label: 'monthly_reports.detail.community_service'.tr(),
                        value: manual?.communityServiceDescription ?? '—',
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.certificates'.tr(),
                        value: _yesNo(manual?.certificatesDelivered),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.booklets'.tr(),
                        value: _yesNo(manual?.membersHaveBooklet),
                      ),
                      _InfoRow(
                        label: 'monthly_reports.detail.booklets_signed'.tr(),
                        value: _yesNo(manual?.bookletRequirementsSigned),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showSticky) _StickyActionBar(report: report),
      ],
    );
  }
}

class _StickyActionBar extends ConsumerStatefulWidget {
  final MonthlyReport report;

  const _StickyActionBar({required this.report});

  @override
  ConsumerState<_StickyActionBar> createState() => _StickyActionBarState();
}

class _StickyActionBarState extends ConsumerState<_StickyActionBar> {
  bool _isOpeningPdf = false;

  Future<void> _editManualData() async {
    final changed = await MonthlyReportManualDataFormView.show(
      context,
      widget.report,
    );
    if (changed == true) {
      ref.invalidate(monthlyReportDetailProvider(widget.report.id));
    }
  }

  Future<void> _openPdf() async {
    setState(() => _isOpeningPdf = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('monthly_reports.detail.downloading_pdf'.tr()),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final localPath = await ref.read(
        monthlyReportPdfProvider(widget.report.id).future,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'monthly_reports.detail.pdf_error'.tr(
              namedArgs: {
                'error': e.toString().replaceFirst('Exception: ', ''),
              },
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthlyReportMutationProvider);

    return MonthlyReportFrostBar(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOut,
        child: SacButton.primary(
          key: ValueKey(
            '${widget.report.canEditManualData}-$_isOpeningPdf-${state.isLoading}',
          ),
          text: widget.report.canEditManualData
              ? 'monthly_reports.detail.edit_manual_data'.tr()
              : (_isOpeningPdf
                  ? 'monthly_reports.detail.downloading_pdf'.tr()
                  : 'monthly_reports.detail.view_pdf_button'.tr()),
          icon: widget.report.canEditManualData
              ? HugeIcons.strokeRoundedNoteEdit
              : HugeIcons.strokeRoundedPdf01,
          onPressed: widget.report.canEditManualData
              ? (state.isLoading ? null : _editManualData)
              : (_isOpeningPdf ? null : _openPdf),
        ),
      ),
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  final MonthlyReport report;

  const _ReportHeaderCard({required this.report});

  String _statusMessage() {
    switch (report.reportStatus) {
      case MonthlyReportStatus.draft:
        return 'monthly_reports.detail.status_message_draft'.tr();
      case MonthlyReportStatus.generated:
        return 'monthly_reports.detail.status_message_generated'.tr();
      case MonthlyReportStatus.submitted:
        return 'monthly_reports.detail.status_message_submitted'.tr();
      case MonthlyReportStatus.approved:
        return 'monthly_reports.detail.status_message_approved'.tr();
      case MonthlyReportStatus.rejected:
        return 'monthly_reports.detail.status_message_rejected'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final period = '${report.monthName} ${report.year}';
    final clubContext = [
      report.clubName,
      report.clubType,
    ].whereType<String>().join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
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
          const SizedBox(height: 14),
          Text(
            period,
            style: TextStyle(
              color: c.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (clubContext.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              clubContext,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (report.generatedAt != null) ...[
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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
    return Text(
      'monthly_reports.visible.generated_on'.tr(
        namedArgs: {'date': DateFormat('dd/MM/yyyy').format(date.toLocal())},
      ),
      style: TextStyle(
        color: c.textTertiary,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'monthly_reports.detail.stat_activities'.tr(),
                value: _dash(
                  report.snapshot?.activities.total ?? report.totalActivities,
                ),
                icon: HugeIcons.strokeRoundedCalendar01,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'monthly_reports.detail.stat_members'.tr(),
                value: _dash(
                  report.snapshot?.memberCount ?? report.totalMembers,
                ),
                icon: HugeIcons.strokeRoundedUserMultiple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'monthly_reports.detail.month_balance'.tr(),
                value: _money(finances?.balance),
                icon: HugeIcons.strokeRoundedAnalytics01,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'monthly_reports.detail.club_total_balance'.tr(),
                value: _money(finances?.totalBalance),
                icon: HugeIcons.strokeRoundedAnalytics01,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
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
                  fontWeight: FontWeight.w900,
                  color: c.text,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: c.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  final String title;
  final dynamic icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: HugeIcon(icon: icon, color: AppColors.primary, size: 18),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          children: children,
        ),
      ),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, color: c.text, height: 1.5),
          ),
        ],
      ),
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
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
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

String _dash(Object? value) => value?.toString() ?? '—';
String _yesNo(bool? value) =>
    value == null ? '—' : (value ? 'common.yes'.tr() : 'common.no'.tr());
String _money(num? value) =>
    value == null ? '—' : NumberFormat.currency(symbol: r'$').format(value);
