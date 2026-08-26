import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/payment_orders/data/models/payment_obligation_model.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';

void main() {
  group('PaymentObligationModel', () {
    test('source → ruta de detalle propietaria', () {
      final inscription = PaymentObligationModel.fromJson({
        'source': 'FIELD_PAYMENT_ORDER',
        'source_id': 'fpo-1',
        'purpose': 'CAMPOREE',
        'folio': 'OP20260001',
        'total_centavos': 30000,
        'currency': 'MXN',
        'status': 'PAYMENT_DUE',
        'action_required': 'UPLOAD_PROOF',
        'camporee': {'type': 'local', 'id': 10, 'name': 'Camporee A'},
        'created_at': '2026-08-24T00:00:00.000Z',
      }).toEntity();
      expect(inscription.detailPath, '/payment-orders/fpo-1');
      expect(inscription.purpose, PaymentObligationPurpose.camporee);

      final materials = PaymentObligationModel.fromJson({
        'source': 'MATERIAL_ORDER',
        'source_id': 'mat-9',
        'purpose': 'MATERIALS',
        'folio': 'MAT0001',
        'total_centavos': 5000,
        'currency': 'MXN',
        'status': 'ORDER_REVIEW',
        'action_required': 'WAIT_APPROVAL',
        'camporee': null,
        'created_at': '2026-08-24T00:00:00.000Z',
      }).toEntity();
      expect(materials.detailPath, '/home/materials/order/mat-9');

      final pedido = PaymentObligationModel.fromJson({
        'source': 'CAMPOREE_ORDER',
        'source_id': 'co-3',
        'purpose': 'CAMPOREE_MATERIALS',
        'folio': 'PED20260003',
        'total_centavos': 19900,
        'currency': 'MXN',
        'status': 'PROOF_REJECTED',
        'action_required': 'RESUBMIT_PROOF',
        'camporee': {'type': 'union', 'id': 88, 'name': 'Unión Norte'},
        'created_at': '2026-08-24T00:00:00.000Z',
      }).toEntity();
      expect(pedido.detailPath, '/camporee-orders/co-3');
      expect(pedido.camporee?.type, 'union');
      expect(pedido.status, PaymentObligationStatus.proofRejected);

      final supplies = PaymentObligationModel.fromJson({
        'source': 'CAMPOREE_SUPPLY_CHARGE',
        'source_id': 'ins-1',
        'purpose': 'CAMPOREE_SUPPLIES',
        'folio': 'INS20260001',
        'total_centavos': 80000,
        'currency': 'MXN',
        'status': 'PAYMENT_DUE',
        'action_required': 'PAY_AT_CAMP',
        'camporee': {'type': 'local', 'id': 21, 'name': 'Camporí'},
        'created_at': '2026-08-24T00:00:00.000Z',
      }).toEntity();
      expect(supplies.detailPath, '/camporee/21/supplies');
      expect(supplies.purpose, PaymentObligationPurpose.camporeeSupplies);
      expect(supplies.actionRequired, PaymentObligationAction.payAtCamp);
    });

    test('dos pedidos de la misma sección siguen siendo dos filas', () {
      final a = PaymentObligationModel.fromJson({
        'source': 'CAMPOREE_ORDER',
        'source_id': 'o1',
        'purpose': 'CAMPOREE_MATERIALS',
        'folio': 'PED20260001',
        'total_centavos': 100,
        'currency': 'MXN',
        'status': 'PAYMENT_DUE',
        'action_required': 'UPLOAD_PROOF',
        'created_at': '2026-08-24T00:00:00.000Z',
      }).toEntity();
      final b = PaymentObligationModel.fromJson({
        'source': 'CAMPOREE_ORDER',
        'source_id': 'o2',
        'purpose': 'CAMPOREE_MATERIALS',
        'folio': 'PED20260002',
        'total_centavos': 200,
        'currency': 'MXN',
        'status': 'UNDER_REVIEW',
        'action_required': 'WAIT_REVIEW',
        'created_at': '2026-08-25T00:00:00.000Z',
      }).toEntity();
      expect(a.sourceId, isNot(b.sourceId));
      expect(a.folio, isNot(b.folio));
      expect(a.detailPath, isNot(b.detailPath));
    });
  });
}
