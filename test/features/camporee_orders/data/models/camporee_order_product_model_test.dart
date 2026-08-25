import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_offering_model.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_product_model.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';

void main() {
  group('CamporeeOrderProductModel', () {
    test('parsea LETTER con opciones de talla', () {
      final entity = CamporeeOrderProductModel.fromJson({
        'camporee_order_product_id': 'prod-1',
        'title': 'Playera hombre',
        'description': 'Algodón',
        'size_scheme': 'LETTER',
        'owner_scope': 'LOCAL_FIELD',
        'owner_local_field_id': 7,
        'active': true,
        'options': [
          {
            'camporee_order_product_option_id': 'opt-m',
            'product_id': 'prod-1',
            'label': 'M',
            'sort_order': 2,
            'active': true,
          },
        ],
      }).toEntity();

      expect(entity.productId, 'prod-1');
      expect(entity.sizeScheme, CamporeeOrderSizeScheme.letter);
      expect(entity.sizeScheme.requiresOption, isTrue);
      expect(entity.options.single.label, 'M');
    });

    test('size_scheme NONE no exige option y admite options vacías', () {
      final entity = CamporeeOrderProductModel.fromJson({
        'camporee_order_product_id': 'prod-pin',
        'title': 'Pin camporí',
        'size_scheme': 'NONE',
        'owner_scope': 'UNION',
        'owner_union_id': 3,
        'active': true,
        'options': const [],
      }).toEntity();

      expect(entity.sizeScheme, CamporeeOrderSizeScheme.none);
      expect(entity.sizeScheme.requiresOption, isFalse);
      expect(entity.options, isEmpty);
    });
  });

  group('CamporeeOrderOfferingsResultModel', () {
    test('parsea settings + items con producto anidado', () {
      final result = CamporeeOrderOfferingsResultModel.fromJson({
        'settings': {
          'orders_enabled': true,
          'orders_opens_at': '2026-08-01T00:00:00.000Z',
          'orders_deadline': null,
        },
        'items': [
          {
            'camporee_order_offering_id': 'off-1',
            'local_camporee_id': 17,
            'union_camporee_id': null,
            'product_id': 'prod-pin',
            'price_centavos': 5000,
            'active': true,
            'sort_order': 0,
            'product': {
              'camporee_order_product_id': 'prod-pin',
              'title': 'Pin camporí',
              'size_scheme': 'NONE',
              'owner_scope': 'UNION',
              'active': true,
              'options': const [],
            },
          },
        ],
      }).toEntity();

      expect(result.settings.ordersEnabled, isTrue);
      expect(result.settings.ordersDeadline, isNull);
      expect(result.items, hasLength(1));
      expect(result.items.single.priceCentavos, 5000);
      expect(result.items.single.requiresOption, isFalse);
      expect(result.items.single.product.sizeScheme,
          CamporeeOrderSizeScheme.none);
    });
  });
}
