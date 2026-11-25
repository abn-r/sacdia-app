import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_camporee_orders_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';

Map<String, dynamic> _product(String id, {bool active = true}) => {
      'camporee_order_product_id': id,
      'owner_scope': 'UNION',
      'title': 'Shirt $id',
      'size_scheme': 'LETTER',
      'active': active,
      'options': [
        {
          'camporee_order_product_option_id': 'o-$id',
          'label': 'M',
          'sort_order': '2',
          'active': true,
        },
      ],
    };

Map<String, dynamic> _offering(String id, String productId,
        {bool active = true, Object? price = 1500, Object? sort = 0}) =>
    {
      'camporee_order_offering_id': id,
      'product_id': productId,
      'price_centavos': price,
      'active': active,
      'sort_order': sort,
      'product': _product(productId),
    };

void main() {
  group('supply catalog', () {
    test('parses settings, slots and products keeping inactive rows', () {
      final c = SupervisionCamporeeOrdersModel.tryParseCatalog({
        'supply_edit_cutoff_local_time': '18:00',
        'timezone': 'America/Mexico_City',
        'start_date': '2026-01-01',
        'end_date': '2026-01-05',
        'slots': [
          {
            'slot_id': 's1',
            'label': 'Breakfast',
            'deliver_time': '07:30',
            'sort_order': 1,
            'active': true,
          },
          {
            'slot_id': 's2',
            'label': 'Lunch',
            'deliver_time': '12:00',
            'sort_order': '2',
            'active': false,
          },
        ],
        'products': [
          {
            'product_id': 'p1',
            'name': 'Rice',
            'uom': 'KG',
            'unit_cost_centavos': 2500,
            'active': true,
          },
          {
            'product_id': 'p2',
            'name': 'Milk',
            'uom': 'L',
            'unit_cost_centavos': '1800',
            'active': false,
          },
        ],
      })!;
      expect(c.cutoffTime, '18:00');
      expect(c.timezone, 'America/Mexico_City');
      expect(c.slots.map((s) => s.id), ['s1', 's2']);
      expect(c.slots[1].active, isFalse);
      expect(c.slots[1].sortOrder, 2);
      expect(c.products[1].active, isFalse);
      expect(c.products[1].unitCostCentavos, 1800);
      expect(c.products[1].uom, SupervisionSupplyUom.l);
    });

    test('maps every uom and unknown strings to unknown', () {
      expect(SupervisionCamporeeOrdersModel.uomFromWire('KG'),
          SupervisionSupplyUom.kg);
      expect(SupervisionCamporeeOrdersModel.uomFromWire('L'),
          SupervisionSupplyUom.l);
      expect(SupervisionCamporeeOrdersModel.uomFromWire('BAG'),
          SupervisionSupplyUom.bag);
      expect(SupervisionCamporeeOrdersModel.uomFromWire('UNIT'),
          SupervisionSupplyUom.unit);
      expect(SupervisionCamporeeOrdersModel.uomFromWire('GALLON'),
          SupervisionSupplyUom.unknown);
      expect(SupervisionCamporeeOrdersModel.uomFromWire(null),
          SupervisionSupplyUom.unknown);
      expect(SupervisionCamporeeOrdersModel.uomFromWire(3),
          SupervisionSupplyUom.unknown);
      expect(SupervisionCamporeeOrdersModel.uomToWire(SupervisionSupplyUom.bag),
          'BAG');
      expect(
          SupervisionCamporeeOrdersModel.uomToWire(
              SupervisionSupplyUom.unknown),
          isNull);
    });

    test('drops rows without id and tolerates nulls and wrong types', () {
      final c = SupervisionCamporeeOrdersModel.tryParseCatalog({
        'supply_edit_cutoff_local_time': null,
        'timezone': 5,
        'slots': [
          {'label': 'No id'},
          'junk',
          null,
          {'slot_id': 's1', 'label': null, 'sort_order': 'x', 'active': null},
        ],
        'products': [
          {'name': 'No id'},
          {'product_id': 'p1', 'uom': 'ZZ', 'unit_cost_centavos': {}},
        ],
      })!;
      expect(c.cutoffTime, '');
      expect(c.slots.single.id, 's1');
      expect(c.slots.single.label, '');
      expect(c.slots.single.sortOrder, 0);
      expect(c.products.single.uom, SupervisionSupplyUom.unknown);
      expect(c.products.single.unitCostCentavos, 0);
    });

    test('non-object body is null; missing lists are empty', () {
      expect(SupervisionCamporeeOrdersModel.tryParseCatalog('x'), isNull);
      final c = SupervisionCamporeeOrdersModel.tryParseCatalog({})!;
      expect(c.slots, isEmpty);
      expect(c.products, isEmpty);
    });
  });

  group('slot and product payloads', () {
    test('slot', () {
      final s = SupervisionCamporeeOrdersModel.tryParseSlot({
        'slot_id': 's1',
        'label': 'Dinner',
        'deliver_time': '19:00',
        'sort_order': 3,
        'active': true,
      })!;
      expect(s.label, 'Dinner');
      expect(s.deliverTime, '19:00');
      expect(
          SupervisionCamporeeOrdersModel.tryParseSlot({'label': 'x'}), isNull);
      expect(SupervisionCamporeeOrdersModel.tryParseSlot(null), isNull);
    });

    test('product', () {
      final p = SupervisionCamporeeOrdersModel.tryParseProduct({
        'product_id': 'p1',
        'name': 'Flour',
        'uom': 'BAG',
        'unit_cost_centavos': 9900,
        'active': false,
      })!;
      expect(p.uom, SupervisionSupplyUom.bag);
      expect(p.active, isFalse);
      expect(SupervisionCamporeeOrdersModel.tryParseProduct([]), isNull);
    });
  });

  group('merchandise payloads', () {
    test('offerings catalog reuses entities and normalizes types', () {
      final catalog = SupervisionCamporeeOrdersModel.parseOfferingsCatalog({
        'settings': {
          'orders_enabled': true,
          'orders_opens_at': '2026-03-01T10:00:00Z',
          'orders_deadline': null,
        },
        'items': [
          _offering('f1', 'p1', price: '1500', sort: '4'),
          _offering('f2', 'p2', active: false),
          {'product': _product('p3')},
          'junk',
          {'camporee_order_offering_id': 'f4', 'product': 'bad'},
        ],
      });
      expect(catalog.settings.ordersEnabled, isTrue);
      expect(catalog.settings.ordersOpensAt, DateTime.utc(2026, 3, 1, 10));
      expect(catalog.settings.ordersDeadline, isNull);
      expect(catalog.items.map((i) => i.offeringId), ['f1', 'f2']);
      expect(catalog.items.first.priceCentavos, 1500);
      expect(catalog.items.first.sortOrder, 4);
      expect(catalog.items.last.active, isFalse);
      expect(catalog.items.first.product.options.single.sortOrder, 2);
    });

    test('settings tolerate garbage', () {
      final s = SupervisionCamporeeOrdersModel.parseSettings('nope');
      expect(s.ordersEnabled, isFalse);
      expect(s.ordersOpensAt, isNull);
    });

    test('library drops rows without id', () {
      final list = SupervisionCamporeeOrdersModel.parseProducts([
        _product('p1'),
        {'title': 'No id'},
        5,
      ]);
      expect(list.single.productId, 'p1');
      expect(SupervisionCamporeeOrdersModel.parseProducts('x'), isEmpty);
    });
  });

  group('SupervisionCamporeeOrderConfig.activeOfferingOf', () {
    CamporeeOrderOffering offering(String id, String productId, bool active) =>
        CamporeeOrderOffering(
          offeringId: id,
          priceCentavos: 100,
          active: active,
          sortOrder: 0,
          product: CamporeeOrderProduct(
            productId: productId,
            ownerScope: CamporeeOrderOwnerScope.union,
            title: 't',
            sizeScheme: CamporeeOrderSizeScheme.none,
            active: true,
          ),
        );

    test('returns only the active offering of the product', () {
      final config = SupervisionCamporeeOrderConfig(
        settings: const CamporeeOrderSettings(ordersEnabled: true),
        offerings: [
          offering('f1', 'p1', false),
          offering('f2', 'p2', true),
        ],
      );
      expect(config.activeOfferingOf('p1'), isNull);
      expect(config.activeOfferingOf('p2')?.offeringId, 'f2');
      expect(config.activeOfferingOf('zzz'), isNull);
    });
  });
}
