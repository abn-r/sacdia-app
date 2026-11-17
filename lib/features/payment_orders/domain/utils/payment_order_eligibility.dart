import '../../../insurance/domain/entities/insurance_overview.dart';
import '../entities/payment_order.dart';

/// Whether [person] can be a beneficiary of a camporee order.
///
/// A camporee needs a valid insurance for the year and no registration (or
/// pending one) in the event yet. Insurance orders no longer use this: the
/// insurance overview already says who is free.
bool isEligibleCamporeeBeneficiary({
  required InsurancePerson person,
  Set<String> registeredCamporeeUserIds = const {},
}) {
  return person.status == InsurancePersonStatus.covered &&
      !registeredCamporeeUserIds.contains(person.userId);
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
