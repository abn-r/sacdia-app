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
