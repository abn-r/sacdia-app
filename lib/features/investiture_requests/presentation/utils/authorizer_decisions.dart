/// Límites del backend: comentario de la autorización y motivo del rechazo.
const int kAuthorizationCommentMax = 500;
const int kRejectionReasonMax = 1000;

/// Decisión que el autorizador toma sobre una persona antes de confirmar.
sealed class DecisionChoice {
  const DecisionChoice();
}

/// Investir, con un comentario opcional que verá la persona en su estado.
class InvestChoice extends DecisionChoice {
  const InvestChoice({this.comment});

  final String? comment;
}

/// Rechazar, con un motivo obligatorio que ve la directiva de la sección.
class RejectChoice extends DecisionChoice {
  const RejectChoice({required this.reason});

  final String reason;
}

/// Quitar la decisión tomada (la persona vuelve a «sin decidir»).
class ClearChoice extends DecisionChoice {
  const ClearChoice();
}
