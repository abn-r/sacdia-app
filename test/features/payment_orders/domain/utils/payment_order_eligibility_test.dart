import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/insurance/domain/entities/member_insurance.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/domain/utils/payment_order_eligibility.dart';

void main() {
  const insured = MemberInsurance(
    memberId: 'insured-user',
    memberName: 'Ana Asegurada',
    status: InsuranceStatus.asegurado,
  );
  const uninsured = MemberInsurance(
    memberId: 'bare-user',
    memberName: 'Beto Sin Seguro',
    status: InsuranceStatus.sinSeguro,
  );
  const expired = MemberInsurance(
    memberId: 'expired-user',
    memberName: 'Cata Vencida',
    status: InsuranceStatus.vencido,
  );

  test('seguro: excluye a quien ya tiene cobertura activa', () {
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.insurance,
        member: insured,
      ),
      isFalse,
    );
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.insurance,
        member: uninsured,
      ),
      isTrue,
    );
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.insurance,
        member: expired,
      ),
      isTrue,
    );
  });

  test('camporee: exige seguro vigente y descarta ya inscritos', () {
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.camporee,
        member: insured,
      ),
      isTrue,
    );
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.camporee,
        member: insured,
        registeredCamporeeUserIds: const {'insured-user'},
      ),
      isFalse,
    );
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.camporee,
        member: uninsured,
      ),
      isFalse,
    );
    expect(
      isEligiblePaymentOrderBeneficiary(
        purpose: PaymentOrderPurpose.camporee,
        member: expired,
      ),
      isFalse,
    );
  });
}
