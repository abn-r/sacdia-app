import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeSecureStorage implements SecureStorage {
  final _store = <String, String>{};
  final deletedKeys = <String>[];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async {
    deletedKeys.add(key);
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deletedKeys.addAll(_store.keys);
    _store.clear();
  }

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_store);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [MockAdapter] that always returns [statusCode] for any request.
MockAdapter _adapterReturning(int statusCode, [Map<String, dynamic>? body]) {
  return MockAdapter(statusCode: statusCode, body: body);
}

class MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic>? body;

  MockAdapter({required this.statusCode, this.body});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final responseBody = body != null
        ? '${body!.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}'
        : '';
    return ResponseBody.fromString(
      '{$responseBody}',
      statusCode,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeSecureStorage storage;
  late Dio dio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    storage = _FakeSecureStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  });

  group('deleteAccount — H-02 fix: validateStatus = 200|204 only', () {
    test('401 response throws AuthException and does NOT clear token', () async {
      // Seed a token so the call proceeds.
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');

      dio.httpClientAdapter = _adapterReturning(
        401,
        {'message': 'Contraseña incorrecta'},
      );

      dataSource = AuthRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000',
        secureStorage: storage,
      );

      expect(
        () => dataSource.deleteAccount('wrong-password'),
        throwsA(
          predicate(
            (e) => e is AuthException && e.code == 401,
            'AuthException with code 401',
          ),
        ),
      );

      // Token must NOT have been deleted.
      final tokenAfter = await storage.read(AppConstants.tokenKey);
      expect(tokenAfter, 'my-jwt-token');
      expect(
        storage.deletedKeys.contains(AppConstants.tokenKey),
        isFalse,
        reason: 'tokenKey must not be deleted on wrong password',
      );
    });

    test('204 response succeeds and clears token', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');

      dio.httpClientAdapter = _adapterReturning(204);

      dataSource = AuthRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000',
        secureStorage: storage,
      );

      // Should not throw.
      await dataSource.deleteAccount('correct-password');

      // Token must be cleared after successful deletion.
      final tokenAfter = await storage.read(AppConstants.tokenKey);
      expect(tokenAfter, isNull);
    });
  });
}
