/// Límite del backend para el motivo de un rechazo.
const int kRejectionReasonMax = 1000;

/// Decisión que el autorizador toma sobre una persona antes de confirmar.
sealed class DecisionChoice {
  const DecisionChoice();
}

/// Investir, sin comentario.
class InvestChoice extends DecisionChoice {
  const InvestChoice();
}

/// Rechazar, con un motivo obligatorio que ve la directiva de la sección.
class RejectChoice extends DecisionChoice {
  const RejectChoice({required this.reason});

  final String reason;
}
