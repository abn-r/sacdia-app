import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification_requirement.dart';
import '../utils/certification_status_view.dart';

/// Steps of the requirement path: not sent, sent, validated.
const int kCertificationStepCount = 3;

String _shortDate(DateTime date) => DateFormat('d MMM').format(date.toLocal());

/// What the panel and the states sheet need to know about a requirement (or
/// about the closeout, which behaves like one).
class CertificationStepInfo {
  const CertificationStepInfo({
    required this.name,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.note,
    this.reviewTitle,
    this.validatedTitle,
  });

  factory CertificationStepInfo.fromRequirement(
    CertificationRequirement requirement,
  ) =>
      CertificationStepInfo(
        name: requirement.name,
        status: requirement.status,
        submittedAt: requirement.submittedAt,
        reviewedAt: requirement.reviewedAt,
        note: requirement.lastReviewComment,
      );

  final String name;
  final CertificationRequirementStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// What the local field wrote when it sent it back.
  final String? note;

  /// Replace «Enviado» / «Validado» (the closeout says «En revisión final» /
  /// «Certificada»).
  final String? reviewTitle;
  final String? validatedTitle;

  bool get isSentBack =>
      status == CertificationRequirementStatus.changesRequested;

  /// The reason the local field gave; only while the requirement is sent back.
  String? get returnedNote {
    if (!isSentBack) return null;
    final text = (note ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// 1-based position in the path. A returned requirement goes back to the
  /// first step.
  int get stepNumber {
    switch (status) {
      case CertificationRequirementStatus.draft:
      case CertificationRequirementStatus.changesRequested:
        return 1;
      case CertificationRequirementStatus.submitted:
        return 2;
      case CertificationRequirementStatus.approved:
        return 3;
    }
  }
}

String? _meta(CertificationStepInfo r, {required bool isReadOnly}) {
  switch (r.status) {
    case CertificationRequirementStatus.draft:
      return isReadOnly
          ? 'certifications.req.meta_closed'.tr()
          : 'certifications.req.meta_pending'.tr();
    case CertificationRequirementStatus.changesRequested:
      final date = r.reviewedAt;
      return date == null
          ? 'certifications.req.meta_rejected_nodate'.tr()
          : 'certifications.req.meta_rejected'
              .tr(namedArgs: {'date': _shortDate(date)});
    case CertificationRequirementStatus.submitted:
      final date = r.submittedAt;
      return date == null
          ? 'certifications.req.meta_sent_nodate'.tr()
          : 'certifications.req.meta_sent'
              .tr(namedArgs: {'date': _shortDate(date)});
    case CertificationRequirementStatus.approved:
      final date = r.reviewedAt;
      return date == null
          ? null
          : 'certifications.req.meta_validated'
              .tr(namedArgs: {'date': _shortDate(date)});
  }
}

/// Opens the sheet with every state: not sent, sent and validated (done,
/// current or next, with dates) and, apart, «Por corregir». The same sheet as
/// a class requirement.
Future<void> showCertificationStatesSheet(
  BuildContext context, {
  required CertificationStepInfo info,
  bool isReadOnly = false,
}) {
  final r = info;
  final sentBack = r.isSentBack;
  final current = r.stepNumber - 1;
  final sentDate = r.submittedAt == null ? null : _shortDate(r.submittedAt!);
  final validatedDate = r.reviewedAt == null ? null : _shortDate(r.reviewedAt!);

  SacStateKind kindOf(int index) {
    if (sentBack) return SacStateKind.pending;
    if (index < current) return SacStateKind.done;
    if (index == current) return SacStateKind.current;
    return SacStateKind.pending;
  }

  final steps = <SacStateStep>[
    SacStateStep(
      kind: kindOf(0),
      title: 'certifications.status.pending'.tr(),
      detail: kindOf(0) == SacStateKind.done
          ? 'certifications.req.sheet_filled'.tr()
          : (isReadOnly
              ? 'certifications.req.meta_closed'.tr()
              : 'certifications.req.meta_pending'.tr()),
    ),
    SacStateStep(
      kind: kindOf(1),
      title: r.reviewTitle ?? 'certifications.status.review'.tr(),
      detail: switch (kindOf(1)) {
        SacStateKind.done => sentDate == null
            ? null
            : 'certifications.row.sent_on'.tr(namedArgs: {'date': sentDate}),
        SacStateKind.current => sentDate == null
            ? 'certifications.req.sheet_sent_current_nodate'.tr()
            : 'certifications.req.sheet_sent_current'
                .tr(namedArgs: {'date': sentDate}),
        _ => 'certifications.req.sheet_sent_next'.tr(),
      },
    ),
    SacStateStep(
      kind: kindOf(2),
      title: r.validatedTitle ?? 'certifications.status.validated'.tr(),
      detail: kindOf(2) == SacStateKind.current && validatedDate != null
          ? 'certifications.row.validated_on'
              .tr(namedArgs: {'date': validatedDate})
          : 'certifications.req.sheet_validated_next'.tr(),
    ),
  ];

  return showSacStatesSheet(
    context,
    title: 'certifications.req.sheet_title'.tr(),
    subtitle: r.name,
    steps: steps,
    detour: SacStateStep(
      kind: sentBack ? SacStateKind.rejected : SacStateKind.pending,
      title: 'certifications.status.rejected'.tr(),
      detail: sentBack
          ? _meta(r, isReadOnly: isReadOnly)
          : 'certifications.req.sheet_fix_hint'.tr(),
    ),
    kindLabels: SacStateKindLabels(
      done: 'certifications.req.kind_done'.tr(),
      current: 'certifications.req.kind_current'.tr(),
      rejected: 'certifications.req.kind_rejected'.tr(),
      pending: 'certifications.req.kind_pending'.tr(),
    ),
  );
}

/// Where a requirement stands, in a card: the current state, the date or what
/// comes next, and «Paso N de 3». Tapping it opens the list of every state.
/// The local field's note sits right under it, once, when it was sent back.
class CertificationStatusPanel extends StatelessWidget {
  const CertificationStatusPanel({
    super.key,
    required this.info,
    this.isReadOnly = false,
  });

  final CertificationStepInfo info;

  /// Nothing can be sent any more (the certification is closed).
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final r = info;
    final base = certificationRequirementStyle(context, r.status);
    final title = switch (r.status) {
      CertificationRequirementStatus.submitted => r.reviewTitle ?? base.label,
      CertificationRequirementStatus.approved => r.validatedTitle ?? base.label,
      _ => base.label,
    };
    final message = _meta(r, isReadOnly: isReadOnly);
    final stepArgs = {
      'step': '${r.stepNumber}',
      'total': '$kCertificationStepCount',
    };
    final note = r.returnedNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacStatePanel(
          key: const ValueKey('certification-status-panel'),
          style: base,
          title: title,
          message: message,
          stepLabel: 'certifications.req.step_of'.tr(namedArgs: stepArgs),
          semanticsHint: 'certifications.req.panel_hint'.tr(),
          semanticsLabel: [
            'certifications.req.panel_semantics'.tr(
              namedArgs: {'state': title, ...stepArgs},
            ),
            if (message != null) message,
          ].join('. '),
          onTap: () => showCertificationStatesSheet(
            context,
            info: r,
            isReadOnly: isReadOnly,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 12),
          _FieldNote(text: note),
        ],
      ],
    );
  }
}

/// The local field's note, quoted in a card. Shown once per screen.
class _FieldNote extends StatelessWidget {
  const _FieldNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('certification-field-note'),
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
            'certifications.req.note_title'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '«$text»',
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
