import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/entities/certification_requirement.dart';
import '../utils/certification_status_view.dart';

/// One requirement in any certification list: the same status icon, tone and
/// label as a class requirement, the title on up to two lines and the one line
/// that matters in its state.
class CertificationRequirementRow extends StatelessWidget {
  const CertificationRequirementRow({
    super.key,
    required this.section,
    required this.onTap,
  });

  final SectionProgress section;
  final VoidCallback onTap;

  String _date(DateTime? date) =>
      date == null ? '' : DateFormat('d MMM').format(date.toLocal());

  String _detail() {
    final s = section;
    switch (s.status) {
      case CertificationRequirementStatus.draft:
        return s.hasDraft
            ? 'certifications.row.draft'.tr()
            : 'certifications.row.not_started'.tr();
      case CertificationRequirementStatus.changesRequested:
        if (s.reviewedAt != null) {
          return 'certifications.row.returned_on'
              .tr(namedArgs: {'date': _date(s.reviewedAt)});
        }
        final note = (s.lastReviewComment ?? '').trim();
        return note.isEmpty
            ? 'certifications.row.returned_default'.tr()
            : '«$note»';
      case CertificationRequirementStatus.submitted:
        return s.submittedAt == null
            ? 'certifications.status.review'.tr()
            : 'certifications.row.sent_on'
                .tr(namedArgs: {'date': _date(s.submittedAt)});
      case CertificationRequirementStatus.approved:
        return s.reviewedAt == null
            ? 'certifications.status.validated'.tr()
            : 'certifications.row.validated_on'
                .tr(namedArgs: {'date': _date(s.reviewedAt)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = certificationRequirementStyle(context, section.status);
    final detail = _detail();
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'certifications.row.requirement_semantics'.tr(
        namedArgs: {
          'title': section.sectionName,
          'state': style.label,
          'detail': detail,
        },
      ),
      child: SacStatusRow(
        key: ValueKey('certification-requirement-${section.sectionId}'),
        style: style,
        title: section.sectionName,
        detail: detail,
        detailIsError: style.kind == SacStatusKind.rejected,
        onTap: onTap,
      ),
    );
  }
}
