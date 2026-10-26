import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/data/datasources/materials_remote_data_source.dart';

import '../../../../support/http_adapters.dart';

void main() {
  group('MaterialsRemoteDataSourceImpl.cancelOrder', () {
    test('sends the folio in the cancel URL and the reason in the body',
        () async {
      final adapter = JsonAdapter(200, {
        'data': {
          'id': 'order-1',
          'folio_referencia': 'SOL20260003',
          'estado': 'cancelada',
          'subtotal_centavos': 6000,
          'total_centavos': 6000,
        },
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://api.test/api/v1',
      );

      final order =
          await dataSource.cancelOrder('SOL20260003', 'Ya no se necesita');

      expect(
        adapter.lastRequest!.uri.path,
        '/api/v1/materials/orders/SOL20260003/cancel',
      );
      expect(adapter.lastRequest!.data, {'cancel_reason': 'Ya no se necesita'});
      expect(order.folioReferencia, 'SOL20260003');
    });

    test('encodes an id that contains reserved characters', () async {
      final adapter = JsonAdapter(200, {
        'data': {'id': 'a b', 'estado': 'cancelada'},
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://api.test/api/v1',
      );

      await dataSource.cancelOrder('a b', 'x');

      expect(
        adapter.lastRequest!.uri.toString(),
        'http://api.test/api/v1/materials/orders/a%20b/cancel',
      );
    });
  });
}
