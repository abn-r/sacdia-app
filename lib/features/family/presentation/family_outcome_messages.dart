import 'package:easy_localization/easy_localization.dart';

import '../domain/entities/dependent.dart';

/// Qué le pasará a un menor cuando su tutor lo deje, según el contexto actual.
///
/// Refleja la regla del servidor: si queda otro tutor humano, sigue a su
/// cargo; si no, y el menor tiene solicitud o membresía vigente en un club, el
/// club asume la custodia; si no, se congela y se borra a los 90 días. El
/// servidor decide al ejecutar y devuelve el resultado real; esto solo avisa
/// ANTES de confirmar.
DependentOutcome predictLeaveOutcome(DependentDetail detail) {
  if (detail.otherGuardians.isNotEmpty) return DependentOutcome.otherGuardian;
  final membership = detail.summary.clubMembership;
  if (membership != null && (membership.isActive || membership.isPending)) {
    return DependentOutcome.clubCustody;
  }
  return DependentOutcome.frozen;
}

/// Frase del resultado ("Otro tutor seguirá a cargo de Ana.").
String outcomeMessage(DependentOutcome outcome, String name) {
  return switch (outcome) {
    DependentOutcome.otherGuardian =>
      'family.outcome.other_guardian'.tr(namedArgs: {'name': name}),
    DependentOutcome.clubCustody =>
      'family.outcome.club_custody'.tr(namedArgs: {'name': name}),
    DependentOutcome.frozen =>
      'family.outcome.frozen'.tr(namedArgs: {'name': name}),
  };
}
