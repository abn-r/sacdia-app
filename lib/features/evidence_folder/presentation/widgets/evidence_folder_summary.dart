import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/entities/evidence_section.dart';

/// Section counts by what they mean for the club.
class EvidenceFolderCounts extends StatusCounts {
  EvidenceFolderCounts(List<EvidenceSection> sections)
      : super(
          validated: _count(sections, {EvidenceSectionStatus.validated}),
          review: _count(sections, {
            EvidenceSectionStatus.submitted,
            EvidenceSectionStatus.preapprovedLf,
          }),
          rejected: _count(sections, {EvidenceSectionStatus.rejected}),
          pending: _count(sections, {EvidenceSectionStatus.pending}),
        );

  static int _count(
    List<EvidenceSection> sections,
    Set<EvidenceSectionStatus> statuses,
  ) =>
      sections.where((s) => statuses.contains(s.status)).length;
}

/// Points with thousands separators. Spanish uses the Mexican format
/// ("3,700"), like money (`SacMoney`): "3.700" reads as a decimal in Mexico.
String formatEvidencePoints(BuildContext context, int value) {
  // The app language comes from EasyLocalization, not from the widget
  // Localizations, which can differ under a dialog route.
  final locale =
      EasyLocalization.of(context)?.locale ?? Localizations.localeOf(context);
  final pattern = locale.languageCode == 'es' ? 'es_MX' : locale.toString();
  return NumberFormat.decimalPattern(pattern).format(value);
}

/// Top block of the folder. It changes with the folder state, so the screen
/// says each fact once: progress while open, what is happening while it is
/// evaluated, and a single result at the end.
class EvidenceFolderSummary extends StatelessWidget {
  const EvidenceFolderSummary({super.key, required this.folder});

  final EvidenceFolder folder;

  @override
  Widget build(BuildContext context) {
    final counts = EvidenceFolderCounts(folder.sections);
    final Widget child;
    if (folder.isEvaluated) {
      child = _EvaluatedSummary(folder: folder, counts: counts);
    } else if (folder.isUnderEvaluation || folder.status == 'submitted') {
      child = _WaitingSummary(folder: folder, counts: counts);
    } else if (!folder.isOpen) {
      child = _ClosedSummary(folder: folder, counts: counts);
    } else {
      child = _OpenSummary(folder: folder, counts: counts);
    }
    return Padding(
      key: const ValueKey('evidence-folder-summary'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: child,
    );
  }
}

class _OpenSummary extends StatelessWidget {
  const _OpenSummary({required this.folder, required this.counts});

  final EvidenceFolder folder;
  final EvidenceFolderCounts counts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacSummaryBox(
      color: c.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'evidence_folder.summary.ready_label'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            key: const ValueKey('evidence-folder-summary-ready'),
            TextSpan(
              children: [
                TextSpan(
                  text: 'evidence_folder.summary.ready_count'.tr(namedArgs: {
                    'ready': '${counts.ready}',
                    'total': '${counts.total}',
                  }),
                  style: TextStyle(
                    fontSize: SacFontSize.displayMedium,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: c.text,
                  ),
                ),
                if (counts.missing > 0)
                  TextSpan(
                    text:
                        '  ·  ${'evidence_folder.summary.missing'.plural(counts.missing)}',
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EvidenceStatusBar(counts: counts),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: c.border),
          const SizedBox(height: 12),
          _PointsLine(folder: folder),
        ],
      ),
    );
  }
}

class _WaitingSummary extends StatelessWidget {
  const _WaitingSummary({required this.folder, required this.counts});

  final EvidenceFolder folder;
  final EvidenceFolderCounts counts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final underEvaluation = folder.isUnderEvaluation;
    return SacSummaryBox(
      color: c.infoContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconHeader(
            icon: HugeIcons.strokeRoundedHourglass,
            color: c.onInfoContainer,
            title: underEvaluation
                ? 'evidence_folder.summary.evaluating_title'.tr()
                : 'evidence_folder.summary.submitted_title'.tr(),
            body: 'evidence_folder.summary.evaluating_body'.tr(),
          ),
          const SizedBox(height: 14),
          EvidenceStatusBar(counts: counts, legendColor: c.onInfoContainer),
        ],
      ),
    );
  }
}

