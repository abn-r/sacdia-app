import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage implements SecureStorage {
  final _store = <String, String>{};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_store);
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.endsWith('/auth/me') && options.method == 'GET') {
      return _jsonResponse(
        200,
        {
          'data': {
            'user_id': 'user-1',
            'email': 'elena@example.com',
            'name': 'Elena',
            'authorization': {
              'effective': {
                'permissions': ['users:read_detail', 'classes:read'],
              },
              'grants': {
                'global_roles': [],
                'club_assignments': [
                  {
                    'assignment_id': 'assignment-pending',
                    'role_name': 'member',
                    'permissions': ['users:read_detail', 'classes:read'],
                    'status': 'pending',
                    'section': {'club_section_id': 30},
                  }
                ],
              },
              'active_assignment': null,
            },
          },
          'post_register_complete': true,
        },
      );
    }

    if (options.path.endsWith('/auth/me/context') &&
        options.method == 'PATCH') {
      return _jsonResponse(200, {'success': true});
    }

    return _jsonResponse(404, {'message': 'unexpected ${options.path}'});
  }

  ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
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

void main() {
  test('does not auto-activate a pending-only membership request', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeSecureStorage();
    await storage.write(AppConstants.tokenKey, 'jwt');
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;

    final dataSource = AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000/api/v1',
      secureStorage: storage,
    );

    final user = await dataSource.getCurrentUser();

    expect(user?.authorization?.clubAssignments.single.isPending, isTrue);
    expect(user?.authorization?.activeAssignmentId, isNull);
    expect(
      adapter.requests.where(
        (request) =>
            request.method == 'PATCH' &&
            request.path.endsWith('/auth/me/context'),
      ),
      isEmpty,
    );
  });
}
