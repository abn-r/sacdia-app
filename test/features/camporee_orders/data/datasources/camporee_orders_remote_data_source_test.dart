import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
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

({Dio dio, _FakeAdapter adapter}) _dioWith(Map<String, dynamic> bodyJson) {
  final body = ResponseBody.fromString(
    jsonEncode(bodyJson),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  final adapter = _FakeAdapter(body);
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

Map<String, dynamic> _orderJson() => {
      'camporee_order_id': 'order-1',
      'local_field_id': 7,
      'club_id': 3,
      'club_section_id': 42,
      'local_camporee_id': 10,
      'union_camporee_id': null,
      'folio_reference': 'PED20260001',
      'status': 'ISSUED',
      'currency': 'MXN',
      'total_centavos': 15000,
      'expires_at': '2026-09-01T00:00:00.000Z',
      'created_at': '2026-08-24T00:00:00.000Z',
      'authorized_without_proof': false,
      'lines': const [],
      'summary': const [],
      'distribution_status': 'NOT_STARTED',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('POST local /camporees/:id/orders sin montos y con Idempotency-Key',
      () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': _orderJson(),
    });
    final ds = CamporeeOrdersRemoteDataSourceImpl(dio: dio, baseUrl: '/api/v1');

    await ds.createOrder(
      camporeeId: 10,
      camporeeType: CamporeeKind.local,
      idempotencyKey: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      lines: const [
        CamporeeOrderLineInput(
          camporeeMemberId: 801,
          offeringId: 'off-1',
          optionId: 'opt-m',
          qty: 1,
        ),
      ],
    );

    expect(adapter.lastOptions?.path, '/api/v1/camporees/10/orders');
    expect(adapter.lastOptions?.method, 'POST');
    expect(
      adapter.lastOptions?.headers['Idempotency-Key'],
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
    final body = adapter.lastBody as Map<String, dynamic>;
    expect(body.keys, ['lines']);
    final line = (body['lines'] as List).first as Map<String, dynamic>;
    expect(line['camporee_member_id'], 801);
    expect(line.containsKey('unit_price_centavos'), isFalse);
    expect(line.containsKey('total_centavos'), isFalse);
    expect(line.containsKey('user_id'), isFalse);
  });

  test('POST unión usa /union-camporees/:id/orders', () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': _orderJson(),
    });
    final ds = CamporeeOrdersRemoteDataSourceImpl(dio: dio, baseUrl: '/api/v1');
    await ds.createOrder(
      camporeeId: 88,
      camporeeType: CamporeeKind.union,
      lines: const [
        CamporeeOrderLineInput(
          camporeeMemberId: 801,
          offeringId: 'off-1',
          qty: 1,
        ),
      ],
    );
    expect(adapter.lastOptions?.path, '/api/v1/union-camporees/88/orders');
  });

  test('GET pending obligations no colapsa dos pedidos', () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': [
        {
          'source': 'CAMPOREE_ORDER',
          'source_id': 'o1',
          'purpose': 'CAMPOREE_MATERIALS',
          'folio': 'PED20260001',
          'total_centavos': 100,
          'currency': 'MXN',
          'status': 'PAYMENT_DUE',
          'action_required': 'UPLOAD_PROOF',
          'camporee': {'type': 'local', 'id': 10, 'name': 'Camporee A'},
          'created_at': '2026-08-24T00:00:00.000Z',
        },
        {
          'source': 'CAMPOREE_ORDER',
          'source_id': 'o2',
          'purpose': 'CAMPOREE_MATERIALS',
          'folio': 'PED20260002',
          'total_centavos': 200,
          'currency': 'MXN',
          'status': 'PAYMENT_DUE',
          'action_required': 'UPLOAD_PROOF',
          'camporee': {'type': 'local', 'id': 10, 'name': 'Camporee A'},
          'created_at': '2026-08-25T00:00:00.000Z',
        },
      ],
    });
    final ds = CamporeeOrdersRemoteDataSourceImpl(dio: dio, baseUrl: '/api/v1');
    final rows = await ds.listPendingObligations(camporeeId: 10);
    expect(adapter.lastOptions?.path, '/api/v1/payment-obligations/pending');
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.folio).toSet(), {'PED20260001', 'PED20260002'});
  });
}
