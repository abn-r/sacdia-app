import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_model.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_product_model.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';

Map<String, dynamic> _lineJson({
  String id = 'line-1',
  int memberId = 801,
  String? optionId = 'opt-m',
  String? optionLabel = 'M',
  String? deliveredAt,
}) {
  return {
    'camporee_order_line_id': id,
    'sequence': 1,
    'camporee_member_id': memberId,
    'beneficiary_user_id': 'user-1',
    'beneficiary_name_snapshot': 'Ana Pérez',
    'offering_id': 'off-1',
    'product_id': 'prod-1',
    'option_id': optionId,
    'product_title_snapshot': 'Playera',
    'option_label_snapshot': optionLabel,
    'qty': 1,
    'unit_price_centavos': 15000,
    'line_total_centavos': 15000,
    'delivered_to_member_at': deliveredAt,
    'delivered_to_member_by_id': deliveredAt == null ? null : 'director-1',
  };
}

Map<String, dynamic> _orderJson({
  int? localCamporeeId = 10,
  int? unionCamporeeId,
  bool authorizedWithoutProof = false,
  String status = 'ISSUED',
  String distributionStatus = 'NOT_STARTED',
  List<Map<String, dynamic>>? lines,
}) {
  return {
    'camporee_order_id': 'order-1',
    'local_field_id': 7,
    'club_id': 3,
    'club_section_id': 42,
    'local_camporee_id': localCamporeeId,
    'union_camporee_id': unionCamporeeId,
    'folio': 1,
    'folio_reference': 'PED20260001',
    'status': status,
    'currency': 'MXN',
    'total_centavos': 15000,
    'expires_at': '2026-09-01T00:00:00.000Z',
    'created_at': '2026-08-24T00:00:00.000Z',
    'authorized_without_proof': authorizedWithoutProof,
    'authorization_reason': authorizedWithoutProof ? 'Caja en efectivo' : null,
    'delivered_to_section_at':
        status == 'DELIVERED' ? '2026-08-30T00:00:00.000Z' : null,
    'lines': lines ?? [_lineJson()],
    'summary': [
      {
        'product_title_snapshot': 'Playera',
        'option_label_snapshot': 'M',
        'qty': 1,
        'subtotal_centavos': 15000,
      },
    ],
    'distribution_status': distributionStatus,
  };
}

