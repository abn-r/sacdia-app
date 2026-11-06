import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';
import 'evidence_folder_summary.dart';
import 'section_status_style.dart';

/// Where a section stands, in the same soft box as the folder summary: the
/// state, one line of context and a step path like the honor one: files →
/// sent → local field, plus → union only when the folder requires the
/// union's confirmation. Otherwise the local field validates directly
/// (`SUBMITTED → VALIDATED` in the backend). The reviewer's note sits below,
/// outside the box.
class EvidenceSectionStatusPanel extends StatelessWidget {
  const EvidenceSectionStatusPanel({
    super.key,
    required this.section,
    required this.folderIsOpen,
    this.requiresUnion = false,
  });

  final EvidenceSection section;
  final bool folderIsOpen;

  /// `requires_union_confirmation` of the folder.
  final bool requiresUnion;

  /// A section approved by the local field only exists in that flow, so it
  /// also shows the union step. `unionDecision` is not a signal: without
  /// union confirmation the backend mirrors the local field's approval into
  /// the union columns.
  bool get _showsUnion =>
      requiresUnion || section.status == EvidenceSectionStatus.preapprovedLf;

  String _date(BuildContext context, DateTime date) =>
      DateFormat('d MMM', Localizations.localeOf(context).toString())
          .format(date.toLocal());

  /// One line of context under the state, or null when there is none.
  String? _meta(BuildContext context) {
    switch (section.status) {
      case EvidenceSectionStatus.pending:
        return folderIsOpen
            ? 'evidence_folder.panel.pending_hint'.tr()
            : 'evidence_folder.panel.folder_closed'.tr();
      case EvidenceSectionStatus.submitted:
        final date = section.submittedAt;
        return date == null
            ? 'evidence_folder.panel.waiting_local_field'.tr()
            : 'evidence_folder.panel.sent_on'
                .tr(namedArgs: {'date': _date(context, date)});
      case EvidenceSectionStatus.preapprovedLf:
        return 'evidence_folder.panel.waiting_union'.tr();
      case EvidenceSectionStatus.validated:
        final date = section.unionApprovedAt ??
            section.validatedAt ??
            section.evaluatedAt;
        return date == null
            ? null
            : 'evidence_folder.panel.validated_on'
                .tr(namedArgs: {'date': _date(context, date)});
      case EvidenceSectionStatus.rejected:
        final date = section.evaluatedAt ??
            section.unionApprovedAt ??
            section.lfApprovedAt;
        if (date == null) {
          return folderIsOpen
              ? 'evidence_folder.panel.fix_full'.tr()
              : 'evidence_folder.panel.returned'.tr();
        }
        final when = 'evidence_folder.panel.returned_on'
            .tr(namedArgs: {'date': _date(context, date)});
        return folderIsOpen
            ? '$when · ${'evidence_folder.panel.fix_hint'.tr()}'
            : when;
    }
  }

  /// Index of the current step (0 files, 1 sent, 2 local field, 3 union)
  /// and how much of it is done.
  (int, double) _progress() {
    final last = _showsUnion ? 3 : 2;
    switch (section.status) {
      case EvidenceSectionStatus.pending:
        final ratio = section.maxFiles == 0
            ? 0.0
            : section.files.length / section.maxFiles;
        return (0, ratio.clamp(0.08, 1.0));
      case EvidenceSectionStatus.rejected:
        return (0, 1);
      case EvidenceSectionStatus.submitted:
        return (2, 0.5);
      case EvidenceSectionStatus.preapprovedLf:
        return (3, 0.5);
      case EvidenceSectionStatus.validated:
        return (last, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = EvidenceStatusStyle.of(context, section.status);
    final isValidated = section.status == EvidenceSectionStatus.validated;
    final isRejected = section.status == EvidenceSectionStatus.rejected;
    final isPending = section.status == EvidenceSectionStatus.pending;
    final ink = isPending ? c.text : style.onContainer;
    final meta = _meta(context);
    final notes = section.evaluationNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final (step, fill) = _progress();

    final String? trailing = isValidated
        ? 'evidence_folder.row.points'.tr(namedArgs: {
            'earned': formatEvidencePoints(context, section.earnedPoints),
            'max': formatEvidencePoints(context, section.pointValue),
          })
        : isPending
            ? 'evidence_folder.detail.files_count'.tr(namedArgs: {
                'count': '${section.files.length}',
                'max': '${section.maxFiles}',
              })
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('evidence-section-status-panel'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.container,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(icon: style.icon, size: 20, color: ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      style.label,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing,
                      style: TextStyle(
                        fontSize: isValidated
                            ? SacFontSize.headlineSmall
                            : SacFontSize.bodySmall,
                        fontWeight:
                            isValidated ? FontWeight.w700 : FontWeight.w600,
                        color: isValidated ? ink : c.textSecondary,
                      ),
                    ),
                ],
              ),
              if (meta != null) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    height: 1.35,
                    color: isPending ? c.textSecondary : ink,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _StepPath(
                withUnion: _showsUnion,
                current: step,
                fill: fill,
                color: isPending ? c.text : ink,
                track: isPending ? c.border : ink.withValues(alpha: 0.22),
                labelColor: isPending ? c.textSecondary : ink,
              ),
            ],
          ),
        ),
        if (hasNotes) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('evidence-section-note'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedComment01,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRejected
                          ? 'evidence_folder.detail.reviewer_note'.tr()
                          : 'evidence_folder.detail.evaluator_note'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    height: 1.4,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Equal segments: Archivos, Enviada, Campo local and, when the folder
/// requires it, Unión. Segments
/// before [current] are full; [current] fills to [fill]; the rest are track.
/// Screen readers get one label naming the current step.
class _StepPath extends StatelessWidget {
  const _StepPath({
    required this.withUnion,
    required this.current,
    required this.fill,
    required this.color,
    required this.track,
    required this.labelColor,
  });

  final bool withUnion;
  final int current;
  final double fill;
  final Color color;
  final Color track;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final names = [
      'evidence_folder.panel.step_files'.tr(),
      'evidence_folder.panel.step_sent'.tr(),
      'evidence_folder.panel.step_local_field'.tr(),
      if (withUnion) 'evidence_folder.panel.step_union'.tr(),
    ];
    return Semantics(
      container: true,
      label: 'evidence_folder.panel.step_semantics'.tr(namedArgs: {
        'current': '${current + 1}',
        'total': '${names.length}',
        'label': names[current],
      }),
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('evidence-section-step-path'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < names.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Segment(
                    fill: i < current ? 1 : (i == current ? fill : 0),
                    color: color,
                    track: track,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    names[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current
                          ? labelColor
                          : labelColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fill,
    required this.color,
    required this.track,
  });

  final double fill;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal;
    final radius = BorderRadius.circular(AppTheme.radiusHairline);
    return Container(
      height: 4,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fill),
        duration: duration,
        curve: SacMotion.easeOut,
        builder: (context, value, _) => FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}
