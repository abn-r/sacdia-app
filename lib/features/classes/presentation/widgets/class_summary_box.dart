import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/grouped_class_status.dart';
import '../utils/member_requirement_groups.dart';
import 'grouped_summary_box.dart';

/// Legend of the class summary bar: validated, sent, to fix and not sent.
SacStatusCountLabels classSummaryLabels(StatusCounts counts) {
  final base = groupedCountLabels(counts);
  return SacStatusCountLabels(
    validated: base.validated,
    review: 'classes.detail_with_progress.legend_sent'.plural(counts.review),
    rejected: base.rejected,
    pending: base.pending,
  );
}

/// "{validated} de {total} · faltan {n}" with the composition bar and its
/// legend. Only validated counts as progress. Used by the class screen
/// (whole class, with [footer]) and by the module screen ([label] left out).
class ClassSummaryBox extends StatelessWidget {
  const ClassSummaryBox({
    super.key,
    required this.requirements,
    this.label,
    this.footer,
  });

  final List<ClassRequirement> requirements;
  final String? label;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final counts = countRequirements(requirements).toStatusCounts();
    final missing = counts.total - counts.validated;
    return GroupedSummaryBox(
      label: label,
      value: 'classes.grouped.ready_count'.tr(namedArgs: {
        'ready': '${counts.validated}',
        'total': '${counts.total}',
      }),
      valueSuffix:
          missing > 0 ? 'classes.grouped.missing'.plural(missing) : null,
      counts: counts,
      countLabels: classSummaryLabels(counts),
      footer: footer,
    );
  }
}
