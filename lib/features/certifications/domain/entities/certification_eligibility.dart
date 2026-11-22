import 'package:equatable/equatable.dart';

/// Tipo de regla de elegibilidad para inscribirse en una certificación.
enum CertificationEligibilityRuleType {
  minAge,
  baptized,
  investedClass,
  activeClubType,
  activeRole,
  unknown,
}

CertificationEligibilityRuleType certificationEligibilityRuleTypeFromWire(
  String? value,
) {
  switch (value) {
    case 'MIN_AGE':
      return CertificationEligibilityRuleType.minAge;
    case 'BAPTIZED':
      return CertificationEligibilityRuleType.baptized;
    case 'INVESTED_CLASS':
      return CertificationEligibilityRuleType.investedClass;
    case 'ACTIVE_CLUB_TYPE':
      return CertificationEligibilityRuleType.activeClubType;
    case 'ACTIVE_ROLE':
      return CertificationEligibilityRuleType.activeRole;
    default:
      return CertificationEligibilityRuleType.unknown;
  }
}

/// Una regla de elegibilidad evaluada por el servidor.
class CertificationEligibilityRule extends Equatable {
  final int? ruleId;
  final CertificationEligibilityRuleType type;
  final bool satisfied;
  final String? reasonCode;

  const CertificationEligibilityRule({
    this.ruleId,
    required this.type,
    required this.satisfied,
    this.reasonCode,
  });

  @override
  List<Object?> get props => [ruleId, type, satisfied, reasonCode];
}

/// Resultado de `GET .../certifications/:id/eligibility`.
class CertificationEligibility extends Equatable {
  final bool eligible;
  final List<CertificationEligibilityRule> rules;
  final String? reasonCode;

  const CertificationEligibility({
    required this.eligible,
    this.rules = const [],
    this.reasonCode,
  });

  @override
  List<Object?> get props => [eligible, rules, reasonCode];
}
