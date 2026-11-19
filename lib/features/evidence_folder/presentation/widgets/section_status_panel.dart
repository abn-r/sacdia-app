import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/evidence_section.dart';
import 'evidence_folder_summary.dart';
import 'section_status_style.dart';

/// Where a section stands, in a card: the current state, one line of context
/// and "Step N of M". Tapping it opens the list of every state (not sent →
/// sent → [approved by the local field →] validated, plus "To fix" apart).
///
/// The union's confirmation is a step only when the folder requires it.
/// Otherwise the local field validates directly (`SUBMITTED → VALIDATED` in
/// the backend). The reviewer's note sits right under the card.
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

  int get _stepCount => _showsUnion ? 4 : 3;

  /// 0-based position in the path. A returned section goes back to the start.
  int get _stepIndex {
    switch (section.status) {
      case EvidenceSectionStatus.pending:
      case EvidenceSectionStatus.rejected:
        return 0;
      case EvidenceSectionStatus.submitted:
        return 1;
      case EvidenceSectionStatus.preapprovedLf:
        return 2;
      case EvidenceSectionStatus.validated:
        return _stepCount - 1;
    }
  }

  static String _date(BuildContext context, DateTime date) =>
      DateFormat('d MMM', Localizations.localeOf(context).toString())
          .format(date.toLocal());

  DateTime? get _validatedDate =>
      section.unionApprovedAt ?? section.validatedAt ?? section.evaluatedAt;

  DateTime? get _returnedDate =>
      section.evaluatedAt ?? section.unionApprovedAt ?? section.lfApprovedAt;

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
        final date = _validatedDate;
        return date == null
            ? null
            : 'evidence_folder.panel.validated_on'
                .tr(namedArgs: {'date': _date(context, date)});
      case EvidenceSectionStatus.rejected:
        final date = _returnedDate;
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

  void _openStates(BuildContext context) {
    final current = _stepIndex;
    final sentBack = section.status == EvidenceSectionStatus.rejected;

    SacStateKind kindOf(int index) {
      if (sentBack) return SacStateKind.pending;
      if (index < current) return SacStateKind.done;
      if (index == current) return SacStateKind.current;
      return SacStateKind.pending;
    }

    String? dateOf(DateTime? date) =>
        date == null ? null : _date(context, date);

    final sent = dateOf(section.submittedAt);
    final approved = dateOf(section.lfApprovedAt);
    final validated = dateOf(_validatedDate);

    final stepsData = <(String, String?)>[];
    stepsData.add((
      'evidence_folder.state.pending'.tr(),
      kindOf(0) == SacStateKind.done
          ? 'evidence_folder.panel.sheet_uploaded'.plural(section.files.length)
          : (folderIsOpen
              ? 'evidence_folder.panel.pending_hint'.tr()
              : 'evidence_folder.panel.folder_closed'.tr()),
    ));
    stepsData.add((
      'evidence_folder.state.submitted'.tr(),
      switch (kindOf(1)) {
        SacStateKind.done => sent == null
            ? null
            : 'evidence_folder.row.submitted_on'.tr(namedArgs: {'date': sent}),
        SacStateKind.current => sent == null
            ? 'evidence_folder.panel.sheet_sent_current_nodate'.tr()
            : 'evidence_folder.panel.sheet_sent_current'
                .tr(namedArgs: {'date': sent}),
        _ => 'evidence_folder.panel.sheet_sent_next'.tr(),
      },
    ));
    if (_showsUnion) {
      stepsData.add((
        'evidence_folder.state.preapproved'.tr(),
        switch (kindOf(2)) {
          SacStateKind.done => approved == null
              ? null
              : 'evidence_folder.panel.sheet_approved_on'
                  .tr(namedArgs: {'date': approved}),
          SacStateKind.current => 'evidence_folder.panel.waiting_union'.tr(),
          _ => 'evidence_folder.panel.sheet_union_next'.tr(),
        },
      ));
    }
    final lastKind = kindOf(_stepCount - 1);
    stepsData.add((
      'evidence_folder.state.validated'.tr(),
      lastKind == SacStateKind.current && validated != null
          ? 'evidence_folder.panel.validated_on'
              .tr(namedArgs: {'date': validated})
          : 'evidence_folder.panel.sheet_validated_next'.tr(),
    ));

    showSacStatesSheet(
      context,
      title: 'evidence_folder.panel.sheet_title'.tr(),
      subtitle: section.name,
      steps: [
        for (var i = 0; i < stepsData.length; i++)
          SacStateStep(
            kind: kindOf(i),
            title: stepsData[i].$1,
            detail: stepsData[i].$2,
          ),
      ],
      detour: SacStateStep(
        kind: sentBack ? SacStateKind.rejected : SacStateKind.pending,
        title: 'evidence_folder.state.rejected'.tr(),
        detail: sentBack
            ? _meta(context)
            : 'evidence_folder.panel.sheet_fix_hint'.tr(),
      ),
      kindLabels: SacStateKindLabels(
        done: 'evidence_folder.panel.kind_done'.tr(),
        current: 'evidence_folder.panel.kind_current'.tr(),
        rejected: 'evidence_folder.panel.kind_rejected'.tr(),
        pending: 'evidence_folder.panel.kind_pending'.tr(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = EvidenceStatusStyle.of(context, section.status);
    final isValidated = section.status == EvidenceSectionStatus.validated;
    final isRejected = section.status == EvidenceSectionStatus.rejected;
    final notes = section.evaluationNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final message = _meta(context);
    final stepArgs = {'step': '${_stepIndex + 1}', 'total': '$_stepCount'};

    // A validated section says its points where the others offer the list of
    // states.
    final stepLabel = isValidated
        ? 'evidence_folder.panel.step_of_points'.tr(namedArgs: {
            ...stepArgs,
            'points': 'evidence_folder.row.points'.tr(namedArgs: {
              'earned': formatEvidencePoints(context, section.earnedPoints),
              'max': formatEvidencePoints(context, section.pointValue),
            }),
          })
        : 'evidence_folder.panel.step_of'.tr(namedArgs: stepArgs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacStatePanel(
          key: const ValueKey('evidence-section-status-panel'),
          style: style,
          title: style.label,
          message: message,
          stepLabel: stepLabel,
          semanticsHint: 'evidence_folder.panel.panel_hint'.tr(),
          semanticsLabel: [
            'evidence_folder.panel.panel_semantics'.tr(namedArgs: {
              'state': style.label,
              ...stepArgs,
            }),
            if (message != null) message,
          ].join('. '),
          onTap: () => _openStates(context),
        ),
        if (hasNotes) ...[
          const SizedBox(height: 12),
          _ReviewerNote(notes: notes, isRejected: isRejected),
        ],
      ],
    );
  }
}

/// The reviewer's note, quoted in a white card.
class _ReviewerNote extends StatelessWidget {
  const _ReviewerNote({required this.notes, required this.isRejected});

  final String notes;
  final bool isRejected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('evidence-section-note'),
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
            (isRejected
                    ? 'evidence_folder.detail.reviewer_note'
                    : 'evidence_folder.detail.evaluator_note')
                .tr()
                .toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '«$notes»',
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
