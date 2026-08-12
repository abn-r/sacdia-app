import 'package:equatable/equatable.dart';

/// Evaluación de una regla de elegibilidad para inscribirse a una
/// certificación (MIN_AGE, BAPTIZED, INVESTED_CLASS, ACTIVE_CLUB_TYPE,
/// ACTIVE_ROLE).
class CertificationEligibilityRule extends Equatable {
  final int ruleId;
  final String type;
  final bool satisfied;

  /// Código de motivo cuando no se cumple (p.ej. AGE_TOO_LOW, NOT_BAPTIZED).
  final String? reasonCode;

  const CertificationEligibilityRule({
    required this.ruleId,
    required this.type,
    required this.satisfied,
    this.reasonCode,
  });

  @override
  List<Object?> get props => [ruleId, type, satisfied, reasonCode];
}

/// Resultado de elegibilidad de un usuario para una certificación,
/// explicable regla por regla.
class CertificationEligibility extends Equatable {
  final bool eligible;
  final List<CertificationEligibilityRule> rules;

  /// Código de motivo a nivel versión (p.ej. NO_RULES_CONFIGURED).
  final String? reasonCode;

  const CertificationEligibility({
    required this.eligible,
    required this.rules,
    this.reasonCode,
  });

  @override
  List<Object?> get props => [eligible, rules, reasonCode];
}
