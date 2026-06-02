import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/data/datasources/profile_remote_data_source.dart';

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
      final chunks = await requestStream.toList();
      lastBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    }
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

void main() {
  const baseUrl = 'http://localhost:3000';

  group('ProfileRemoteDataSourceImpl.updateUserProfile', () {
    test('unwraps standard API response data before parsing user detail',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'user_id': '104a2549-2056-4b9b-aaeb-51d8fd43191d',
          'email': 'abner@example.com',
          'name': 'Abner',
          'paternal_last_name': 'Reyes',
          'maternal_last_name': 'Ramírez',
          'gender': 'M',
          'birthday': '1994-03-25T00:00:00.000Z',
          'baptism': true,
          'baptism_date': '2026-03-25T00:00:00.000Z',
        },
        'message': 'Usuario actualizado exitosamente',
      });
      final ds = ProfileRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.updateUserProfile(
        '104a2549-2056-4b9b-aaeb-51d8fd43191d',
        {'name': 'Abner'},
      );

      expect(result.id, '104a2549-2056-4b9b-aaeb-51d8fd43191d');
      expect(result.email, 'abner@example.com');
      expect(result.name, 'Abner');
      expect(adapter.lastOptions?.method, 'PATCH');
    });
  });
}
