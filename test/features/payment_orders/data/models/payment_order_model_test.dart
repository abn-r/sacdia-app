import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/payment_orders/data/models/payment_order_model.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';

void main() {
  group('PaymentOrderModel', () {
    test('parsea orden completa con líneas y comprobantes', () {
      final model = PaymentOrderModel.fromJson({
        'field_payment_order_id': 'order-1',
        'purpose': 'CAMPOREE',
        'folio_reference': 'OP20260001',
        'currency': 'MXN',
        'unit_cost_centavos': 15000,
        'total_centavos': 30000,
        'status': 'PROOF_SUBMITTED',
        'expires_at': '2026-08-27T00:00:00.000Z',
        'created_at': '2026-08-12T00:00:00.000Z',
        'lines': [
          {
            'field_payment_order_line_id': 'line-1',
            'sequence': 1,
            'beneficiary_user_id': 'user-1',
            'unit_cost_centavos': 15000,
          },
        ],
        'proofs': [
          {
            'field_payment_order_proof_id': 'proof-1',
            'file_name': 'pago.pdf',
            'mime_type': 'application/pdf',
            'status': 'SUBMITTED',
            'created_at': '2026-08-13T00:00:00.000Z',
          },
        ],
      });

      final entity = model.toEntity();
      expect(entity.orderId, 'order-1');
      expect(entity.purpose, PaymentOrderPurpose.camporee);
      expect(entity.status, PaymentOrderStatus.proofSubmitted);
      expect(entity.totalCentavos, 30000);
      expect(entity.lines, hasLength(1));
      expect(entity.lines.first.beneficiaryUserId, 'user-1');
      expect(entity.proofs, hasLength(1));
      expect(entity.proofs.first.status, PaymentOrderProofStatus.submitted);
    });

    test('tolera campos faltantes con defaults seguros', () {
      final entity = PaymentOrderModel.fromJson(const {}).toEntity();
      expect(entity.orderId, '');
      expect(entity.purpose, PaymentOrderPurpose.insurance);
      expect(entity.status, PaymentOrderStatus.issued);
      expect(entity.lines, isEmpty);
      expect(entity.proofs, isEmpty);
    });
  });

  group('PaymentOrdersContextModel', () {
    test('parsea contexto con ciclos y convierte unit_cost decimal a centavos',
        () {
      final model = PaymentOrdersContextModel.fromJson({
        'enabled': true,
        'local_field_id': 7,
        'club_section_id': 42,
        'insurance_cycles': [
          {
            'insurance_cycle_config_id': 3,
            'unit_cost': '150.50',
            'purchase_deadline': '2026-09-30T00:00:00.000Z',
            'product': {'name': 'Seguro anual'},
          },
        ],
      });

      final entity = model.toEntity();
      expect(entity.enabled, isTrue);
      expect(entity.localFieldId, 7);
      expect(entity.clubSectionId, 42);
      expect(entity.insuranceCycles, hasLength(1));

      final cycle = entity.insuranceCycles.first;
      expect(cycle.cycleConfigId, 3);
      expect(cycle.productName, 'Seguro anual');
      expect(cycle.unitCostCentavos, 15050);
      expect(cycle.purchaseDeadline, isNotNull);
    });

    test('flag apagado sin ciclos', () {
      final entity = PaymentOrdersContextModel.fromJson(const {
        'enabled': false,
        'local_field_id': 7,
        'club_section_id': 42,
      }).toEntity();
      expect(entity.enabled, isFalse);
      expect(entity.insuranceCycles, isEmpty);
    });
  });

  group('InsuranceReassignmentModel', () {
    test('parsea solicitud de reasignación', () {
      final entity = InsuranceReassignmentModel.fromJson({
        'insurance_reassignment_request_id': 11,
        'insurance_assignment_id': 5,
        'from_user_id': 'user-a',
        'to_user_id': 'user-b',
        'reason': 'Cambio de miembro',
        'status': 'PENDING',
        'created_at': '2026-08-12T00:00:00.000Z',
      }).toEntity();

      expect(entity.requestId, 11);
      expect(entity.insuranceAssignmentId, 5);
      expect(entity.fromUserId, 'user-a');
      expect(entity.toUserId, 'user-b');
      expect(entity.status, 'PENDING');
    });
  });
}
