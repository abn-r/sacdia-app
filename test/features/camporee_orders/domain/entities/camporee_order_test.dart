import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';

CamporeeOrderLine _line({
  required String id,
  DateTime? deliveredAt,
}) {
  return CamporeeOrderLine(
    lineId: id,
    sequence: 1,
    camporeeMemberId: 801,
    beneficiaryUserId: 'user-1',
    beneficiaryNameSnapshot: 'Ana',
    offeringId: 'off-1',
    productId: 'prod-1',
    productTitleSnapshot: 'Playera',
    qty: 1,
    unitPriceCentavos: 100,
    lineTotalCentavos: 100,
    deliveredToMemberAt: deliveredAt,
  );
}

void main() {
  group('deriveDistributionStatus', () {
    test('sin líneas → NOT_STARTED', () {
      expect(
        deriveDistributionStatus(const []),
        CamporeeOrderDistributionStatus.notStarted,
      );
    });

    test('ninguna entregada → NOT_STARTED', () {
      expect(
        deriveDistributionStatus([_line(id: 'a'), _line(id: 'b')]),
        CamporeeOrderDistributionStatus.notStarted,
      );
    });

    test('algunas entregadas → PARTIAL', () {
      expect(
        deriveDistributionStatus([
          _line(id: 'a', deliveredAt: DateTime.utc(2026, 8, 25)),
          _line(id: 'b'),
        ]),
        CamporeeOrderDistributionStatus.partial,
      );
    });

    test('todas entregadas → COMPLETE', () {
      final at = DateTime.utc(2026, 8, 25);
      expect(
        deriveDistributionStatus([
          _line(id: 'a', deliveredAt: at),
          _line(id: 'b', deliveredAt: at),
        ]),
        CamporeeOrderDistributionStatus.complete,
      );
    });
  });

  group('CamporeeOrderCreateLine payload', () {
    const forbidden = {
      'price',
      'total',
      'user_id',
      'club_id',
      'club_section_id',
      'local_field_id',
      'unit_price_centavos',
      'line_total_centavos',
      'total_centavos',
    };

    test('con talla envía camporee_member_id + offering_id + option_id + qty',
        () {
      const line = CamporeeOrderCreateLine(
        camporeeMemberId: 801,
        offeringId: 'uuid-playera',
        optionId: 'uuid-m',
        qty: 1,
      );

      expect(line.toJson(), {
        'camporee_member_id': 801,
        'offering_id': 'uuid-playera',
        'option_id': 'uuid-m',
        'qty': 1,
      });
      expect(line.toJson().keys.toSet().intersection(forbidden), isEmpty);
    });

    test('size_scheme NONE omite option_id y no manda montos', () {
      const line = CamporeeOrderCreateLine(
        camporeeMemberId: 802,
        offeringId: 'uuid-pin',
        qty: 1,
      );

      expect(line.toJson(), {
        'camporee_member_id': 802,
        'offering_id': 'uuid-pin',
        'qty': 1,
      });
      expect(line.toJson().containsKey('option_id'), isFalse);
      expect(line.toJson().keys.toSet().intersection(forbidden), isEmpty);
    });
  });
}
