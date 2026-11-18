import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/monthly_report.dart';
import '../utils/monthly_report_format.dart';

/// «Lo llenas tú»: cada sección manual con su estado (palomita y «Listo», o
/// ícono de edición y «Falta llenar»). Tocarla abre esa sección del formulario.
class MonthlyReportManualGroup extends StatelessWidget {
  const MonthlyReportManualGroup({
    super.key,
    required this.report,
    required this.onOpen,
  });

  final MonthlyReport report;
  final ValueChanged<MonthlyReportManualSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = report.pendingManualSections;

    return SacGroupedSection(
      key: const Key('monthly-report-manual-group'),
      label: 'monthly_reports.draft.manual_title'.tr(),
      dividerIndent: 58,
      action: Text(
        pending.isEmpty
            ? 'monthly_reports.draft.all_done'.tr()
            : 'monthly_reports.draft.missing_count'
                .tr(namedArgs: {'count': '${pending.length}'}),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          color: c.textTertiary,
        ),
      ),
      children: [
        for (final section in MonthlyReportManualSection.values)
          _ManualRow(
            key: ValueKey('monthly-report-manual-${section.name}'),
            title: monthlyReportSectionTitle(section),
            isFilled: !pending.contains(section),
            onTap: () => onOpen(section),
          ),
      ],
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({
    super.key,
    required this.title,
    required this.isFilled,
    required this.onTap,
  });

  final String title;
  final bool isFilled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = isFilled
        ? 'monthly_reports.draft.ready'.tr()
        : 'monthly_reports.draft.missing'.tr();

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$title. $detail',
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
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFilled ? c.successContainer : c.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: isFilled
                        ? HugeIcons.strokeRoundedTick02
                        : HugeIcons.strokeRoundedNoteEdit,
                    size: 17,
                    color:
                        isFilled ? c.onSuccessContainer : c.onWarningContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
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
                        detail,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight:
                              isFilled ? FontWeight.w400 : FontWeight.w600,
                          height: 1.35,
                          color:
                              isFilled ? c.textSecondary : c.onWarningContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

/// «Se llena solo»: lo que el sistema calcula, con su cifra clave. [snapshot]
/// es el cálculo en vivo; mientras llega, o si no se pudo leer, la cifra se
/// escribe en gris como «Sin dato».
class MonthlyReportAutoGroup extends StatelessWidget {
  const MonthlyReportAutoGroup({super.key, required this.snapshot});

  final MonthlyReportSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    return SacGroupedSection(
      key: const Key('monthly-report-auto-group'),
      label: 'monthly_reports.draft.auto_title'.tr(),
      dividerIndent: 58,
      children: [
        _AutoRow(
          icon: HugeIcons.strokeRoundedUserMultiple,
          title: 'monthly_reports.detail.stat_members'.tr(),
          value: data?.memberCount?.toString(),
        ),
        _AutoRow(
          icon: HugeIcons.strokeRoundedCalendar01,
          title: 'monthly_reports.detail.stat_activities'.tr(),
          value: data?.activities.total.toString(),
        ),
        _AutoRow(
          icon: HugeIcons.strokeRoundedNoteEdit,
          title: 'monthly_reports.detail.section_honors'.tr(),
          value: data?.honors.completed.toString(),
        ),
        _AutoRow(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'monthly_reports.detail.month_balance'.tr(),
          value: data == null ? null : SacMoney.format(data.finances.balance),
        ),
      ],
    );
  }
}

class _AutoRow extends StatelessWidget {
  const _AutoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final HugeIconData icon;
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final value = this.value;
    final shown = value ?? 'monthly_reports.detail.no_data'.tr();

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$title: $shown. ${'monthly_reports.draft.auto_hint'.tr()}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: icon,
                  size: 17,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
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
                      'monthly_reports.draft.auto_hint'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                shown,
                style: value == null
                    ? TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textTertiary,
                      )
                    : TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        fontFeatures: SacMoney.tabularFigures,
                        color: c.text,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
