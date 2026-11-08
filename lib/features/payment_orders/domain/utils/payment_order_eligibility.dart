import '../../../insurance/domain/entities/member_insurance.dart';
import '../entities/payment_order.dart';

/// Elegibilidad de un miembro como beneficiario de una orden de pago.
///
/// - Seguro: quien aún no tiene cobertura activa.
/// - Camporee: seguro vigente y todavía no inscrito (ni pendiente) en el evento.
bool isEligiblePaymentOrderBeneficiary({
  required PaymentOrderPurpose purpose,
  required MemberInsurance member,
  Set<String> registeredCamporeeUserIds = const {},
}) {
  if (purpose == PaymentOrderPurpose.insurance) {
    return member.status != InsuranceStatus.asegurado;
  }

  return member.status == InsuranceStatus.asegurado &&
      !registeredCamporeeUserIds.contains(member.memberId);
}

/// Members held by an order that is still open (issued, in review, rejected
/// or approved), mapped to that order's folio. The backend refuses a second
/// order for them until the first one is cancelled or expires.
Map<String, String> beneficiariesHeldByOrders(Iterable<PaymentOrder> orders) {
  final held = <String, String>{};
  for (final order in orders) {
    if (!order.holdsBeneficiaries) continue;
    for (final line in order.lines) {
      held.putIfAbsent(line.beneficiaryUserId, () => order.folioReference);
    }
  }
  return held;
}
