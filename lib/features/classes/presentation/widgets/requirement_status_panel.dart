import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/grouped_class_status.dart';

/// Steps of the requirement path: not sent, sent, validated.
const int kRequirementStepCount = 3;

String _shortDate(DateTime date) => DateFormat('d MMM').format(date.toLocal());

bool _isSentBack(ClassRequirement r) =>
    r.status == RequirementStatus.rechazado ||
    r.status == RequirementStatus.observado;

/// 1-based position of the requirement in its path. A returned requirement
/// goes back to the first step.
int requirementStepNumber(ClassRequirement r) {
  switch (r.status) {
    case RequirementStatus.pendiente:
    case RequirementStatus.rechazado:
    case RequirementStatus.observado:
      return 1;
    case RequirementStatus.enviado:
      return 2;
    case RequirementStatus.validado:
      return 3;
  }
}

/// The reason the local field gave when it sent the requirement back.
String? requirementNoteOf(ClassRequirement r) {
  if (!_isSentBack(r)) return null;
  final text = (r.rejectionReason ?? r.observationComment ?? '').trim();
  return text.isEmpty ? null : text;
}

/// One line of context under the state, or null when there is none.
String? _meta(ClassRequirement r, {required bool isReadOnly}) {
  switch (r.status) {
    case RequirementStatus.pendiente:
      return isReadOnly
          ? 'classes.grouped.req.meta_closed'.tr()
          : 'classes.grouped.req.meta_pending'.tr();
    case RequirementStatus.rechazado:
    case RequirementStatus.observado:
      final date =
          r.status == RequirementStatus.observado ? r.observedAt : r.rejectedAt;
      return date == null
          ? 'classes.grouped.req.meta_rejected_nodate'.tr()
          : 'classes.grouped.req.meta_rejected'
              .tr(namedArgs: {'date': _shortDate(date)});
    case RequirementStatus.enviado:
      final date = r.submittedAt;
      return date == null
          ? 'classes.grouped.req.meta_sent_nodate'.tr()
          : 'classes.grouped.req.meta_sent'
              .tr(namedArgs: {'date': _shortDate(date)});
    case RequirementStatus.validado:
      final date = r.validatedAt;
      return date == null
          ? null
          : 'classes.grouped.req.meta_validated'
              .tr(namedArgs: {'date': _shortDate(date)});
  }
}

/// Opens the sheet with every state of the requirement: not sent, sent and
/// validated (done, current or next, with dates) and, apart, "To fix".
Future<void> showRequirementStatesSheet(
  BuildContext context, {
  required ClassRequirement requirement,
  bool isReadOnly = false,
}) {
  final r = requirement;
  final sentBack = _isSentBack(r);
  final current = requirementStepNumber(r) - 1;
  final sentDate = r.submittedAt == null ? null : _shortDate(r.submittedAt!);
  final validatedDate =
      r.validatedAt == null ? null : _shortDate(r.validatedAt!);

  SacStateKind kindOf(int index) {
    if (sentBack) return SacStateKind.pending;
    if (index < current) return SacStateKind.done;
    if (index == current) return SacStateKind.current;
    return SacStateKind.pending;
  }

  final steps = <SacStateStep>[
    SacStateStep(
      kind: kindOf(0),
      title: 'classes.grouped.state_pending'.tr(),
      detail: kindOf(0) == SacStateKind.done
          ? 'classes.grouped.req.sheet_uploaded'.plural(r.files.length)
          : (isReadOnly
              ? 'classes.grouped.req.meta_closed'.tr()
              : 'classes.grouped.req.meta_pending'.tr()),
    ),
    SacStateStep(
      kind: kindOf(1),
      title: 'classes.grouped.state_review'.tr(),
      detail: switch (kindOf(1)) {
        SacStateKind.done => sentDate == null
            ? null
            : 'classes.grouped.sent_on'.tr(namedArgs: {'date': sentDate}),
        SacStateKind.current => sentDate == null
            ? 'classes.grouped.req.sheet_sent_current_nodate'.tr()
            : 'classes.grouped.req.sheet_sent_current'
                .tr(namedArgs: {'date': sentDate}),
        _ => 'classes.grouped.req.sheet_sent_next'.tr(),
      },
    ),
    SacStateStep(
      kind: kindOf(2),
      title: 'classes.grouped.state_validated'.tr(),
      detail: kindOf(2) == SacStateKind.current && validatedDate != null
          ? 'classes.grouped.validated_on'
              .tr(namedArgs: {'date': validatedDate})
          : 'classes.grouped.req.sheet_validated_next'.tr(),
    ),
  ];

  return showSacStatesSheet(
    context,
    title: 'classes.grouped.req.sheet_title'.tr(),
    subtitle: r.name,
    steps: steps,
    detour: SacStateStep(
      kind: sentBack ? SacStateKind.rejected : SacStateKind.pending,
      title: 'classes.grouped.state_rejected'.tr(),
      detail: sentBack
          ? _meta(r, isReadOnly: isReadOnly)
          : 'classes.grouped.req.sheet_fix_hint'.tr(),
    ),
    kindLabels: SacStateKindLabels(
      done: 'classes.grouped.req.kind_done'.tr(),
      current: 'classes.grouped.req.kind_current'.tr(),
      rejected: 'classes.grouped.req.kind_rejected'.tr(),
      pending: 'classes.grouped.req.kind_pending'.tr(),
    ),
  );
}

