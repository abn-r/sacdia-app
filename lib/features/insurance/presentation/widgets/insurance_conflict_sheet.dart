import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/insurance_conflict.dart';
import 'insurance_action_sheet.dart';
import 'insurance_ui.dart';

/// Why [conflict] cannot go in the order, in one sentence.
String insuranceConflictReason(InsuranceConflict conflict) {
  switch (conflict.reason) {
    case InsuranceConflictReason.alreadyCovered:
      final place = conflict.sectionName ?? conflict.clubName;
      return place == null
          ? tr('insurance.conflict.covered_elsewhere')
          : tr('insurance.conflict.covered_in', namedArgs: {'place': place});
    case InsuranceConflictReason.inLiveOrder:
      final folio = conflict.folio;
      return folio == null
          ? tr('insurance.conflict.in_order')
          : tr('insurance.conflict.in_order_folio',
              namedArgs: {'folio': folio});
  }
}

/// "Conflicto al emitir": someone got insured, or entered another order,
/// while the director was building this one. Explains who and why.
///
/// [remainingCount] / [remainingTotal] describe the order without them. When
/// nobody is left the only action is to review the list. Returns `true` to
/// issue the order with the rest.
Future<bool?> showInsuranceConflictSheet(
  BuildContext context, {
  required List<InsuranceConflict> conflicts,
  required int remainingCount,
  required String remainingTotal,
}) {
  final single = conflicts.length == 1 ? conflicts.first : null;
  final title = single == null
      ? tr(
          'insurance.conflict.title_many',
          namedArgs: {'count': '${conflicts.length}'},
        )
      : tr(
          single.reason == InsuranceConflictReason.alreadyCovered
              ? 'insurance.conflict.title_covered'
              : 'insurance.conflict.title_in_order',
          namedArgs: {'name': single.name},
        );
  final outcome = remainingCount > 0
      ? 'insurance.conflict.outcome'.plural(
          remainingCount,
          namedArgs: {'total': remainingTotal},
        )
      : tr('insurance.conflict.outcome_none');

  return showInsuranceActionSheet(
    context,
    title: title,
    body: single == null
        ? outcome
        : '${insuranceConflictReason(single)} $outcome',
    content: single == null ? _ConflictList(conflicts: conflicts) : null,
    primaryLabel: remainingCount > 0
        ? 'insurance.conflict.issue_remaining'.plural(remainingCount)
        : tr('insurance.conflict.review_list'),
    secondaryLabel:
        remainingCount > 0 ? tr('insurance.conflict.review_list') : null,
  ).then((value) => remainingCount > 0 ? value : false);
}

class _ConflictList extends StatelessWidget {
  const _ConflictList({required this.conflicts});

  final List<InsuranceConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      children: [
        for (final conflict in conflicts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                InsuranceAvatar(name: conflict.name, muted: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.name,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      Text(
                        insuranceConflictReason(conflict),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
