import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../classes/presentation/widgets/grouped_summary_box.dart';
import '../utils/certification_status_view.dart';

/// «{validated} de {total} · faltan {n}» with the composition bar and its
/// legend. Only validated counts as progress. The certification screen passes
/// [label] and [percent]; the module screen leaves them out.
class CertificationSummaryBox extends StatelessWidget {
  const CertificationSummaryBox({
    super.key,
    required this.counts,
    this.label,
    this.percent,
  });

  final StatusCounts counts;
  final String? label;

  /// «Avance de la certificación  NN %» under the bar; null leaves it out.
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final missing = counts.total - counts.validated;
    String readyText(int ready) => 'certifications.summary.ready_count'.tr(
          namedArgs: {'ready': '$ready', 'total': '${counts.total}'},
        );
    return GroupedSummaryBox(
      label: label,
      value: readyText(counts.validated),
      valueCount: counts.validated,
      valueText: readyText,
      valueSuffix:
          missing > 0 ? 'certifications.summary.missing'.plural(missing) : null,
      counts: counts,
      countLabels: certificationCountLabels(counts),
      footer: percent == null
          ? null
          : GroupedKeyValueLine(
              label: 'certifications.summary.progress'.tr(),
              value: groupedPercentText(percent!),
            ),
    );
  }
}

/// What a certification asks, before enrolling: modules, requirements and who
/// reviews it.
class CertificationAvailableSummary extends StatelessWidget {
  const CertificationAvailableSummary({
    super.key,
    required this.modules,
    this.requirements,
  });

  final int modules;
  final int? requirements;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, thickness: 1, color: c.border),
        );
    return SacSummaryBox(
      color: c.surfaceVariant,
      child: Column(
        children: [
          GroupedKeyValueLine(
            label: 'certifications.summary.modules'.tr(),
            value: '$modules',
          ),
          if (requirements != null) ...[
            divider(),
            GroupedKeyValueLine(
              label: 'certifications.summary.requirements'.tr(),
              value: '$requirements',
            ),
          ],
          divider(),
          GroupedKeyValueLine(
            label: 'certifications.summary.reviewer'.tr(),
            value: 'certifications.summary.reviewer_value'.tr(),
          ),
        ],
      ),
    );
  }
}

/// Description in three lines with «Ver más» (opens the full text in a sheet
/// when it does not fit).
class CertificationDescription extends StatelessWidget {
  const CertificationDescription({
    super.key,
    required this.text,
    required this.onMore,
  });

  final String text;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.titleMedium,
      height: 1.45,
      color: c.text,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 3,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              key: const ValueKey('certification-description'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              InkWell(
                key: const ValueKey('certification-description-more'),
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                onTap: onMore,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'certifications.view.more'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
