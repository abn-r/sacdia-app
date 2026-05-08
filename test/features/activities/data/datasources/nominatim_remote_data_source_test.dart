import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/activities/data/datasources/nominatim_remote_data_source.dart';

class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? capturedOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedOptions = options;
    return ResponseBody.fromString(
      jsonEncode([
        {
          'lat': '19.4326',
          'lon': '-99.1332',
          'display_name': 'Centro Histórico, Ciudad de México, México',
        }
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('search maps Nominatim response and preserves query parameters',
      () async {
    final adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://nominatim.openstreetmap.org'))
      ..httpClientAdapter = adapter;
    final dataSource = NominatimRemoteDataSourceImpl(dio: dio);

    final results = await dataSource.search('CDMX');

    expect(results, hasLength(1));
    expect(results.first.lat, 19.4326);
    expect(results.first.lon, -99.1332);
    expect(results.first.displayName, contains('Ciudad de México'));
    expect(adapter.capturedOptions?.path, '/search');
    expect(adapter.capturedOptions?.queryParameters['q'], 'CDMX');
    expect(adapter.capturedOptions?.queryParameters['limit'], 5);
  });
}
