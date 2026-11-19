import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/grouped_class_status.dart';

/// One requirement in any class list: the same status icon, tone and label
/// everywhere (not sent folder, sent plane, validated check, to fix alert),
/// the title on up to two lines and the one line that matters in its state.
///
/// A requirement linked to an honor says so on the line when there is
/// nothing else to say (not sent, no files yet).
class RequirementCard extends StatelessWidget {
  const RequirementCard({
    super.key,
    required this.requirement,
    required this.onTap,
    this.showUnsentFiles = false,
  });

  final ClassRequirement requirement;
  final VoidCallback onTap;

  /// "2 files not sent" for a requirement started but not sent (the
  /// "Por atender" list). Otherwise the line reads "2 de 10 archivos".
  final bool showUnsentFiles;

  String _date(DateTime? date) =>
      date == null ? '' : DateFormat('d MMM').format(date.toLocal());

  String _detail() {
    final r = requirement;
    switch (r.status) {
      case RequirementStatus.pendiente:
        if (r.files.isEmpty) {
          final honor = r.linkedHonorName?.trim() ?? '';
          return honor.isEmpty
              ? 'classes.grouped.no_files'.tr()
              : 'classes.detail_with_progress.honor_linked'
                  .tr(namedArgs: {'name': honor});
        }
        if (showUnsentFiles) {
          return r.files.length == 1
              ? 'classes.detail_with_progress.files_unsent_one'.tr()
              : 'classes.detail_with_progress.files_unsent_other'
                  .tr(namedArgs: {'count': '${r.files.length}'});
        }
        return 'classes.grouped.files_of'.tr(namedArgs: {
          'count': '${r.files.length}',
          'max': '${r.maxFiles}',
        });
      case RequirementStatus.rechazado:
      case RequirementStatus.observado:
        final date = r.rejectedAt ?? r.observedAt;
        if (date != null) {
          return 'classes.detail_with_progress.returned_on'
              .tr(namedArgs: {'date': _date(date)});
        }
        final note = (r.rejectionReason ?? r.observationComment ?? '').trim();
        return note.isEmpty
            ? 'classes.grouped.returned_default'.tr()
            : '«$note»';
      case RequirementStatus.enviado:
        return r.submittedAt == null
            ? 'classes.grouped.state_review'.tr()
            : 'classes.grouped.sent_on'
                .tr(namedArgs: {'date': _date(r.submittedAt)});
      case RequirementStatus.validado:
        return r.validatedAt == null
            ? 'classes.grouped.state_validated'.tr()
            : 'classes.grouped.validated_on'
                .tr(namedArgs: {'date': _date(r.validatedAt)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final style = requirementStatusStyle(context, r.status);
    final detail = _detail();
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'classes.detail_with_progress.requirement_semantics'.tr(
        namedArgs: {'title': r.name, 'state': style.label, 'detail': detail},
      ),
      child: SacStatusRow(
        key: ValueKey('grouped-requirement-${r.id}'),
        style: style,
        title: r.name,
        detail: detail,
        detailIsError:
            requirementStatusKind(r.status) == SacStatusKind.rejected,
        onTap: onTap,
      ),
    );
  }
}
