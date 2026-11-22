import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification_eligibility.dart';
import 'certification_sections.dart';

/// «Requisitos de inscripción»: every rule the server evaluated, with a check
/// when it is met and a clock when it is not yet.
class CertificationEligibilitySection extends StatelessWidget {
  const CertificationEligibilitySection({super.key, required this.eligibility});

  final CertificationEligibility eligibility;

  static String ruleTitle(CertificationEligibilityRuleType type) {
    switch (type) {
      case CertificationEligibilityRuleType.minAge:
        return 'certifications.eligibility.min_age'.tr();
      case CertificationEligibilityRuleType.baptized:
        return 'certifications.eligibility.baptized'.tr();
      case CertificationEligibilityRuleType.investedClass:
        return 'certifications.eligibility.invested_class'.tr();
      case CertificationEligibilityRuleType.activeClubType:
        return 'certifications.eligibility.active_club_type'.tr();
      case CertificationEligibilityRuleType.activeRole:
        return 'certifications.eligibility.active_role'.tr();
      case CertificationEligibilityRuleType.unknown:
        return 'certifications.eligibility.unknown'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = eligibility.rules;
    if (rules.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('certification-eligibility-section'),
      label: 'certifications.eligibility.title'.tr(),
      count: rules.length,
      children: [
        for (final (i, rule) in rules.indexed)
          CertificationRuleRow(
            key: ValueKey('certification-rule-$i'),
            title: ruleTitle(rule.type),
            satisfied: rule.satisfied,
          ),
      ],
    );
  }
}