/// Where a requirement stands, in a card: the current state, the date or what
/// comes next, and "Step N of 3". Tapping it opens the list of every state.
/// The local field's note sits right under it when the requirement was sent
/// back.
///
/// A requirement linked to an honor says so ("Pending · It validates itself
/// when you complete the honor") instead of talking about files.
class RequirementStatusPanel extends StatelessWidget {
  const RequirementStatusPanel({
    super.key,
    required this.requirement,
    this.isReadOnly = false,
  });

  final ClassRequirement requirement;

  /// The class is closed (invested or expired): nothing can be sent.
  final bool isReadOnly;

  /// The reason the local field gave when it sent the requirement back.
  static String? noteOf(ClassRequirement r) => requirementNoteOf(r);

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final isHonor = r.linkedHonorId != null;
    final isHonorDone = isHonor &&
        (r.linkedHonorCompleted == true ||
            r.status == RequirementStatus.validado);

    final SacStatusStyle style;
    final String title;
    final String? message;
    final String stepLabel;
    final String semanticsState;
    if (isHonor) {
      style = SacStatusStyle.of(
        context,
        isHonorDone ? SacStatusKind.validated : SacStatusKind.pending,
        label: '',
        icon: HugeIcons.strokeRoundedAward01,
      );
      title = isHonorDone
          ? 'classes.requirement_detail.honor_completed'.tr()
          : 'classes.requirement_detail.honor_pending'.tr();
      message = isHonorDone
          ? 'classes.requirement_detail.honor_done_message'.tr()
          : 'classes.requirement_detail.honor_pending_message'.tr();
      stepLabel = 'classes.requirement_detail.linked_honor_title'.tr();
      semanticsState = title;
    } else {
      style = requirementStatusStyle(context, r.status);
      title = style.label;
      message = _meta(r, isReadOnly: isReadOnly);
      final stepArgs = {
        'step': '${requirementStepNumber(r)}',
        'total': '$kRequirementStepCount',
      };
      stepLabel = 'classes.grouped.req.step_of'.tr(namedArgs: stepArgs);
      semanticsState = title;
    }
    final note = requirementNoteOf(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacStatePanel(
          key: const ValueKey('requirement-status-panel'),
          style: style,
          title: title,
          message: message,
          stepLabel: stepLabel,
          semanticsHint: 'classes.grouped.req.panel_hint'.tr(),
          semanticsLabel: [
            'classes.grouped.req.panel_semantics'.tr(namedArgs: {
              'state': semanticsState,
              'step': '${requirementStepNumber(r)}',
              'total': '$kRequirementStepCount',
            }),
            if (message != null) message,
          ].join('. '),
          onTap: () => showRequirementStatesSheet(
            context,
            requirement: r,
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

/// The local field's note, quoted in a white card.
class _FieldNote extends StatelessWidget {
  const _FieldNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('requirement-field-note'),
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
            'classes.grouped.req.note_title'.tr().toUpperCase(),
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
