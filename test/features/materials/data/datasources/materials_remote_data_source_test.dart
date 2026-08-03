import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/materials/data/datasources/materials_remote_data_source.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _FakeAdapter adapter}) _dioWith(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  final adapter = _FakeAdapter(
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
  final dio = Dio(BaseOptions(responseType: ResponseType.json))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

Map<String, dynamic> _cancelledOrderJson() => {
      'data': {
        'id': 'order-1',
        'folio_referencia': 'SOL/2026 001',
        'estado': 'cancelada',
        'club_section_id': 12,
        'created_by': 'user-1',
        'subtotal_centavos': 1000,
        'envio_centavos': 0,
        'total_centavos': 1000,
        'entrega': 'recoger',
        'cancel_reason': 'Cambio de planes',
        'created_at': '2026-08-03T00:00:00.000Z',
        'lines': [],
        'comprobantes': [],
      },
    };

void main() {
  const baseUrl = 'https://api.test/api/v1';

  group('MaterialsRemoteDataSourceImpl.cancelOrder', () {
    test('POSTs the encoded folio and required cancellation body', () async {
      final (:dio, :adapter) = _dioWith(_cancelledOrderJson());
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: baseUrl,
      );

      final order = await dataSource.cancelOrder(
        'SOL/2026 001',
        'Cambio de planes',
      );

      expect(
        adapter.lastOptions!.path,
        '$baseUrl/materials/orders/SOL%2F2026%20001/cancel',
      );
      expect(adapter.lastOptions!.method, 'POST');
      expect(adapter.lastOptions!.data, {'cancel_reason': 'Cambio de planes'});
      expect(order.id, 'order-1');
      expect(order.cancelReason, 'Cambio de planes');
    });

    test('rejects an empty folio before constructing a double-slash URL',
        () async {
      final (:dio, :adapter) = _dioWith(_cancelledOrderJson());
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: baseUrl,
      );

      await expectLater(
        dataSource.cancelOrder('', 'Cambio de planes'),
        throwsA(isA<ServerException>()),
      );
      expect(adapter.lastOptions, isNull);
    });

    test('preserves the cancellation authorization failure', () async {
      final (:dio, :adapter) = _dioWith(
        {'message': 'cancel_forbidden'},
        statusCode: 403,
      );
      dio.interceptors.add(ErrorInterceptor());
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: baseUrl,
      );

      await expectLater(
        dataSource.cancelOrder('SOL-001', 'Cambio de planes'),
        throwsA(
          isA<AuthException>()
              .having((error) => error.code, 'code', 403)
              .having((error) => error.message, 'message', 'cancel_forbidden'),
        ),
      );
      expect(adapter.lastOptions!.path,
          '$baseUrl/materials/orders/SOL-001/cancel');
    });

    test('maps a missing order to NotFoundException', () async {
      final response = _dioWith(
        {'message': 'order_not_found'},
        statusCode: 404,
      );
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: response.dio,
        baseUrl: baseUrl,
      );

      await expectLater(
        dataSource.cancelOrder('SOL-404', 'Cambio de planes'),
        throwsA(
          isA<NotFoundException>()
              .having((error) => error.code, 'code', 404)
              .having((error) => error.message, 'message', 'order_not_found'),
        ),
      );
    });

    test('maps a cancellation conflict to ServerException', () async {
      final response = _dioWith(
        {'message': 'state_machine_violation'},
        statusCode: 409,
      );
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: response.dio,
        baseUrl: baseUrl,
      );

      await expectLater(
        dataSource.cancelOrder('SOL-409', 'Cambio de planes'),
        throwsA(
          isA<ServerException>()
              .having((error) => error.code, 'code', 409)
              .having(
                (error) => error.message,
                'message',
                'state_machine_violation',
              ),
        ),
      );
    });
  });
}
