import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/grouped_class_status.dart';

/// Where a requirement stands, in the same soft box as the evidence folder:
/// the state, one line of context and a path files → sent → local field. The
/// local field's note sits below the box when the requirement was sent back.
class RequirementStatusPanel extends StatelessWidget {
  const RequirementStatusPanel({
    super.key,
    required this.requirement,
    this.isReadOnly = false,
  });

  final ClassRequirement requirement;

  /// The class is closed (invested or expired): nothing can be sent.
  final bool isReadOnly;

  static String _date(DateTime date) =>
      DateFormat('d MMM').format(date.toLocal());

  /// The reason the local field gave when it sent the requirement back.
  static String? noteOf(ClassRequirement r) {
    final isSentBack = r.status == RequirementStatus.rechazado ||
        r.status == RequirementStatus.observado;
    if (!isSentBack) return null;
    final text = (r.rejectionReason ?? r.observationComment ?? '').trim();
    return text.isEmpty ? null : text;
  }

  String? _meta() {
    final r = requirement;
    switch (r.status) {
      case RequirementStatus.pendiente:
        return isReadOnly
            ? 'classes.grouped.req.meta_closed'.tr()
            : 'classes.grouped.req.meta_pending'.tr();
      case RequirementStatus.rechazado:
      case RequirementStatus.observado:
        final date = r.status == RequirementStatus.observado
            ? r.observedAt
            : r.rejectedAt;
        return date == null
            ? 'classes.grouped.req.meta_rejected_nodate'.tr()
            : 'classes.grouped.req.meta_rejected'
                .tr(namedArgs: {'date': _date(date)});
      case RequirementStatus.enviado:
        final date = r.submittedAt;
        return date == null
            ? 'classes.grouped.req.meta_sent_nodate'.tr()
            : 'classes.grouped.req.meta_sent'
                .tr(namedArgs: {'date': _date(date)});
      case RequirementStatus.validado:
        final date = r.validatedAt;
        return date == null
            ? null
            : 'classes.grouped.req.meta_validated'
                .tr(namedArgs: {'date': _date(date)});
    }
  }

  /// Index of the current step (0 files, 1 sent, 2 local field) and how much
  /// of it is done.
  (int, double) _progress() {
    final r = requirement;
    switch (r.status) {
      case RequirementStatus.pendiente:
        final ratio = r.maxFiles == 0 ? 0.0 : r.files.length / r.maxFiles;
        return (0, ratio.clamp(0.08, 1.0));
      case RequirementStatus.rechazado:
      case RequirementStatus.observado:
        return (0, 1);
      case RequirementStatus.enviado:
        return (2, 0.5);
      case RequirementStatus.validado:
        return (2, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final style = requirementStatusStyle(context, r.status);
    final (step, fill) = _progress();
    final names = [
      'classes.grouped.req.step_files'.tr(),
      'classes.grouped.req.step_sent'.tr(),
      'classes.grouped.req.step_local'.tr(),
    ];
    final note = noteOf(r);

    return SacStatusPanel(
      key: const ValueKey('requirement-status-panel'),
      stepPathKey: const ValueKey('requirement-step-path'),
      style: style,
      trailing: r.status == RequirementStatus.pendiente
          ? 'classes.grouped.files_of'.tr(namedArgs: {
              'count': '${r.files.length}',
              'max': '${r.maxFiles}',
            })
          : null,
      meta: _meta(),
      steps: names,
      currentStep: step,
      fill: fill,
      stepsSemanticsLabel: 'classes.grouped.req.step_semantics'.tr(namedArgs: {
        'current': '${step + 1}',
        'total': '${names.length}',
        'label': names[step],
      }),
      note: note == null ? null : _FieldNote(text: note),
    );
  }
}

class _FieldNote extends StatelessWidget {
  const _FieldNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('requirement-field-note'),
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
                'classes.grouped.req.note_title'.tr(),
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
            text,
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
