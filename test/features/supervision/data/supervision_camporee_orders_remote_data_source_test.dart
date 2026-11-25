import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_camporee_orders_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_camporee_orders_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';

SupervisionCamporeeOrdersRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionCamporeeOrdersRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

void _answer(
    RequestOptions o, RequestInterceptorHandler h, int status, Object body) {
  final res =
      Response<Object>(requestOptions: o, statusCode: status, data: body);
  if (status >= 400) {
    h.reject(DioException(
        requestOptions: o, response: res, type: DioExceptionType.badResponse));
  } else {
    h.resolve(res);
  }
}

SupervisionCamporeeOrdersRemoteDataSourceImpl _returning(
        int status, Object body) =>
    _ds((o, h) => _answer(o, h, status, body));

({
  SupervisionCamporeeOrdersRemoteDataSourceImpl ds,
  RequestOptions Function() req,
}) _capturing(Object data) {
  late RequestOptions captured;
  final ds = _ds((o, h) {
    captured = o;
    _answer(o, h, 200, {'status': 'success', 'data': data});
  });
  return (ds: ds, req: () => captured);
}

Map<String, dynamic> _product(String id) => {
      'camporee_order_product_id': id,
      'owner_scope': 'UNION',
      'title': 'Shirt $id',
      'size_scheme': 'NONE',
      'active': true,
      'options': [],
    };

const _slotJson = {
  'slot_id': 's1',
  'label': 'Lunch',
  'deliver_time': '12:00',
  'sort_order': 0,
  'active': true,
};
const _productJson = {
  'product_id': 'p1',
  'name': 'Rice',
  'uom': 'KG',
  'unit_cost_centavos': 100,
  'active': true,
};
const _catalogJson = {
  'supply_edit_cutoff_local_time': '18:00',
  'timezone': 'UTC',
  'slots': [_slotJson],
  'products': [_productJson],
};

