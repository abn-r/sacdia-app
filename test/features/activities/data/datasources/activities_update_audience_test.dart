import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/activities/data/datasources/activities_remote_data_source.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({
        'activity_id': 7,
        'name': 'Campamento',
        'activity_place': 'Parque',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late ActivitiesRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _CapturingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dataSource =
        ActivitiesRemoteDataSourceImpl(dio: dio, baseUrl: 'http://test');
  });

  test('sends audience with its classes on update', () async {
    await dataSource.updateActivity(
      activityId: 7,
      audience: 'classes',
      classes: const [3, 4],
    );

    final body = adapter.lastOptions!.data as Map<String, dynamic>;
    expect(body['audience'], 'classes');
    expect(body['classes'], [3, 4]);
  });

  test('audience other than classes omits the class list', () async {
    await dataSource.updateActivity(activityId: 7, audience: 'board');

    final body = adapter.lastOptions!.data as Map<String, dynamic>;
    expect(body['audience'], 'board');
    expect(body.containsKey('classes'), isFalse);
  });

  test('omits audience when unchanged', () async {
    await dataSource.updateActivity(activityId: 7, name: 'Retiro');

    final body = adapter.lastOptions!.data as Map<String, dynamic>;
    expect(body.containsKey('audience'), isFalse);
  });
}
