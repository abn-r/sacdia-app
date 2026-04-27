import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/qr/data/datasources/qr_remote_data_source.dart';
import 'package:sacdia_app/features/qr/data/models/qr_scan_result_model.dart';

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

Map<String, dynamic> _validateResponseJson({
  bool includeAttendance = true,
}) {
  return {
    'valid': true,
    'member': {
      'user_id': 'user-123',
      'full_name': 'Ana Lopez',
      'avatar': null,
      'club_name': 'Club Orion',
      'section_name': 'Unidad Pioneros',
    },
    if (includeAttendance)
      'attendance': {
        'registered': true,
        'already_present': false,
        'activity_id': 88,
      },
    'scanned_at': '2026-04-23T18:42:00.000Z',
  };
}

void main() {
  const baseUrl = 'http://localhost:3000';

  test('validateToken posts to /qr/validate with canonical payload', () async {
    final (:dio, :adapter) = _dioWith(_validateResponseJson());
    final ds = QrRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

    final result = await ds.validateToken(token: 'qr-token', activityId: 88);

    expect(result, isA<QrScanResultModel>());
    expect(adapter.lastOptions!.path, '$baseUrl/qr/validate');
    expect(adapter.lastOptions!.method, 'POST');
    expect(adapter.lastOptions!.data, {
      'token': 'qr-token',
      'activity_id': 88,
    });
  });

  test('scanToken keeps legacy compatibility but still hits /qr/validate',
      () async {
    final (:dio, :adapter) = _dioWith(_validateResponseJson());
    final ds = QrRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

    await ds.scanToken(token: 'legacy-token');

    expect(adapter.lastOptions!.path, '$baseUrl/qr/validate');
    expect(adapter.lastOptions!.data, {
      'token': 'legacy-token',
    });
  });
}