void main() {
  group('CamporeeOrderModel', () {
    test('parsea pedido local y XOR de camporee', () {
      final entity = CamporeeOrderModel.fromJson(_orderJson()).toEntity();
      expect(entity.orderId, 'order-1');
      expect(entity.folioReference, 'PED20260001');
      expect(entity.camporeeKind, CamporeeKind.local);
      expect(entity.localCamporeeId, 10);
      expect(entity.unionCamporeeId, isNull);
      expect(entity.lines.first.camporeeMemberId, 801);
      expect(entity.summary.first.qty, 1);
    });

    test('parsea pedido de unión', () {
      final entity = CamporeeOrderModel.fromJson(
        _orderJson(localCamporeeId: null, unionCamporeeId: 88),
      ).toEntity();
      expect(entity.camporeeKind, CamporeeKind.union);
      expect(entity.unionCamporeeId, 88);
      expect(entity.localCamporeeId, isNull);
    });

    test('talla null cuando size_scheme es NONE', () {
      final entity = CamporeeOrderModel.fromJson(
        _orderJson(lines: [_lineJson(optionId: null, optionLabel: null)]),
      ).toEntity();
      expect(entity.lines.first.optionId, isNull);
      expect(entity.lines.first.optionLabelSnapshot, isNull);
    });

    test('excepción authorize-without-proof no cambia el folio', () {
      final entity = CamporeeOrderModel.fromJson(
        _orderJson(
          authorizedWithoutProof: true,
          status: 'PAID',
        ),
      ).toEntity();
      expect(entity.authorizedWithoutProof, isTrue);
      expect(entity.status, CamporeeOrderStatus.paid);
      expect(entity.authorizationReason, 'Caja en efectivo');
      expect(entity.folioReference, 'PED20260001');
    });

    test('distribución por línea NOT_STARTED / PARTIAL / COMPLETE', () {
      final none = CamporeeOrderModel.fromJson(
        _orderJson(
          status: 'DELIVERED',
          distributionStatus: 'NOT_STARTED',
          lines: [
            _lineJson(id: 'a'),
            _lineJson(id: 'b', memberId: 802),
          ],
        ),
      ).toEntity();
      expect(
          none.distributionStatus, CamporeeOrderDistributionStatus.notStarted);
      expect(deriveDistributionStatus(none.lines),
          CamporeeOrderDistributionStatus.notStarted);

      final partialLines = [
        CamporeeOrderLineModel.fromJson(
          _lineJson(id: 'a', deliveredAt: '2026-08-31T00:00:00.000Z'),
        ).toEntity(),
        CamporeeOrderLineModel.fromJson(_lineJson(id: 'b', memberId: 802))
            .toEntity(),
      ];
      expect(
        deriveDistributionStatus(partialLines),
        CamporeeOrderDistributionStatus.partial,
      );

      final completeLines = [
        CamporeeOrderLineModel.fromJson(
          _lineJson(id: 'a', deliveredAt: '2026-08-31T00:00:00.000Z'),
        ).toEntity(),
        CamporeeOrderLineModel.fromJson(
          _lineJson(
            id: 'b',
            memberId: 802,
            deliveredAt: '2026-08-31T00:00:00.000Z',
          ),
        ).toEntity(),
      ];
      expect(
        deriveDistributionStatus(completeLines),
        CamporeeOrderDistributionStatus.complete,
      );
    });
  });

  group('CamporeeOrderLineInput', () {
    test('payload usa camporee_member_id y no envía montos ni user_id', () {
      const withSize = CamporeeOrderLineInput(
        camporeeMemberId: 801,
        offeringId: 'off-1',
        optionId: 'opt-m',
        qty: 2,
      );
      const noSize = CamporeeOrderLineInput(
        camporeeMemberId: 802,
        offeringId: 'off-2',
        qty: 1,
      );
      final payload = {
        'lines': [withSize.toJson(), noSize.toJson()],
      };
      expect(payload['lines'], hasLength(2));
      expect(
        withSize.toJson().keys,
        containsAll(['camporee_member_id', 'offering_id', 'option_id', 'qty']),
      );
      expect(noSize.toJson().containsKey('option_id'), isFalse);
      for (final line in [withSize.toJson(), noSize.toJson()]) {
        expect(line.containsKey('unit_price_centavos'), isFalse);
        expect(line.containsKey('line_total_centavos'), isFalse);
        expect(line.containsKey('total_centavos'), isFalse);
        expect(line.containsKey('user_id'), isFalse);
        expect(line.containsKey('club_id'), isFalse);
        expect(line.containsKey('club_section_id'), isFalse);
        expect(line.containsKey('local_field_id'), isFalse);
      }
    });
  });

  group('CamporeeOrderProductModel', () {
    test('NONE no requiere opción; LETTER sí', () {
      final none = CamporeeOrderProductModel.fromJson({
        'camporee_order_product_id': 'p1',
        'owner_scope': 'UNION',
        'title': 'Libro',
        'size_scheme': 'NONE',
        'active': true,
        'options': const [],
      }).toEntity();
      expect(none.sizeScheme, CamporeeOrderSizeScheme.none);
      expect(none.requiresOption, isFalse);

      final letter = CamporeeOrderProductModel.fromJson({
        'camporee_order_product_id': 'p2',
        'owner_scope': 'LOCAL_FIELD',
        'title': 'Playera',
        'size_scheme': 'LETTER',
        'active': true,
        'options': [
          {
            'camporee_order_product_option_id': 'opt-m',
            'label': 'M',
            'sort_order': 2,
            'active': true,
          },
        ],
      }).toEntity();
      expect(letter.requiresOption, isTrue);
      expect(letter.options.first.label, 'M');
    });
  });

  group('CamporeeOrderOfferingsCatalogModel', () {
    test('parsea settings fail-closed y precio de oferta', () {
      final catalog = CamporeeOrderOfferingsCatalogModel.fromJson({
        'settings': {
          'orders_enabled': true,
          'orders_opens_at': null,
          'orders_deadline': '2026-09-01T05:59:59.000Z',
        },
        'items': [
          {
            'camporee_order_offering_id': 'off-1',
            'price_centavos': 19900,
            'active': true,
            'sort_order': 0,
            'product': {
              'camporee_order_product_id': 'p2',
              'owner_scope': 'DIVISION',
              'title': 'Gorra',
              'size_scheme': 'NUMERIC',
              'active': true,
              'options': [
                {
                  'camporee_order_product_option_id': 'opt-7',
                  'label': '7',
                  'sort_order': 0,
                  'active': true,
                },
              ],
            },
          },
        ],
      }).toEntity();
      expect(catalog.settings.ordersEnabled, isTrue);
      expect(catalog.items.first.priceCentavos, 19900);
      expect(catalog.items.first.product.sizeScheme,
          CamporeeOrderSizeScheme.numeric);
    });
  });
}