void main() {
  group('getOrderConfig', () {
    test('calls both endpoints, active=true on the library, unwraps', () async {
      final requests = <RequestOptions>[];
      final ds = _ds((o, h) {
        requests.add(o);
        if (o.path.endsWith('/order-offerings')) {
          _answer(o, h, 200, {
            'status': 'success',
            'data': {
              'settings': {'orders_enabled': true},
              'items': [
                {
                  'camporee_order_offering_id': 'f1',
                  'price_centavos': 1500,
                  'active': false,
                  'sort_order': 0,
                  'product': _product('p1'),
                },
              ],
            },
          });
        } else {
          _answer(o, h, 200, {
            'status': 'success',
            'data': [_product('p1'), _product('p2')],
          });
        }
      });
      final config = await ds.getOrderConfig(7);
      expect(requests, hasLength(2));
      final offerings =
          requests.firstWhere((r) => r.path.endsWith('/order-offerings'));
      final library = requests
          .firstWhere((r) => r.path.endsWith('/camporee-order-products'));
      expect(offerings.method, 'GET');
      expect(offerings.uri.path, '/api/v1/union-camporees/7/order-offerings');
      expect(library.uri.path, '/api/v1/camporee-order-products');
      expect(library.uri.queryParameters, {'active': 'true'});
      expect(config.settings.ordersEnabled, isTrue);
      expect(config.offerings.single.active, isFalse);
      expect(config.products.map((p) => p.productId), ['p1', 'p2']);
    });

    test('either request failing fails the call', () async {
      for (final failing in ['/order-offerings', '/camporee-order-products']) {
        final ds = _ds((o, h) {
          if (o.path.endsWith(failing)) {
            _answer(o, h, 403, {'code': 'CAMPOREE_ORDER_FORBIDDEN'});
          } else {
            _answer(o, h, 200, {'data': o.path.endsWith('products') ? [] : {}});
          }
        });
        await expectLater(
          ds.getOrderConfig(7),
          throwsA(isA<AuthException>()
              .having((e) => e.errorCode, 'code', 'CAMPOREE_ORDER_FORBIDDEN')),
        );
      }
    });
  });

  group('updateOrderSettings', () {
    test('sends only the enabled flag when only it is patched', () async {
      final c = _capturing({
        'orders_enabled': true,
        'orders_opens_at': null,
        'orders_deadline': null,
      });
      final s = await c.ds.updateOrderSettings(
          7, const SupervisionOrderSettingsPatch(ordersEnabled: true));
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/orders-settings');
      expect(c.req().data, {'orders_enabled': true});
      expect(s.ordersEnabled, isTrue);
    });

    test('timestamps go as UTC ISO with Z', () async {
      final c = _capturing({'orders_enabled': false});
      final local = DateTime(2026, 5, 4, 9, 30);
      await c.ds.updateOrderSettings(
          7, SupervisionOrderSettingsPatch(opensAt: local, deadline: local));
      final body = c.req().data as Map;
      expect(body.keys.toSet(), {'orders_opens_at', 'orders_deadline'});
      expect(body['orders_opens_at'], local.toUtc().toIso8601String());
      expect((body['orders_opens_at'] as String).endsWith('Z'), isTrue);
    });

    test('clear flags send null, unset keys are absent', () async {
      final c = _capturing({'orders_enabled': true});
      await c.ds.updateOrderSettings(
          7, const SupervisionOrderSettingsPatch(clearDeadline: true));
      final body = c.req().data as Map;
      expect(body.containsKey('orders_deadline'), isTrue);
      expect(body['orders_deadline'], isNull);
      expect(body.containsKey('orders_enabled'), isFalse);
      expect(body.containsKey('orders_opens_at'), isFalse);
    });

    test('clear wins over a value', () async {
      final c = _capturing({'orders_enabled': true});
      await c.ds.updateOrderSettings(
          7,
          SupervisionOrderSettingsPatch(
              opensAt: DateTime.utc(2026), clearOpensAt: true));
      expect((c.req().data as Map)['orders_opens_at'], isNull);
    });

    test('maps 404 keeping the code', () async {
      final ds = _returning(404, {'code': 'CAMPOREE_ORDER_NOT_FOUND'});
      await expectLater(
        ds.updateOrderSettings(7, const SupervisionOrderSettingsPatch()),
        throwsA(isA<ServerException>()
            .having((e) => e.errorCode, 'code', 'CAMPOREE_ORDER_NOT_FOUND')),
      );
    });
  });

  group('replaceOfferings', () {
    test('PUTs the exact body shape with active true', () async {
      final c = _capturing({
        'settings': {'orders_enabled': true},
        'items': [],
      });
      final catalog = await c.ds.replaceOfferings(7, const [
        SupervisionOfferingInput(
            productId: 'p1', priceCentavos: 1500, sortOrder: 0),
        SupervisionOfferingInput(
            productId: 'p2', priceCentavos: 200, sortOrder: 1),
      ]);
      expect(c.req().method, 'PUT');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/order-offerings');
      expect(c.req().data, {
        'items': [
          {
            'product_id': 'p1',
            'price_centavos': 1500,
            'active': true,
            'sort_order': 0,
          },
          {
            'product_id': 'p2',
            'price_centavos': 200,
            'active': true,
            'sort_order': 1,
          },
        ],
      });
      expect(catalog.settings.ordersEnabled, isTrue);
    });

    test('an empty list is sent as is', () async {
      final c = _capturing({'settings': {}, 'items': []});
      await c.ds.replaceOfferings(7, const []);
      expect(c.req().data, {'items': <Object?>[]});
    });

    test('maps 422 keeping the code', () async {
      final ds = _returning(422, {'code': 'CAMPOREE_ORDER_OPTION_REQUIRED'});
      await expectLater(
        ds.replaceOfferings(7, const []),
        throwsA(isA<ServerException>().having(
            (e) => e.errorCode, 'code', 'CAMPOREE_ORDER_OPTION_REQUIRED')),
      );
    });
  });

  group('supplies', () {
    test('getSupplyCatalog GET path and parse', () async {
      final c = _capturing(_catalogJson);
      final catalog = await c.ds.getSupplyCatalog(7);
      expect(c.req().method, 'GET');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-catalog');
      expect(catalog.cutoffTime, '18:00');
      expect(catalog.slots.single.id, 's1');
    });

    test('updateSupplyCutoff PATCH body', () async {
      final c = _capturing(_catalogJson);
      await c.ds.updateSupplyCutoff(7, '17:30');
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-settings');
      expect(c.req().data, {'supply_edit_cutoff_local_time': '17:30'});
    });

    test('createSupplySlot POST body has no sort_order', () async {
      final c = _capturing(_slotJson);
      final slot =
          await c.ds.createSupplySlot(7, label: 'Lunch', deliverTime: '12:00');
      expect(c.req().method, 'POST');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-slots');
      expect(c.req().data, {'label': 'Lunch', 'deliver_time': '12:00'});
      expect(slot.id, 's1');
    });

    test('updateSupplySlot PATCH omits null optionals', () async {
      final c = _capturing(_slotJson);
      await c.ds.updateSupplySlot(7, 's1', active: false);
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-slots/s1');
      expect(c.req().data, {'active': false});
      await c.ds.updateSupplySlot(7, 's1', label: 'L', deliverTime: '08:00');
      expect(c.req().data, {'label': 'L', 'deliver_time': '08:00'});
    });

    test('createSupplyProduct POST body', () async {
      final c = _capturing(_productJson);
      final p = await c.ds.createSupplyProduct(7,
          name: 'Rice', uom: SupervisionSupplyUom.kg, unitCostCentavos: 100);
      expect(c.req().method, 'POST');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-products');
      expect(c.req().data,
          {'name': 'Rice', 'uom': 'KG', 'unit_cost_centavos': 100});
      expect(p.id, 'p1');
    });

    test('updateSupplyProduct PATCH omits null optionals', () async {
      final c = _capturing(_productJson);
      await c.ds.updateSupplyProduct(7, 'p1', unitCostCentavos: 0);
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/union-camporees/7/supply-products/p1');
      expect(c.req().data, {'unit_cost_centavos': 0});
      await c.ds.updateSupplyProduct(7, 'p1',
          name: 'N', uom: SupervisionSupplyUom.bag, active: true);
      expect(c.req().data, {'name': 'N', 'uom': 'BAG', 'active': true});
    });

    test('unknown uom fails before any request', () async {
      var calls = 0;
      final ds = _ds((o, h) {
        calls++;
        _answer(o, h, 200, {'data': _productJson});
      });
      await expectLater(
        ds.createSupplyProduct(7,
            name: 'x', uom: SupervisionSupplyUom.unknown, unitCostCentavos: 1),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        ds.updateSupplyProduct(7, 'p1', uom: SupervisionSupplyUom.unknown),
        throwsA(isA<ServerException>()),
      );
      expect(calls, 0);
    });

    test('unparsable success body is a ServerException', () async {
      final ds = _returning(200, {'data': 'nope'});
      await expectLater(
          ds.getSupplyCatalog(7), throwsA(isA<ServerException>()));
      await expectLater(
          ds.createSupplySlot(7, label: 'a', deliverTime: '10:00'),
          throwsA(isA<ServerException>()));
    });

    test('error mapping keeps the business code', () async {
      await expectLater(
        _returning(422, {'code': 'CAMPOREE_SUPPLIES_PRICE_LOCKED'})
            .updateSupplyProduct(7, 'p1', unitCostCentavos: 5),
        throwsA(isA<ServerException>().having(
            (e) => e.errorCode, 'code', 'CAMPOREE_SUPPLIES_PRICE_LOCKED')),
      );
      await expectLater(
        _returning(403, {'code': 'CAMPOREE_SUPPLIES_FORBIDDEN'})
            .updateSupplyCutoff(7, '10:00'),
        throwsA(isA<AuthException>()
            .having((e) => e.errorCode, 'code', 'CAMPOREE_SUPPLIES_FORBIDDEN')),
      );
      await expectLater(
        _returning(404, {'code': 'CAMPOREE_SUPPLIES_SLOT_INVALID'})
            .updateSupplySlot(7, 'zz', active: true),
        throwsA(isA<ServerException>().having(
            (e) => e.errorCode, 'code', 'CAMPOREE_SUPPLIES_SLOT_INVALID')),
      );
    });
  });

  group('repository', () {
    test('maps exceptions to failures keeping the code', () async {
      final repo = SupervisionCamporeeOrdersRepositoryImpl(
        remoteDataSource:
            _returning(403, {'code': 'CAMPOREE_SUPPLIES_FORBIDDEN'}),
      );
      final result = await repo.getSupplyCatalog(7);
      final failure = result.swap().getOrElse(() => throw StateError('right'));
      expect(failure.errorCode, 'CAMPOREE_SUPPLIES_FORBIDDEN');
      expect(failure.code, 403);
    });
  });
}
