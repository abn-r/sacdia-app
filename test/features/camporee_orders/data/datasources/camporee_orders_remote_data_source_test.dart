import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/camporee_orders/data/datasources/camporee_orders_remote_data_source.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastBody = options.data;
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _FakeAdapter adapter}) _dioWith(
  Map<String, dynamic> bodyJson, {
  int statusCode = 200,
}) {
  final body = ResponseBody.fromString(
    jsonEncode(bodyJson),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  final adapter = _FakeAdapter(body);
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this._builder);

  final DioException Function(RequestOptions) _builder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw _builder(options);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _orderJson({String id = 'ord-1'}) => {
      'camporee_order_id': id,
      'local_camporee_id': 17,
      'union_camporee_id': null,
      'folio_reference': 'PED20260001',
      'status': 'ISSUED',
      'currency': 'MXN',
      'total_centavos': 250000,
      'expires_at': '2026-09-10T00:00:00.000Z',
      'created_at': '2026-08-24T18:00:00.000Z',
      'authorized_without_proof': false,
      'distribution_status': 'NOT_STARTED',
      'lines': const [],
      'summary': const [],
    };

CamporeeOrdersRemoteDataSourceImpl _dataSource(Dio dio) =>
    CamporeeOrdersRemoteDataSourceImpl(dio: dio, baseUrl: '/api/v1');

const _forbiddenLineKeys = {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('createOrder payload', () {
    test(
        'POST /camporees/:id/orders con camporee_member_id y sin montos',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      const sized = CamporeeOrderCreateLine(
        camporeeMemberId: 801,
        offeringId: 'uuid-playera',
        optionId: 'uuid-m',
        qty: 1,
      );
      const unsized = CamporeeOrderCreateLine(
        camporeeMemberId: 802,
        offeringId: 'uuid-pin',
        qty: 1,
      );

      await _dataSource(dio).createOrder(
        camporeeId: 17,
        camporeeType: 'local',
        lines: [sized.toJson(), unsized.toJson()],
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.path, '/api/v1/camporees/17/orders');
      expect(
        adapter.lastOptions?.path.contains('payment-orders'),
        isFalse,
      );

      final body = adapter.lastBody as Map<String, dynamic>;
      expect(body.keys, ['lines']);
      expect(body['lines'], [
        {
          'camporee_member_id': 801,
          'offering_id': 'uuid-playera',
          'option_id': 'uuid-m',
          'qty': 1,
        },
        {
          'camporee_member_id': 802,
          'offering_id': 'uuid-pin',
          'qty': 1,
        },
      ]);

      for (final line in body['lines'] as List) {
        final keys = (line as Map).keys.map((k) => k.toString()).toSet();
        expect(keys.intersection(_forbiddenLineKeys), isEmpty);
      }
    });

    test('POST /union-camporees/:id/orders y header Idempotency-Key', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).createOrder(
        camporeeId: 8,
        camporeeType: 'union',
        lines: const [
          CamporeeOrderCreateLine(
            camporeeMemberId: 801,
            offeringId: 'off-1',
            qty: 1,
          ),
        ].map((l) => l.toJson()).toList(),
        idempotencyKey: '11111111-1111-1111-1111-111111111111',
      );

      expect(
        adapter.lastOptions?.path,
        '/api/v1/union-camporees/8/orders',
      );
      expect(
        adapter.lastOptions?.headers['Idempotency-Key'],
        '11111111-1111-1111-1111-111111111111',
      );
    });
  });

  group('list / get / offerings / obligations', () {
    test('GET /camporee-orders con camporee_id local', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [_orderJson(), _orderJson(id: 'ord-2')],
      });

      final orders = await _dataSource(dio).listOrders(localCamporeeId: 17);

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/api/v1/camporee-orders');
      expect(adapter.lastOptions?.queryParameters, {'camporee_id': 17});
      expect(orders, hasLength(2));
    });

    test('GET /camporee-orders/:orderId desanida data', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      final order = await _dataSource(dio).getOrder('ord-1');

      expect(adapter.lastOptions?.path, '/api/v1/camporee-orders/ord-1');
      expect(order.orderId, 'ord-1');
    });

    test('GET /camporees/:id/order-offerings', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'settings': {
            'orders_enabled': true,
            'orders_opens_at': null,
            'orders_deadline': null,
          },
          'items': const [],
        },
      });

      final result = await _dataSource(dio).getOfferings(
        camporeeId: 17,
        camporeeType: 'local',
      );

      expect(
        adapter.lastOptions?.path,
        '/api/v1/camporees/17/order-offerings',
      );
      expect(result.settings.ordersEnabled, isTrue);
    });

    test('GET /union-camporees/:id/order-offerings', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'settings': {'orders_enabled': false},
          'items': const [],
        },
      });

      await _dataSource(dio).getOfferings(
        camporeeId: 8,
        camporeeType: 'union',
      );

      expect(
        adapter.lastOptions?.path,
        '/api/v1/union-camporees/8/order-offerings',
      );
    });

    test('GET /camporee-order-products', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [
          {
            'camporee_order_product_id': 'prod-1',
            'title': 'Playera',
            'size_scheme': 'LETTER',
            'owner_scope': 'DIVISION',
            'active': true,
            'options': const [],
          },
        ],
      });

      final products = await _dataSource(dio).listProducts(active: true);

      expect(adapter.lastOptions?.path, '/api/v1/camporee-order-products');
      expect(adapter.lastOptions?.queryParameters, {'active': true});
      expect(products.single.productId, 'prod-1');
    });

    test('GET /payment-obligations/pending sin fusionar filas', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [
          {
            'source': 'CAMPOREE_ORDER',
            'source_id': 'ord-a',
            'purpose': 'CAMPOREE_MATERIALS',
            'folio': 'PED20260001',
            'total_centavos': 100,
            'currency': 'MXN',
            'status': 'PAYMENT_DUE',
            'action_required': 'UPLOAD_PROOF',
            'camporee': {'type': 'local', 'id': 17, 'name': 'Camporí 2026'},
            'created_at': '2026-08-24T18:00:00.000Z',
          },
          {
            'source': 'FIELD_PAYMENT_ORDER',
            'source_id': 'insc-1',
            'purpose': 'CAMPOREE',
            'folio': 'ORD20260002',
            'total_centavos': 200,
            'currency': 'MXN',
            'status': 'PAYMENT_DUE',
            'action_required': 'UPLOAD_PROOF',
            'camporee': {'type': 'local', 'id': 17, 'name': 'Camporí 2026'},
            'created_at': '2026-08-24T17:00:00.000Z',
          },
        ],
      });

      final rows = await _dataSource(dio).listPendingObligations(camporeeId: 17);

      expect(
        adapter.lastOptions?.path,
        '/api/v1/payment-obligations/pending',
      );
      expect(adapter.lastOptions?.queryParameters, {'camporee_id': 17});
      expect(rows, hasLength(2));
      expect(rows.first.folio, 'PED20260001');
      expect(rows.last.folio, 'ORD20260002');
    });

    test('POST /camporee-orders/:id/cancel', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).cancelOrder('ord-1');
      expect(adapter.lastOptions?.method, 'POST');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/camporee-orders/ord-1/cancel',
      );
    });

    test('POST /camporee-orders/:id/lines/:lineId/deliver-to-member', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).deliverLineToMember(
        orderId: 'ord-1',
        lineId: 'line-1',
      );
      expect(adapter.lastOptions?.method, 'POST');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/camporee-orders/ord-1/lines/line-1/deliver-to-member',
      );
    });

    test('GET proof', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'url': 'https://signed.example/proof',
          'expires_in': 900,
          'file_name': 'pago.pdf',
          'mime_type': 'application/pdf',
          'status': 'SUBMITTED',
          'created_at': '2026-08-24T18:00:00.000Z',
        },
      });

      final proof = await _dataSource(dio).getProof('ord-1');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/camporee-orders/ord-1/proof',
      );
      expect(proof.url, 'https://signed.example/proof');
      expect(proof.expiresIn, 900);
    });
  });

  group('error mapping', () {
    test('CAMPOREE_ORDER_* se mapea a clave i18n', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ThrowingAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 422,
            data: {
              'code': 'CAMPOREE_ORDER_MEMBER_NOT_ELIGIBLE',
              'message': 'raw backend message',
            },
          ),
        ),
      );

      await expectLater(
        _dataSource(dio).getOrder('ord-1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 422)
              .having(
                (e) => e.message,
                'message',
                'camporee_orders.errors.member_not_eligible',
              ),
        ),
      );
    });
  });
}
