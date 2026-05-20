import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (requestStream != null) {
      lastBody =
          utf8.decode(await requestStream.expand((chunk) => chunk).toList());
    }
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _FakeAdapter adapter}) _dioWith(Map<String, dynamic> bodyJson) {
  final adapter = _FakeAdapter(
    ResponseBody.fromString(
      jsonEncode(bodyJson),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

Map<String, dynamic> _batchJson() => {
      'batch_id': 'batch-1',
      'status': 'DRAFT',
      'files': [],
      'items': [],
    };

void main() {
  const baseUrl = 'http://localhost:3000/api/v1';

  test('creates a certificate import batch with uploaded file metadata',
      () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': _batchJson(),
    });
    final dataSource = CertificateImportRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    );

    final result = await dataSource.createBatch(
      files: const [
        CertificateImportFilePayload(
          url: 'https://cdn.sacdia.app/cert.jpg',
          name: 'cert.jpg',
          type: 'image/jpeg',
        ),
      ],
    );

    expect(result.id, 'batch-1');
    expect(adapter.lastOptions!.method, 'POST');
    expect(adapter.lastOptions!.path, '$baseUrl/certificate-bulk-imports');
    expect(adapter.lastBody, contains('cert.jpg'));
  });

  test('updates an item using the backend snake_case contract', () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': {
        'item_id': 'item-1',
        'item_type': 'HONOR',
        'honor_id': 10,
        'completed_at': '2026-04-12',
        'status': 'READY',
      },
    });
    final dataSource = CertificateImportRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    );

    final item = await dataSource.updateItem(
      batchId: 'batch-1',
      itemId: 'item-1',
      payload: const CertificateImportItemUpdatePayload(
        itemType: 'HONOR',
        honorId: 10,
        completedAt: '2026-04-12',
        markAsReady: true,
      ),
    );

    expect(item.id, 'item-1');
    expect(adapter.lastOptions!.method, 'PATCH');
    expect(
      adapter.lastOptions!.path,
      '$baseUrl/certificate-bulk-imports/batch-1/items/item-1',
    );
    expect(adapter.lastBody, contains('"item_type":"HONOR"'));
    expect(adapter.lastBody, contains('"mark_as_ready":true'));
  });
}
