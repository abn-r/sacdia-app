import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_model.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';

Map<String, dynamic> _localOrderJson({
  bool authorizedWithoutProof = false,
  String distributionStatus = 'NOT_STARTED',
  List<Map<String, dynamic>>? lines,
  List<Map<String, dynamic>>? summary,
}) {
  return {
    'camporee_order_id': 'ord-local',
    'local_camporee_id': 17,
    'union_camporee_id': null,
    'folio_reference': 'PED20260001',
    'status': 'ISSUED',
    'currency': 'MXN',
    'total_centavos': 425000,
    'expires_at': '2026-09-10T00:00:00.000Z',
    'created_at': '2026-08-24T18:00:00.000Z',
    'authorized_without_proof': authorizedWithoutProof,
    'distribution_status': distributionStatus,
    'lines': lines ??
        [
          {
            'camporee_order_line_id': 'line-1',
            'sequence': 1,
            'camporee_member_id': 801,
            'beneficiary_user_id': 'user-1',
            'beneficiary_name_snapshot': 'Ana Pérez',
            'offering_id': 'off-playera',
            'product_id': 'prod-playera',
            'option_id': 'opt-m',
            'product_title_snapshot': 'Playera hombre',
            'option_label_snapshot': 'M',
            'qty': 1,
            'unit_price_centavos': 250000,
            'line_total_centavos': 250000,
            'delivered_to_member_at': null,
            'delivered_to_member_by_id': null,
          },
        ],
    'summary': summary ??
        [
          {
            'product_title_snapshot': 'Playera hombre',
            'option_label_snapshot': 'M',
            'qty': 1,
            'subtotal_centavos': 250000,
          },
        ],
  };
}

void main() {
  group('CamporeeOrderModel local vs union', () {
    test('parsea camporee local (union_camporee_id nulo)', () {
      final entity = CamporeeOrderModel.fromJson(_localOrderJson()).toEntity();

      expect(entity.orderId, 'ord-local');
      expect(entity.localCamporeeId, 17);
      expect(entity.unionCamporeeId, isNull);
      expect(entity.isUnionCamporee, isFalse);
      expect(entity.folioReference, 'PED20260001');
      expect(entity.status, CamporeeOrderStatus.issued);
      expect(entity.totalCentavos, 425000);
    });

    test('parsea camporee de unión (local_camporee_id nulo)', () {
      final entity = CamporeeOrderModel.fromJson({
        ..._localOrderJson(),
        'camporee_order_id': 'ord-union',
        'local_camporee_id': null,
        'union_camporee_id': 8,
      }).toEntity();

      expect(entity.orderId, 'ord-union');
      expect(entity.localCamporeeId, isNull);
      expect(entity.unionCamporeeId, 8);
      expect(entity.isUnionCamporee, isTrue);
    });
  });

  group('authorized_without_proof', () {
    test('excepción LF queda en true y no se infiere del status', () {
      final entity = CamporeeOrderModel.fromJson(
        _localOrderJson(authorizedWithoutProof: true)
          ..['status'] = 'PAID',
      ).toEntity();

      expect(entity.authorizedWithoutProof, isTrue);
      expect(entity.status, CamporeeOrderStatus.paid);
    });

    test('ausente o false no marca la excepción', () {
      expect(
        CamporeeOrderModel.fromJson(_localOrderJson()).toEntity()
            .authorizedWithoutProof,
        isFalse,
      );
      expect(
        CamporeeOrderModel.fromJson({
          ..._localOrderJson(),
          'authorized_without_proof': false,
        }).toEntity().authorizedWithoutProof,
        isFalse,
      );
    });
  });

  group('talla / option_id null (size_scheme NONE)', () {
    test('línea sin option_id ni option_label_snapshot', () {
      final entity = CamporeeOrderModel.fromJson(
        _localOrderJson(
          lines: [
            {
              'camporee_order_line_id': 'line-pin',
              'sequence': 1,
              'camporee_member_id': 802,
              'beneficiary_user_id': 'user-2',
              'beneficiary_name_snapshot': 'Beto Ruiz',
              'offering_id': 'off-pin',
              'product_id': 'prod-pin',
              'option_id': null,
              'product_title_snapshot': 'Pin camporí',
              'option_label_snapshot': null,
              'qty': 2,
              'unit_price_centavos': 5000,
              'line_total_centavos': 10000,
              'delivered_to_member_at': null,
              'delivered_to_member_by_id': null,
            },
          ],
        ),
      ).toEntity();

      final line = entity.lines.single;
      expect(line.optionId, isNull);
      expect(line.optionLabelSnapshot, isNull);
      expect(line.qty, 2);
    });
  });

  group('summary parse-only', () {
    test('no inventa un segundo consolidado: usa el del API', () {
      final entity = CamporeeOrderModel.fromJson(
        _localOrderJson(
          summary: [
            {
              'product_title_snapshot': 'Playera hombre',
              'option_label_snapshot': 'M',
              'qty': 16,
              'subtotal_centavos': 4000000,
            },
          ],
        ),
      ).toEntity();

      expect(entity.summary, hasLength(1));
      expect(entity.summary.first.qty, 16);
      expect(entity.summary.first.subtotalCentavos, 4000000);
      expect(entity.lines.first.qty, isNot(16));
    });
  });

  group('delivered_to_member_at y distribution_status', () {
    test('parsea distribution_status del API', () {
      final partial = CamporeeOrderModel.fromJson(
        _localOrderJson(distributionStatus: 'PARTIAL'),
      ).toEntity();
      expect(
        partial.distributionStatus,
        CamporeeOrderDistributionStatus.partial,
      );
    });

    test('parsea delivered_to_member_at por línea', () {
      final deliveredAt = '2026-08-25T12:00:00.000Z';
      final entity = CamporeeOrderModel.fromJson(
        _localOrderJson(
          distributionStatus: 'PARTIAL',
          lines: [
            {
              'camporee_order_line_id': 'line-1',
              'sequence': 1,
              'camporee_member_id': 801,
              'beneficiary_user_id': 'user-1',
              'beneficiary_name_snapshot': 'Ana Pérez',
              'offering_id': 'off-playera',
              'product_id': 'prod-playera',
              'option_id': 'opt-m',
              'product_title_snapshot': 'Playera hombre',
              'option_label_snapshot': 'M',
              'qty': 1,
              'unit_price_centavos': 250000,
              'line_total_centavos': 250000,
              'delivered_to_member_at': deliveredAt,
              'delivered_to_member_by_id': 'director-1',
            },
            {
              'camporee_order_line_id': 'line-2',
              'sequence': 2,
              'camporee_member_id': 802,
              'beneficiary_user_id': 'user-2',
              'beneficiary_name_snapshot': 'Beto Ruiz',
              'offering_id': 'off-pin',
              'product_id': 'prod-pin',
              'option_id': null,
              'product_title_snapshot': 'Pin camporí',
              'option_label_snapshot': null,
              'qty': 1,
              'unit_price_centavos': 5000,
              'line_total_centavos': 5000,
              'delivered_to_member_at': null,
              'delivered_to_member_by_id': null,
            },
          ],
        ),
      ).toEntity();

      expect(entity.lines.first.deliveredToMemberAt, isNotNull);
      expect(entity.lines.first.deliveredToMemberById, 'director-1');
      expect(entity.lines.last.deliveredToMemberAt, isNull);
      expect(
        deriveDistributionStatus(entity.lines),
        CamporeeOrderDistributionStatus.partial,
      );
    });
  });
}
