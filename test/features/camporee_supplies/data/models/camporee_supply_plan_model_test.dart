import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_supplies/data/models/camporee_supply_plan_model.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';

void main() {
  test('parses a draft envelope with catalog and no plan', () {
    final envelope = CamporeeSupplyPlanModel.envelopeFromJson(
      {
        'plan': null,
        'catalog': {
          'supply_edit_cutoff_local_time': '21:00',
          'timezone': 'America/Mexico_City',
          'start_date': '2026-08-28',
          'end_date': '2026-08-30',
          'slots': [
            {
              'slot_id': 'slot-1',
              'label': 'Almuerzo',
              'deliver_time': '13:00',
              'sort_order': 1,
            }
          ],
          'products': [
            {
              'product_id': 'prod-1',
              'name': 'Tortillas',
              'uom': 'KG',
              'unit_cost_centavos': 2800,
            }
          ],
        },
      },
      camporeeId: 21,
      camporeeType: CamporeeKind.local,
    );

    expect(envelope.plan, isNull);
    expect(envelope.catalog.isReady, isTrue);
    expect(envelope.catalog.products.single.name, 'Tortillas');
  });

  test('parses a submitted plan with principal folio', () {
    final plan = CamporeeSupplyPlanModel.planFromJson({
      'plan_id': 'plan-1',
      'status': 'SUBMITTED',
      'committed_total_centavos': 8400,
      'net_centavos': 8400,
      'cutoff': '21:00',
      'timezone': 'America/Mexico_City',
      'lines': [
        {
          'line_id': 'line-1',
          'date': '2026-08-29',
          'slot_id': 'slot-1',
          'slot_label': 'Almuerzo',
          'deliver_time': '13:00',
          'product_id': 'prod-1',
          'product_name': 'Tortillas',
          'uom': 'KG',
          'qty': '3.000',
          'delivered_qty': '0.000',
          'unit_cost_centavos': 2800,
          'line_total_centavos': 8400,
        }
      ],
      'payments': [
        {
          'payment_id': 'pay-1',
          'kind': 'PRINCIPAL',
          'parent_id': null,
          'folio_reference': 'INS20260001',
          'total_centavos': 8400,
          'status': 'ISSUED',
        }
      ],
    });

    expect(plan.isSubmitted, isTrue);
    expect(plan.payments.single.folioReference, 'INS20260001');
    expect(plan.lines.single.toInput().qty, 3);
  });

  test('maps supply obligations without mixing merchandise folios', () {
    expect(
      PaymentObligationSourceApi.fromApi('CAMPOREE_SUPPLY_CHARGE'),
      PaymentObligationSource.camporeeSupplyCharge,
    );
    expect(
      PaymentObligationSourceApi.fromApi('CAMPOREE_SUPPLY_REFUND'),
      PaymentObligationSource.camporeeSupplyRefund,
    );
    expect(
      PaymentObligationActionApi.fromApi('PAY_AT_CAMP'),
      PaymentObligationAction.payAtCamp,
    );
  });
}
