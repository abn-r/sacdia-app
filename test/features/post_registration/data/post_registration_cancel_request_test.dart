import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/post_registration_remote_data_source.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({'success': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'cancelPendingMembershipRequest posts to the user post-registration endpoint',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    final dataSource = PostRegistrationRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000/api/v1',
    );

    await dataSource.cancelPendingMembershipRequest(userId: 'user-1');

    expect(adapter.lastRequest?.method, 'POST');
    expect(
      adapter.lastRequest?.path,
      'http://localhost:3000/api/v1/users/user-1/post-registration/membership-request/cancel',
    );
  });
}
