import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/domain/utils/payment_order_eligibility.dart';

InsurancePerson _person(String id, InsurancePersonStatus status) =>
    InsurancePerson(userId: id, name: 'Persona $id', status: status);

void main() {
  final covered = _person('insured-user', InsurancePersonStatus.covered);

  test('camporee: exige seguro vigente del año', () {
    expect(isEligibleCamporeeBeneficiary(person: covered), isTrue);
    for (final status in [
      InsurancePersonStatus.uninsured,
      InsurancePersonStatus.inOrder,
      InsurancePersonStatus.inReview,
      InsurancePersonStatus.proofRejected,
    ]) {
      expect(
        isEligibleCamporeeBeneficiary(person: _person('x', status)),
        isFalse,
        reason: '$status no cuenta como asegurado',
      );
    }
  });

  test('camporee: descarta a quien ya está inscrito', () {
    expect(
      isEligibleCamporeeBeneficiary(
        person: covered,
        registeredCamporeeUserIds: const {'insured-user'},
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
