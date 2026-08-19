/// Flujo de inscripción de miembros según el contexto de órdenes de pago.
///
/// Loading y error son fail-closed: no se pinta el register legacy. Ese POST
/// responde `403 FIELD_PAYMENT_ORDER_LEGACY_DISABLED` si el flag está ON.
enum CamporeeRegistrationPaymentFlow {
  loading,
  unavailable,
  paymentOrder,
  legacy,
}

CamporeeRegistrationPaymentFlow camporeeRegistrationPaymentFlow({
  required bool isLoading,
  required bool hasError,
  bool enabled = false,
}) {
  if (isLoading) return CamporeeRegistrationPaymentFlow.loading;
  if (hasError) return CamporeeRegistrationPaymentFlow.unavailable;
  if (enabled) return CamporeeRegistrationPaymentFlow.paymentOrder;
  return CamporeeRegistrationPaymentFlow.legacy;
}
