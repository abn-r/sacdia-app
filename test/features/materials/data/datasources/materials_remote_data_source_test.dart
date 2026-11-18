import 'dart:io';

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

  group('MaterialsRemoteDataSourceImpl.uploadReceipt', () {
    Future<FormData> upload({String? fileName}) async {
      final adapter = JsonAdapter(201, {
        'data': {'id': 'r1', 'file_name': fileName ?? 'x.png'},
      });
      final dir = await Directory.systemTemp.createTemp('receipt_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/image_picker_ABC.png')
        ..writeAsBytesSync([1, 2, 3]);
      final dataSource = MaterialsRemoteDataSourceImpl(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'http://api.test/api/v1',
      );
      await dataSource.uploadReceipt(
        folioOrId: 'MAT-1',
        file: file,
        montoCentavos: 100,
        refBancariaDeclarada: 'MAT-1',
        fechaPago: DateTime(2026, 11, 15),
        fileName: fileName,
      );
      return adapter.lastRequest!.data as FormData;
    }

    test('sends the given file name as the multipart filename', () async {
      final form = await upload(fileName: 'comprobante-MAT-1.png');
      expect(form.files.single.value.filename, 'comprobante-MAT-1.png');
      expect(form.files.single.value.contentType.toString(), 'image/png');
    });

    test('falls back to the path name when none is given', () async {
      final form = await upload();
      expect(form.files.single.value.filename, 'image_picker_ABC.png');
    });
  });
}
