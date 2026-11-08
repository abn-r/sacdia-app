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

  group('beneficiariesHeldByOrders', () {
    PaymentOrder order(
            String folio, PaymentOrderStatus status, List<String> ids) =>
        PaymentOrder(
          orderId: folio,
          purpose: PaymentOrderPurpose.camporee,
          folioReference: folio,
          currency: 'MXN',
          unitCostCentavos: 10000,
          totalCentavos: 10000 * ids.length,
          status: status,
          expiresAt: DateTime(2026, 12, 1),
          createdAt: DateTime(2026, 11, 1),
          lines: [
            for (var i = 0; i < ids.length; i++)
              PaymentOrderLine(
                lineId: '$folio-$i',
                sequence: i + 1,
                beneficiaryUserId: ids[i],
                unitCostCentavos: 10000,
              ),
          ],
        );

    test('maps members of open orders to the folio that holds them', () {
      final held = beneficiariesHeldByOrders([
        order('ORD5', PaymentOrderStatus.issued, ['ana', 'beto']),
        order('ORD6', PaymentOrderStatus.proofSubmitted, ['cata']),
        order('ORD7', PaymentOrderStatus.proofRejected, ['dani']),
        order('ORD8', PaymentOrderStatus.approved, ['eva']),
      ]);

      expect(held, {
        'ana': 'ORD5',
        'beto': 'ORD5',
        'cata': 'ORD6',
        'dani': 'ORD7',
        'eva': 'ORD8',
      });
    });

    test('releases members of cancelled or expired orders', () {
      final held = beneficiariesHeldByOrders([
        order('ORD1', PaymentOrderStatus.cancelled, ['ana']),
        order('ORD2', PaymentOrderStatus.expired, ['beto']),
      ]);

      expect(held, isEmpty);
    });
  });
}
