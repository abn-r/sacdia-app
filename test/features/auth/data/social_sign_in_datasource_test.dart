import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';

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

class _FakeSocialAuthClient implements SocialAuthClient {
  _FakeSocialAuthClient(this.result);

  final SocialCredential? result;
  SocialProvider? requested;

  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async {
    requested = provider;
    return result;
  }

  @override
  bool supports(SocialProvider provider) => true;
}

/// Adaptador Dio que responde JSON (anidado) con un status fijo.
class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    lastRequest = options;
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

const _credential = SocialCredential(
  provider: SocialProvider.apple,
  idToken: 'apple-id-token',
  nonce: 'nonce-1',
  authorizationCode: 'code-1',
  givenName: 'Ana',
  familyName: 'Pérez',
);

const _successBody = {
  'status': 'success',
  'data': {
    'accessToken': 'sacdia-jwt',
    'sessionToken': 'opaque',
    'refreshToken': 'opaque',
    'expiresAt': 1900000000,
    'tokenType': 'bearer',
    'user': {
      'id': 'user-1',
      'email': 'ana@example.com',
      'name': 'Ana',
      'paternal_last_name': 'Pérez',
      'maternal_last_name': null,
      'avatar': 'https://r2.example/u1.jpg',
      'connectedProviders': ['apple'],
    },
    'needsPostRegistration': true,
  },
};

class _ThrowingSocialAuthClient implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async =>
      throw SocialAuthException(provider, 'sdk exploded');
  @override
  bool supports(SocialProvider provider) => true;
}

void main() {
  late _FakeSecureStorage storage;
  late Dio dio;

  AuthRemoteDataSourceImpl build(SocialAuthClient social) =>
      AuthRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000',
        secureStorage: storage,
        socialAuth: social,
      );

  setUp(() {
    storage = _FakeSecureStorage();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  });

  test(
    'posts the credential to /auth/oauth/apple/token and persists the session',
    () async {
      final adapter = _JsonAdapter(201, _successBody);
      dio.httpClientAdapter = adapter;
      final social = _FakeSocialAuthClient(_credential);

      final user = await build(social).signInWithApple();

      expect(social.requested, SocialProvider.apple);
      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.uri.path, '/auth/oauth/apple/token');
      expect(adapter.lastRequest?.data, {
        'idToken': 'apple-id-token',
        'nonce': 'nonce-1',
        'authorizationCode': 'code-1',
        'fullName': {'givenName': 'Ana', 'familyName': 'Pérez'},
      });
      expect(user.id, 'user-1');
      expect(user.email, 'ana@example.com');
      expect(user.avatar, 'https://r2.example/u1.jpg');
      expect(user.postRegisterComplete, isFalse);
      expect(await storage.read(AppConstants.tokenKey), 'sacdia-jwt');
      expect(await storage.read(AppConstants.refreshTokenKey), 'opaque');
      expect(await storage.read(AppConstants.expiresAtKey), '1900000000');
      expect(await storage.read(AppConstants.tokenTypeKey), 'bearer');
    },
  );

  test('uses the google route for Google', () async {
    final adapter = _JsonAdapter(201, _successBody);
    dio.httpClientAdapter = adapter;
    const google = SocialCredential(
      provider: SocialProvider.google,
      idToken: 'g-token',
      nonce: 'n',
    );

    await build(_FakeSocialAuthClient(google)).signInWithGoogle();

    expect(adapter.lastRequest?.uri.path, '/auth/oauth/google/token');
    expect(adapter.lastRequest?.data, {'idToken': 'g-token', 'nonce': 'n'});
  });

  test(
    'throws SocialSignInCancelledException and makes no request on cancel',
    () async {
      final adapter = _JsonAdapter(201, _successBody);
      dio.httpClientAdapter = adapter;

      await expectLater(
        build(_FakeSocialAuthClient(null)).signInWithGoogle(),
        throwsA(isA<SocialSignInCancelledException>()),
      );
      expect(adapter.lastRequest, isNull);
      expect(await storage.read(AppConstants.tokenKey), isNull);
    },
  );

  test('maps a 401 to AuthException with the server message', () async {
    dio.httpClientAdapter = _JsonAdapter(401, {
      'status': 'error',
      'statusCode': 401,
      'code': 'AUTH_INVALID_TOKEN',
      'message': 'Token inválido o expirado',
    });

    await expectLater(
      build(_FakeSocialAuthClient(_credential)).signInWithApple(),
      throwsA(
        predicate(
          (e) =>
              e is AuthException &&
              e.message == 'Token inválido o expirado' &&
              e.code == 401,
        ),
      ),
    );
    expect(await storage.read(AppConstants.tokenKey), isNull);
  });

  test('maps an SDK failure to AuthException', () async {
    final failing = _ThrowingSocialAuthClient();
    await expectLater(
      build(failing).signInWithGoogle(),
      throwsA(isA<AuthException>()),
    );
  });
}
