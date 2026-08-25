import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/payment_orders/data/models/payment_obligation_model.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';

Map<String, dynamic> _obligationJson({
  required String source,
  required String sourceId,
  required String purpose,
  required String folio,
  Map<String, dynamic>? camporee,
}) {
  return {
    'source': source,
    'source_id': sourceId,
    'purpose': purpose,
    'folio': folio,
    'total_centavos': 425000,
    'currency': 'MXN',
    'status': 'PAYMENT_DUE',
    'action_required': 'UPLOAD_PROOF',
    'camporee': camporee,
    'created_at': '2026-08-24T18:00:00.000Z',
  };
}

void main() {
  group('PaymentObligationModel', () {
    test('parsea pedido de camporee, inscripción y materiales', () {
      final merch = PaymentObligationModel.fromJson(_obligationJson(
        source: 'CAMPOREE_ORDER',
        sourceId: 'ord-merch',
        purpose: 'CAMPOREE_MATERIALS',
        folio: 'PED20260001',
        camporee: {'type': 'local', 'id': 17, 'name': 'Camporí 2026'},
      )).toEntity();
      final inscription = PaymentObligationModel.fromJson(_obligationJson(
        source: 'FIELD_PAYMENT_ORDER',
        sourceId: 'ord-insc',
        purpose: 'CAMPOREE',
        folio: 'ORD20260002',
        camporee: {'type': 'union', 'id': 8, 'name': 'Camporí Unión'},
      )).toEntity();
      final materials = PaymentObligationModel.fromJson(_obligationJson(
        source: 'MATERIAL_ORDER',
        sourceId: 'mat-1',
        purpose: 'MATERIALS',
        folio: 'SOL20260003',
      )).toEntity();

      expect(merch.source, PaymentObligationSource.camporeeOrder);
      expect(merch.purpose, PaymentObligationPurpose.camporeeMaterials);
      expect(merch.currency, 'MXN');
      expect(merch.camporee?.type, 'local');
      expect(inscription.source, PaymentObligationSource.fieldPaymentOrder);
      expect(inscription.camporee?.isUnion, isTrue);
      expect(materials.source, PaymentObligationSource.materialOrder);
      expect(materials.camporee, isNull);
    });

    test('misma sección/camporee: dos obligaciones siguen siendo dos filas', () {
      final rows = [
        PaymentObligationModel.fromJson(_obligationJson(
          source: 'CAMPOREE_ORDER',
          sourceId: 'ord-a',
          purpose: 'CAMPOREE_MATERIALS',
          folio: 'PED20260001',
          camporee: {'type': 'local', 'id': 17, 'name': 'Camporí 2026'},
        )).toEntity(),
        PaymentObligationModel.fromJson(_obligationJson(
          source: 'FIELD_PAYMENT_ORDER',
          sourceId: 'ord-b',
          purpose: 'CAMPOREE',
          folio: 'ORD20260002',
          camporee: {'type': 'local', 'id': 17, 'name': 'Camporí 2026'},
        )).toEntity(),
      ];

      expect(rows, hasLength(2));
      expect(rows[0].folio, isNot(rows[1].folio));
      expect(rows[0].camporee?.id, rows[1].camporee?.id);
    });
  });

  group('source → detail route', () {
    test('FIELD_PAYMENT_ORDER → /payment-orders/:id', () {
      expect(
        paymentObligationDetailRoute(
          source: PaymentObligationSource.fieldPaymentOrder,
          sourceId: 'insc-1',
        ),
        '/payment-orders/insc-1',
      );
    });

    test('MATERIAL_ORDER → /home/materials/order/:id', () {
      expect(
        paymentObligationDetailRoute(
          source: PaymentObligationSource.materialOrder,
          sourceId: 'mat-9',
        ),
        '/home/materials/order/mat-9',
      );
    });

    test('CAMPOREE_ORDER → /camporee-orders/:id', () {
      expect(
        paymentObligationDetailRoute(
          source: PaymentObligationSource.camporeeOrder,
          sourceId: 'ord-merch',
        ),
        '/camporee-orders/ord-merch',
      );
    });

    test('el getter de la entidad usa la misma función pura', () {
      final entity = PaymentObligationModel.fromJson(_obligationJson(
        source: 'CAMPOREE_ORDER',
        sourceId: 'ord-merch',
        purpose: 'CAMPOREE_MATERIALS',
        folio: 'PED20260001',
      )).toEntity();
      expect(entity.detailRoute, '/camporee-orders/ord-merch');
    });
  });
}
