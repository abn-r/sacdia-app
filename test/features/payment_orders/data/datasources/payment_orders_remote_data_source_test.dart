import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/payment_orders/data/datasources/payment_orders_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fake HttpClientAdapter ────────────────────────────────────────────────────

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

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _orderJson({String id = 'order-1'}) => {
      'field_payment_order_id': id,
      'purpose': 'INSURANCE',
      'folio_reference': 'OP20260001',
      'currency': 'MXN',
      'unit_cost_centavos': 15000,
      'total_centavos': 15000,
      'status': 'ISSUED',
      'expires_at': '2026-08-27T00:00:00.000Z',
      'created_at': '2026-08-12T00:00:00.000Z',
      'lines': const [],
      'proofs': const [],
    };

PaymentOrdersRemoteDataSourceImpl _dataSource(Dio dio) =>
    PaymentOrdersRemoteDataSourceImpl(dio: dio, baseUrl: '/api/v1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('getContext', () {
    test('GET /payment-orders/context y desanida data', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'enabled': true,
          'local_field_id': 7,
          'club_section_id': 42,
          'insurance_cycles': const [],
        },
      });

      final context = await _dataSource(dio).getContext();

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/api/v1/payment-orders/context');
      expect(context.enabled, isTrue);
      expect(context.localFieldId, 7);
    });
  });

  group('createInsuranceOrder', () {
    test('POST /insurance/payment-orders con cuerpo correcto', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      final order = await _dataSource(dio).createInsuranceOrder(
        cycleConfigId: 3,
        beneficiaryUserIds: const ['user-1', 'user-2'],
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.path, '/api/v1/insurance/payment-orders');
      expect(adapter.lastBody, {
        'insurance_cycle_config_id': 3,
        'beneficiary_user_ids': ['user-1', 'user-2'],
      });
      expect(order.orderId, 'order-1');
    });
  });

  group('createCamporeeOrder', () {
    test('POST /camporees/:id/payment-orders con beneficiarios', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).createCamporeeOrder(
        camporeeId: 12,
        beneficiaryUserIds: const ['user-1'],
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/camporees/12/payment-orders',
      );
      expect(adapter.lastBody, {
        'beneficiary_user_ids': ['user-1'],
      });
    });

    test(
        'POST /union-camporees/:id/payment-orders cuando camporeeType es union',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).createCamporeeOrder(
        camporeeId: 90,
        beneficiaryUserIds: const ['user-1'],
        camporeeType: 'union',
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/union-camporees/90/payment-orders',
      );
      expect(adapter.lastBody, {
        'beneficiary_user_ids': ['user-1'],
      });
    });
  });

  group('listOrders', () {
    test('GET /payment-orders con filtros como query params', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [_orderJson(), _orderJson(id: 'order-2')],
      });

      final orders = await _dataSource(dio).listOrders(
        purpose: 'CAMPOREE',
        status: 'ISSUED',
        camporeeId: 12,
      );

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/api/v1/payment-orders');
      expect(adapter.lastOptions?.queryParameters, {
        'purpose': 'CAMPOREE',
        'status': 'ISSUED',
        'camporee_id': 12,
      });
      expect(orders, hasLength(2));
    });

    test('sin filtros no manda query params', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': const [],
      });

      await _dataSource(dio).listOrders();

      expect(adapter.lastOptions?.queryParameters, isEmpty);
    });
  });

  group('getOrder', () {
    test('GET /payment-orders/:orderId', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      final order = await _dataSource(dio).getOrder('order-1');

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/api/v1/payment-orders/order-1');
      expect(order.orderId, 'order-1');
    });
  });

  group('cancelOrder', () {
    test('POST /payment-orders/:orderId/cancel', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': _orderJson(),
      });

      await _dataSource(dio).cancelOrder('order-1');

      expect(adapter.lastOptions?.method, 'POST');
      expect(
        adapter.lastOptions?.path,
        '/api/v1/payment-orders/order-1/cancel',
      );
    });
  });

  group('reassignments', () {
    test('POST /insurance/reassignments con cuerpo correcto', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'insurance_reassignment_request_id': 11,
          'insurance_assignment_id': 5,
          'from_user_id': 'user-a',
          'to_user_id': 'user-b',
          'status': 'PENDING',
          'created_at': '2026-08-12T00:00:00.000Z',
        },
      });

      final request = await _dataSource(dio).createReassignment(
        insuranceAssignmentId: 5,
        toUserId: 'user-b',
        reason: 'Cambio',
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.path, '/api/v1/insurance/reassignments');
      expect(adapter.lastBody, {
        'insurance_assignment_id': 5,
        'to_user_id': 'user-b',
        'reason': 'Cambio',
      });
      expect(request.requestId, 11);
    });

    test('GET /insurance/reassignments con filtro de status', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': const [],
      });

      await _dataSource(dio).listReassignments(status: 'PENDING');

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/api/v1/insurance/reassignments');
      expect(adapter.lastOptions?.queryParameters, {'status': 'PENDING'});
    });
  });

  group('error mapping', () {
    test('código de negocio del backend se mapea a mensaje i18n', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ThrowingAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 403,
            data: {
              'code': 'FIELD_PAYMENT_ORDER_FLAG_DISABLED',
              'message': 'raw backend message',
            },
          ),
        ),
      );

      await expectLater(
        _dataSource(dio).getContext(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 403)
              // Sin assets cargados, tr() regresa la clave i18n.
              .having(
                (e) => e.message,
                'message',
                'payment_orders.errors.flag_disabled',
              ),
        ),
      );
    });

    test('error sin código de negocio usa el message del backend', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ThrowingAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 500,
            data: {'message': 'Unexpected failure'},
          ),
        ),
      );

      await expectLater(
        _dataSource(dio).getOrder('order-1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Unexpected failure'),
        ),
      );
    });
  });
}
