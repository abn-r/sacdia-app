import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';

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

  test('creates a certificate import draft without local path file_url',
      () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': _batchJson(),
    });
    final dataSource = CertificateImportRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    );

    final result = await dataSource.createBatch(files: const []);

    expect(result.id, 'batch-1');
    expect(adapter.lastOptions!.method, 'POST');
    expect(adapter.lastOptions!.path, '$baseUrl/certificate-bulk-imports');
    expect(adapter.lastBody, contains('"files":[]'));
    expect(adapter.lastBody, isNot(contains('file_url')));
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

  test('lists the classes of a club type from the import catalog', () async {
    final (:dio, :adapter) = _dioWith({
      'status': 'success',
      'data': [
        {
          'class_id': 3,
          'name': 'Explorador',
          'asset_code': 'CQ-02',
          'club_type_id': 1,
          'institutional': false,
        },
        {
          'class_id': 9,
          'name': 'Guía Mayor Instructor',
          'asset_code': 'GM-03',
          'club_type_id': 3,
          'institutional': true,
        },
        {'class_id': null, 'name': 'sin id'},
        'not a map',
      ],
    });
    final dataSource = CertificateImportRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    );

    final classes = await dataSource.getClassCatalog(clubTypeId: 1);

    expect(adapter.lastOptions!.method, 'GET');
    expect(adapter.lastOptions!.path,
        '$baseUrl/certificate-bulk-imports/catalog/classes');
    expect(adapter.lastOptions!.queryParameters, {'clubTypeId': 1});
    expect(classes.map((c) => c.id), [3, 9]);
    expect(classes.first.assetCode, 'CQ-02');
    expect(classes.last.institutional, isTrue);
  });

  group('item payload', () {
    test('a class sends class_id and club_type_id, never honor_id', () {
      final json = const CertificateImportItemUpdatePayload(
        itemType: 'CLASS',
        classId: 3,
        clubTypeId: 1,
        completedAt: '2022-11-20',
        markAsReady: true,
      ).toJson();
      expect(json['class_id'], 3);
      expect(json['club_type_id'], 1);
      expect(json.containsKey('honor_id'), isFalse);
    });

    test('a honor sends honor_id only, with no catalog trash', () {
      final json = const CertificateImportItemUpdatePayload(
        itemType: 'HONOR',
        honorId: 10,
        completedAt: '2023-03-12',
      ).toJson();
      expect(json['honor_id'], 10);
      expect(json.containsKey('class_id'), isFalse);
      expect(json.containsKey('club_type_id'), isFalse);
    });

    test('club_type_id is dropped when there is no class', () {
      final json = const CertificateImportItemUpdatePayload(
        itemType: 'CLASS',
        clubTypeId: 1,
      ).toJson();
      expect(json.containsKey('club_type_id'), isFalse);
    });
  });
}
