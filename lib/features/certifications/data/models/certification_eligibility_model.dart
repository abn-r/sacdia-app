import '../../domain/entities/certification_eligibility.dart';

/// Modelo de datos para la evaluación de una regla de elegibilidad.
class CertificationEligibilityRuleModel {
  final int ruleId;
  final String type;
  final bool satisfied;
  final String? reasonCode;

  const CertificationEligibilityRuleModel({
    required this.ruleId,
    required this.type,
    required this.satisfied,
    this.reasonCode,
  });

  factory CertificationEligibilityRuleModel.fromJson(
      Map<String, dynamic> json) {
    return CertificationEligibilityRuleModel(
      ruleId: (json['eligibility_rule_id'] ?? json['rule_id'] ?? 0) as int,
      type: json['type'] as String,
      satisfied: json['satisfied'] as bool? ?? false,
      reasonCode: json['reason_code'] as String?,
    );
  }

  CertificationEligibilityRule toEntity() {
    return CertificationEligibilityRule(
      ruleId: ruleId,
      type: type,
      satisfied: satisfied,
      reasonCode: reasonCode,
    );
  }
}

/// Modelo de datos para el resultado de elegibilidad de una certificación.
class CertificationEligibilityModel {
  final bool eligible;
  final List<CertificationEligibilityRuleModel> rules;
  final String? reasonCode;

  const CertificationEligibilityModel({
    required this.eligible,
    required this.rules,
    this.reasonCode,
  });

  factory CertificationEligibilityModel.fromJson(Map<String, dynamic> json) {
    return CertificationEligibilityModel(
      eligible: json['eligible'] as bool? ?? false,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((r) => CertificationEligibilityRuleModel.fromJson(
                  r as Map<String, dynamic>))
              .toList() ??
          [],
      reasonCode: json['reason_code'] as String?,
    );
  }

  CertificationEligibility toEntity() {
    return CertificationEligibility(
      eligible: eligible,
      rules: rules.map((r) => r.toEntity()).toList(),
      reasonCode: reasonCode,
    );
  }
}
