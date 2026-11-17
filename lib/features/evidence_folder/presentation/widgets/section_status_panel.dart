import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
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
    final notes = section.evaluationNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final (step, fill) = _progress();
    final names = [
      'evidence_folder.panel.step_files'.tr(),
      'evidence_folder.panel.step_sent'.tr(),
      'evidence_folder.panel.step_local_field'.tr(),
      if (_showsUnion) 'evidence_folder.panel.step_union'.tr(),
    ];

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

    return SacStatusPanel(
      key: const ValueKey('evidence-section-status-panel'),
      stepPathKey: const ValueKey('evidence-section-step-path'),
      style: style,
      trailing: trailing,
      emphasizeTrailing: isValidated,
      meta: _meta(context),
      steps: names,
      currentStep: step,
      fill: fill,
      stepsSemanticsLabel:
          'evidence_folder.panel.step_semantics'.tr(namedArgs: {
        'current': '${step + 1}',
        'total': '${names.length}',
        'label': names[step],
      }),
      note: hasNotes
          ? _ReviewerNote(notes: notes, isRejected: isRejected, c: c)
          : null,
    );
  }
}

class _ReviewerNote extends StatelessWidget {
  const _ReviewerNote({
    required this.notes,
    required this.isRejected,
    required this.c,
  });

  final String notes;
  final bool isRejected;
  final SacColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
