import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/monthly_report.dart';
import '../utils/monthly_report_format.dart';

/// Las cuatro cifras clave en UNA caja de 2×2 (no cuatro tarjetas). Una cifra
/// que falta se escribe en gris, nunca como un guion enorme.
class MonthlyReportFiguresBox extends StatelessWidget {
  const MonthlyReportFiguresBox({super.key, required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final snapshot = report.snapshot;
    final members = snapshot?.memberCount ?? report.totalMembers;
    final activities = snapshot?.activities.total ?? report.totalActivities;
    final finances = snapshot?.finances;

    final cells = [
      _Figure(
        'monthly_reports.detail.stat_members'.tr(),
        members?.toString(),
      ),
      _Figure(
        'monthly_reports.detail.stat_activities'.tr(),
        activities?.toString(),
      ),
      _Figure(
        'monthly_reports.detail.income'.tr(),
        finances == null ? null : SacMoney.format(finances.income),
      ),
      _Figure(
        'monthly_reports.detail.month_balance'.tr(),
        finances == null ? null : SacMoney.format(finances.balance),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        key: const Key('monthly-report-figures'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _FigureCell(figure: cells[0])),
                  VerticalDivider(width: 1, thickness: 1, color: c.divider),
                  Expanded(child: _FigureCell(figure: cells[1])),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.divider),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _FigureCell(figure: cells[2])),
                  VerticalDivider(width: 1, thickness: 1, color: c.divider),
                  Expanded(child: _FigureCell(figure: cells[3])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure {
  const _Figure(this.label, this.value);

  final String label;
  final String? value;
}

class _FigureCell extends StatelessWidget {
  const _FigureCell({required this.figure});

  final _Figure figure;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final value = figure.value;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${figure.label}: ${value ?? 'monthly_reports.detail.no_data'.tr()}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: SacFontSize.headlineSmall,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.15,
                    fontFeatures: SacMoney.tabularFigures,
                    color: c.text,
                  ),
                ),
              )
            else
              Text(
                'monthly_reports.detail.no_data'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.6,
                  color: c.textTertiary,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              figure.label,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cada sección del informe ya generado como grupo de etiqueta y valor: sin
/// tarjetas anidadas ni secciones plegables.
class MonthlyReportSectionGroups extends StatelessWidget {
  const MonthlyReportSectionGroups({super.key, required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final snapshot = report.snapshot;
    final manual = report.manualData;

    String? number(Object? value) => value?.toString();
    String? money(num? value) => value == null ? null : SacMoney.format(value);
    String? yesNo(bool? value) =>
        value == null ? null : (value ? 'common.yes'.tr() : 'common.no'.tr());
    String t(String key) => 'monthly_reports.detail.$key'.tr();

    final activities = snapshot?.activities.items ?? const [];
    final honors = snapshot?.honors.items ?? const [];
    final leaders = snapshot?.directiva ?? const [];

    return Column(
      children: [
        _Group(
          label: t('section_administration'),
          rows: [
            _Kv(t('stat_members'), number(snapshot?.memberCount)),
            _Kv(t('meeting_days'), snapshot?.meetingDays),
            _Kv(t('planning_meetings'), number(manual?.planningMeetings)),
            _Kv(t('parent_meetings'), number(manual?.parentMeetings)),
            _Kv(t('youth_council_attendance'),
                number(manual?.youthCouncilAttendance)),
            _Kv(t('church_board_attendance'),
                number(manual?.churchBoardAttendance)),
            for (final leader in leaders) _Kv(leader.role, leader.name),
          ],
        ),
        _Group(
          label: t('section_honors'),
          rows: [
            _Kv(t('honors_started'), number(snapshot?.honors.started)),
            _Kv(t('honors_completed'), number(snapshot?.honors.completed)),
            for (final honor in honors) _Kv(honor.name, honor.status),
          ],
        ),
        _Group(
          label: t('section_activities'),
          rows: [
            _Kv(
              t('stat_activities'),
              number(snapshot?.activities.total ?? report.totalActivities),
            ),
            for (final activity in activities)
              _Kv(
                activity.name,
                [
                  if (activity.type != null) activity.type,
                  if (activity.date != null)
                    monthlyReportShortDate(context, activity.date!),
                  if (activity.attendees != null)
                    'monthly_reports.detail.attendees'
                        .plural(activity.attendees!),
                ].join(' · '),
                stacked: true,
              ),
          ],
        ),
        _Group(
          label: t('section_finances'),
          rows: [
            _Kv(t('income'), money(snapshot?.finances.income),
                color: context.sac.onSuccessContainer),
            _Kv(t('expenses'), money(snapshot?.finances.expenses),
                color: context.sac.onErrorContainer),
            _Kv(t('month_balance'), money(snapshot?.finances.balance)),
            _Kv(t('club_total_balance'),
                money(snapshot?.finances.totalBalance)),
            _Kv(t('transactions'), number(snapshot?.finances.transactions)),
          ],
        ),
        _Group(
          label: t('section_mission'),
          rows: [
            _Kv(t('soul_target'), number(manual?.soulTarget)),
            _Kv(t('unbaptized_members'), number(manual?.unbaptizedMembers)),
            _Kv(t('bible_studies_receiving'),
                number(manual?.bibleStudiesReceiving)),
            _Kv(t('weekly_instruction'),
                yesNo(manual?.hasWeeklyBibleInstruction)),
            _Kv(t('studies_given'), yesNo(manual?.bibleStudiesGiven)),
            _Kv(t('literature'), yesNo(manual?.literatureDistributed)),
            _Kv(t('baptized_this_month'), number(manual?.baptizedThisMonth)),
            _Kv(t('total_baptized'), number(manual?.totalBaptized)),
            if (manual?.clubParticipationDescription?.isNotEmpty == true)
              _Kv(
                t('club_participation'),
                manual!.clubParticipationDescription,
                stacked: true,
              ),
          ],
        ),
        _Group(
          label: t('section_service'),
          rows: [
            _Kv(t('community_service'), manual?.communityServiceDescription,
                stacked: true),
            _Kv(t('certificates'), yesNo(manual?.certificatesDelivered)),
            _Kv(t('booklets'), yesNo(manual?.membersHaveBooklet)),
            _Kv(t('booklets_signed'), yesNo(manual?.bookletRequirementsSigned)),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<_Kv> rows;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: label,
      dividerIndent: 16,
      // Un grupo de etiqueta y valor no se cuenta.
      action: const SizedBox.shrink(),
      children: rows,
    );
  }
}

/// Etiqueta a la izquierda y valor a la derecha; con [stacked] el valor va
/// debajo (textos largos). Sin valor, «Sin dato» en gris.
class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value, {this.color, this.stacked = false});

  final String label;
  final String? value;
  final Color? color;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final raw = value?.trim();
    final hasValue = raw != null && raw.isNotEmpty;
    final shown = hasValue ? raw : 'monthly_reports.detail.no_data'.tr();

    final labelText = Text(
      label,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        height: 1.3,
        color: c.textSecondary,
      ),
    );
    final valueText = Text(
      shown,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: hasValue
          ? TextStyle(
              fontSize: SacFontSize.titleMedium,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: color ?? c.text,
            )
          : TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.35,
              color: c.textTertiary,
            ),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $shown',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 4), valueText],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: labelText),
                    const SizedBox(width: 16),
                    Flexible(child: valueText),
                  ],
                ),
        ),
      ),
    );
  }
}