class _ClosedSummary extends StatelessWidget {
  const _ClosedSummary({required this.folder, required this.counts});

  final EvidenceFolder folder;
  final EvidenceFolderCounts counts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacSummaryBox(
      color: c.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconHeader(
            icon: HugeIcons.strokeRoundedLocked,
            color: c.textSecondary,
            titleColor: c.text,
            title: 'evidence_folder.summary.closed_title'.tr(),
            body: 'evidence_folder.summary.closed_body'.tr(),
          ),
          const SizedBox(height: 14),
          EvidenceStatusBar(counts: counts),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: c.border),
          const SizedBox(height: 12),
          _PointsLine(folder: folder),
        ],
      ),
    );
  }
}

class _EvaluatedSummary extends StatelessWidget {
  const _EvaluatedSummary({required this.folder, required this.counts});

  final EvidenceFolder folder;
  final EvidenceFolderCounts counts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ink = c.onSuccessContainer;
    final date = folder.evaluatedAt;
    final percent = (folder.completionRatio * 100).round();
    return SacSummaryBox(
      color: c.successContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? 'evidence_folder.summary.evaluated_title'.tr()
                      : 'evidence_folder.summary.evaluated_on'.tr(namedArgs: {
                          'date': DateFormat('d MMM yyyy',
                                  Localizations.localeOf(context).toString())
                              .format(date.toLocal()),
                        }),
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  key: const ValueKey('evidence-folder-summary-result'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            formatEvidencePoints(context, folder.earnedPoints),
                        style: TextStyle(
                          fontSize: SacFontSize.displayMedium,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: ink,
                        ),
                      ),
                      TextSpan(
                        text:
                            '  ${'evidence_folder.summary.of_points'.tr(namedArgs: {
                              'max': formatEvidencePoints(
                                  context, folder.maxPoints),
                            })}',
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'evidence_folder.summary.evaluated_detail'.tr(namedArgs: {
                    'percent': '$percent',
                    'validated': '${counts.validated}',
                    'total': '${counts.total}',
                  }),
                  style: TextStyle(fontSize: SacFontSize.bodySmall, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconHeader extends StatelessWidget {
  const _IconHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.titleColor,
  });

  final HugeIconData icon;
  final Color color;
  final Color? titleColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: HugeIcon(icon: icon, size: 22, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: titleColor ?? color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.4,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointsLine extends StatelessWidget {
  const _PointsLine({required this.folder});

  final EvidenceFolder folder;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Expanded(
          child: Text(
            'evidence_folder.summary.points_label'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ),
        Text(
          'evidence_folder.summary.points_value'.tr(namedArgs: {
            'earned': formatEvidencePoints(context, folder.earnedPoints),
            'max': formatEvidencePoints(context, folder.maxPoints),
          }),
          key: const ValueKey('evidence-folder-summary-points'),
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ],
    );
  }
}

/// Segmented bar with one segment per group, plus a text legend that only
/// lists the groups that have sections. Gray is "not sent", never an error.
class EvidenceStatusBar extends StatelessWidget {
  const EvidenceStatusBar({super.key, required this.counts, this.legendColor});

  final EvidenceFolderCounts counts;
  final Color? legendColor;

  @override
  Widget build(BuildContext context) {
    return SacStatusBar.counts(
      key: const ValueKey('evidence-folder-status-bar'),
      counts: counts,
      legendColor: legendColor,
      countLabels: SacStatusCountLabels(
        validated:
            'evidence_folder.summary.legend_validated'.plural(counts.validated),
        review: 'evidence_folder.summary.legend_review'.plural(counts.review),
        rejected:
            'evidence_folder.summary.legend_rejected'.plural(counts.rejected),
        pending:
            'evidence_folder.summary.legend_pending'.plural(counts.pending),
      ),
    );
  }
}
