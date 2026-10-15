import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';

import '../../../support/http_adapters.dart';

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

class _NoSocialAuth implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [MockAdapter] that always returns [statusCode] for any request.
MockAdapter _adapterReturning(int statusCode, [Map<String, dynamic>? body]) {
  return MockAdapter(statusCode: statusCode, body: body);
}

class MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic>? body;
  RequestOptions? lastRequest;

  MockAdapter({required this.statusCode, this.body});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final responseBody = body != null
        ? body!.entries.map((e) => '"${e.key}":"${e.value}"').join(',')
        : '';
    return ResponseBody.fromString(
      '{$responseBody}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _googleReauth = SocialReauth(
  SocialCredential(
    provider: SocialProvider.google,
    idToken: 'g-token',
    nonce: 'n-1',
  ),
);

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
    test('401 response throws AuthException and does NOT clear token',
        () async {
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
        socialAuth: _NoSocialAuth(),
      );

      expect(
        () => dataSource.deleteAccount(const PasswordReauth('wrong-password')),
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
        socialAuth: _NoSocialAuth(),
      );

      // Should not throw.
      await dataSource.deleteAccount(const PasswordReauth('correct-password'));

      // Token must be cleared after successful deletion.
      final tokenAfter = await storage.read(AppConstants.tokenKey);
      expect(tokenAfter, isNull);
    });
  });

  group('deleteAccount — re-auth body', () {
    AuthRemoteDataSourceImpl build() => AuthRemoteDataSourceImpl(
          dio: dio,
          baseUrl: 'http://localhost:3000',
          secureStorage: storage,
          socialAuth: _NoSocialAuth(),
        );

    test('sends only the password for a password re-auth', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      final adapter = _adapterReturning(204);
      dio.httpClientAdapter = adapter;

      await build().deleteAccount(const PasswordReauth('correct-password'));

      expect(adapter.lastRequest?.method, 'DELETE');
      expect(adapter.lastRequest?.data, {'password': 'correct-password'});
    });

    test('sends provider, idToken and nonce for a social re-auth', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      final adapter = _adapterReturning(204);
      dio.httpClientAdapter = adapter;

      await build().deleteAccount(_googleReauth);

      expect(adapter.lastRequest?.method, 'DELETE');
      expect(adapter.lastRequest?.uri.path, '/auth/me');
      expect(adapter.lastRequest?.data, {
        'provider': 'google',
        'idToken': 'g-token',
        'nonce': 'n-1',
      });
      expect(await storage.read(AppConstants.tokenKey), isNull);
    });
  });

  group('deleteAccount — error mapping by code and status', () {
    setUp(() async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
    });

    AuthRemoteDataSourceImpl build() => AuthRemoteDataSourceImpl(
          dio: dio,
          baseUrl: 'http://localhost:3000',
          secureStorage: storage,
          socialAuth: _NoSocialAuth(),
        );

    Map<String, dynamic> errorBody(int status, String code) => {
          'status': 'error',
          'statusCode': status,
          'code': code,
          'message': 'texto crudo del backend',
        };

    Future<void> expectMapped(
      DeleteAccountReauth reauth, {
      required String message,
      int? code,
    }) async {
      await expectLater(
        build().deleteAccount(reauth),
        throwsA(
          predicate(
            (e) => e is AuthException && e.message == message && e.code == code,
            'AuthException($message, $code)',
          ),
        ),
      );
      // Los tokens solo se limpian con un 204.
      expect(await storage.read(AppConstants.tokenKey), 'my-jwt-token');
      expect(storage.deletedKeys.contains(AppConstants.tokenKey), isFalse);
    }

    test('AUTH_INVALID_PASSWORD maps to wrong_password', () async {
      dio.httpClientAdapter =
          JsonAdapter(401, errorBody(401, 'AUTH_INVALID_PASSWORD'));

      await expectMapped(
        const PasswordReauth('nope'),
        message: 'errors.wrong_password',
        code: 401,
      );
    });

    test('AUTH_INVALID_TOKEN on a social re-auth maps to social_reauth_failed',
        () async {
      dio.httpClientAdapter =
          JsonAdapter(401, errorBody(401, 'AUTH_INVALID_TOKEN'));

      await expectMapped(
        _googleReauth,
        message: 'errors.delete_account_social_reauth_failed',
        code: 401,
      );
    });

    test('AUTH_INVALID_TOKEN on a password re-auth maps to wrong_password',
        () async {
      dio.httpClientAdapter =
          JsonAdapter(401, errorBody(401, 'AUTH_INVALID_TOKEN'));

      await expectMapped(
        const PasswordReauth('nope'),
        message: 'errors.wrong_password',
        code: 401,
      );
    });

    test('a 429 maps to too_many_attempts', () async {
      dio.httpClientAdapter = JsonAdapter(429, {
        'statusCode': 429,
        'message': 'ThrottlerException: Too Many Requests',
      });

      await expectMapped(
        _googleReauth,
        message: 'errors.too_many_attempts',
        code: 429,
      );
    });

    test('AUTH_OAUTH_PROVIDER_UNAVAILABLE maps to provider_unavailable',
        () async {
      dio.httpClientAdapter =
          JsonAdapter(503, errorBody(503, 'AUTH_OAUTH_PROVIDER_UNAVAILABLE'));

      await expectMapped(
        _googleReauth,
        message: 'errors.social_signin_provider_unavailable',
        code: 503,
      );
    });

    test('a masked 5xx on a social re-auth maps to provider_unavailable',
        () async {
      dio.httpClientAdapter = JsonAdapter(500, {'message': 'Internal error'});

      await expectMapped(
        _googleReauth,
        message: 'errors.social_signin_provider_unavailable',
        code: 500,
      );
    });

    test('a 5xx on a password re-auth maps to the generic delete error',
        () async {
      dio.httpClientAdapter = JsonAdapter(500, {'message': 'Internal error'});

      await expectMapped(
        const PasswordReauth('pw'),
        message: 'errors.delete_account',
        code: 500,
      );
    });

    test('AUTH_ACCOUNT_NOT_FOUND maps to the generic delete error', () async {
      dio.httpClientAdapter =
          JsonAdapter(404, errorBody(404, 'AUTH_ACCOUNT_NOT_FOUND'));

      await expectMapped(
        const PasswordReauth('pw'),
        message: 'errors.delete_account',
        code: 404,
      );
    });

    test('a non-string code in the body does not crash the mapping', () async {
      dio.httpClientAdapter = JsonAdapter(400, {'code': 123, 'message': 'x'});

      await expectMapped(
        const PasswordReauth('pw'),
        message: 'errors.delete_account',
        code: 400,
      );
    });

    test('uses the interceptor message when there is no response', () async {
      dio.httpClientAdapter = ErrorAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          error: ConnectionException(message: 'Tiempo agotado'),
        ),
      );

      await expectMapped(_googleReauth, message: 'Tiempo agotado');
    });

    test('falls back to common.error_network on a bare connection error',
        () async {
      dio.httpClientAdapter = ErrorAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectMapped(
        const PasswordReauth('pw'),
        message: 'common.error_network',
      );
    });
  });

  group('getConnectedProviders', () {
    AuthRemoteDataSourceImpl build() => AuthRemoteDataSourceImpl(
          dio: dio,
          baseUrl: 'http://localhost:3000',
          secureStorage: storage,
          socialAuth: _NoSocialAuth(),
        );

    test('returns the provider list from GET /auth/oauth/providers', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      final adapter = JsonAdapter(200, ['google', 'apple']);
      dio.httpClientAdapter = adapter;

      expect(
        await build().getConnectedProviders(),
        [SocialProvider.google, SocialProvider.apple],
      );
      expect(adapter.lastRequest?.method, 'GET');
      expect(adapter.lastRequest?.uri.path, '/auth/oauth/providers');
    });

    test('ignores unknown provider names', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      dio.httpClientAdapter = JsonAdapter(200, ['apple', 'github']);

      expect(await build().getConnectedProviders(), [SocialProvider.apple]);
    });

    test('also accepts the list wrapped in {status, data}', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      dio.httpClientAdapter = JsonAdapter(200, {
        'status': 'success',
        'data': ['google'],
      });

      expect(await build().getConnectedProviders(), [SocialProvider.google]);
    });

    test('returns an empty list for an unexpected body', () async {
      await storage.write(AppConstants.tokenKey, 'my-jwt-token');
      dio.httpClientAdapter = JsonAdapter(200, {'status': 'success'});

      expect(await build().getConnectedProviders(), isEmpty);
    });
  });

  group('AuthRemoteDataSourceImpl.resetPassword', () {
    test('should use the canonical password reset request endpoint', () async {
      final adapter = _adapterReturning(200);
      dio.httpClientAdapter = adapter;
      dataSource = AuthRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000',
        secureStorage: storage,
        socialAuth: _NoSocialAuth(),
      );

      await dataSource.resetPassword('admin@example.com');

      expect(
        adapter.lastRequest?.uri.path,
        '/auth/password/reset-request',
      );
      expect(adapter.lastRequest?.data, {'email': 'admin@example.com'});
    });
  });
}
