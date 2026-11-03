import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_scan_provider.dart';

import '../../support/riverpod_test_support.dart';

/// Responds after a moment, like a real network call.
class _SlowAdapter implements HttpClientAdapter {
  _SlowAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(int statusCode, Map<String, dynamic> body) =>
    Dio()..httpClientAdapter = _SlowAdapter(statusCode, body);

void main() {
  // The scanner only `ref.read` this notifier, so nothing listens to it. An
  // autoDispose provider is then disposed while the request is in flight, and
  // writing `state` after the await threw.
  test('submit completes when nothing listens to the notifier', () async {
    final container = createTestContainer(overrides: [
      qrScanDioProvider.overrideWithValue(_dio(200, {
        'valid': true,
        'member': {'user_id': 'u1', 'full_name': 'Ana Lopez'},
        'scanned_at': '2026-11-03T10:00:00Z',
      })),
    ]);

    await container
        .read(qrScanProvider.notifier)
        .submit(token: 'tok', activityId: 7);

    final state = container.read(qrScanProvider);
    expect(state.error, isNull);
    expect(state.value?.member.userId, 'u1');
  });

  test('a rejected scan ends in an error state instead of throwing', () async {
    final container = createTestContainer(overrides: [
      qrScanDioProvider
          .overrideWithValue(_dio(400, {'message': 'Token vencido'})),
    ]);

    await container.read(qrScanProvider.notifier).submit(token: 'tok');

    final state = container.read(qrScanProvider);
    expect(state.error, isNotNull);
  });
}
