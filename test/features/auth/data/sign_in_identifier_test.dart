import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sacdia_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/presentation/login_error_messages.dart';

import '../../family/family_test_harness.dart';

class _MemorySecureStorage implements SecureStorage {
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

class _NoSocialAuthClient implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

/// Responde un JSON fijo con cabeceras opcionales (para `Retry-After`).
class _HeaderAdapter implements HttpClientAdapter {
  _HeaderAdapter(this.status, this.body, {this.headers = const {}});

  final int status;
  final Object body;
  final Map<String, List<String>> headers;
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
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DropAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async =>
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _loginOk({String? email, Map<String, dynamic>? user}) => {
      'status': 'success',
      'data': {
        'accessToken': 'jwt',
        'refreshToken': 'refresh',
        'expiresAt': 1900000000,
        'tokenType': 'bearer',
        'user': {
          'id': 'teen-1',
          'name': 'Ana',
          'email': email,
          'principal': {'kind': 'supervised_user', 'supervision': 'active'},
          ...?user,
        },
      },
    };

AuthRemoteDataSourceImpl _dataSource(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
    ..httpClientAdapter = adapter;
  return AuthRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'http://localhost:3000',
    secureStorage: _MemorySecureStorage(),
    socialAuth: _NoSocialAuthClient(),
  );
}

Map<String, dynamic> _error(String code, int status) => {
      'status': 'error',
      'statusCode': status,
      'code': code,
      'message': 'RAW SERVER TEXT',
      // `details` NUNCA se lee: este valor no debe llegar a ningún sitio.
      'details': {'retry_after_seconds': 999, 'secret': 'leak'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  group('wire format', () {
    test('a handle travels as `identifier`, unvalidated and trimmed', () async {
      final adapter = _HeaderAdapter(200, _loginOk());

      await _dataSource(adapter).signInWithIdentifier(
        identifier: '  ana-7kq4m9 ',
        password: 'Password123',
      );

      expect(adapter.lastRequest?.uri.path, endsWith('/auth/login'));
      expect(adapter.lastRequest?.data, {
        'identifier': 'ana-7kq4m9',
        'password': 'Password123',
      });
    });

    test('an email travels as the legacy `email` field', () async {
      final adapter = _HeaderAdapter(200, _loginOk(email: 'ana@example.com'));

      await _dataSource(adapter).signInWithIdentifier(
        identifier: 'ana@example.com',
        password: 'Password123',
      );

      expect(adapter.lastRequest?.data, {
        'email': 'ana@example.com',
        'password': 'Password123',
      });
    });

    test('a handle login never turns the handle into the account email',
        () async {
      final user = await _dataSource(_HeaderAdapter(200, _loginOk()))
          .signInWithIdentifier(
        identifier: 'ana-7kq4m9',
        password: 'Password123',
      );

      expect(user.email, isNull);
      expect(user.id, 'teen-1');
    });

    test(
        'an email login falls back to the typed email when the server omits it',
        () async {
      final user = await _dataSource(_HeaderAdapter(200, _loginOk()))
          .signInWithIdentifier(
        identifier: 'ana@example.com',
        password: 'Password123',
      );

      expect(user.email, 'ana@example.com');
    });

    test('data.user.principal is parsed from the login payload', () async {
      final user = await _dataSource(_HeaderAdapter(200, _loginOk()))
          .signInWithIdentifier(identifier: 'x@y.com', password: 'Password123');

      expect(user.principal!.kind, PrincipalKind.supervisedUser);
      expect(user.mode, AccountMode.teenSupervised);
      // El login no trae el campo de analítica: la analítica queda anónima.
      expect(user.canIdentifyInAnalytics, isFalse);
    });
  });

  group('errors keep the business code and nothing else', () {
    Future<AuthException> failWith(
      int status,
      String code, {
      Map<String, List<String>> headers = const {},
    }) async {
      final adapter =
          _HeaderAdapter(status, _error(code, status), headers: headers);
      try {
        await _dataSource(adapter).signInWithIdentifier(
          identifier: 'ana-7kq4m9',
          password: 'bad',
        );
      } on AuthException catch (e) {
        return e;
      }
      fail('expected an AuthException');
    }

    test('401 uniform credentials', () async {
      final e = await failWith(401, 'AUTH_INVALID_CREDENTIALS');
      expect(e.code, 401);
      expect(e.errorCode, 'AUTH_INVALID_CREDENTIALS');
      expect(e.retryAfterSeconds, isNull);
    });

    test('403 disabled and frozen', () async {
      expect(
        (await failWith(403, 'AUTH_SUPERVISED_LOGIN_DISABLED')).errorCode,
        'AUTH_SUPERVISED_LOGIN_DISABLED',
      );
      expect(
        (await failWith(403, 'AUTH_ACCOUNT_FROZEN')).errorCode,
        'AUTH_ACCOUNT_FROZEN',
      );
    });

    test('429 lock reads Retry-After from the header, never from details',
        () async {
      final e = await failWith(
        429,
        'AUTH_LOGIN_LOCKED',
        headers: {
          'retry-after': ['900'],
        },
      );
      expect(e.code, 429);
      expect(e.errorCode, 'AUTH_LOGIN_LOCKED');
      expect(e.retryAfterSeconds, 900);
    });

    test('429 without a usable Retry-After has no seconds', () async {
      expect(
          (await failWith(429, 'AUTH_LOGIN_LOCKED')).retryAfterSeconds, isNull);
      expect(
        (await failWith(
          429,
          'AUTH_LOGIN_LOCKED',
          headers: {
            'retry-after': ['soon'],
          },
        ))
            .retryAfterSeconds,
        isNull,
      );
    });

    test('no response is a connection error, not bad credentials', () async {
      await expectLater(
        _dataSource(_DropAdapter())
            .signInWithIdentifier(identifier: 'x@y.com', password: 'pw'),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('repository', () {
    AuthRepositoryImpl repo(HttpClientAdapter a) => AuthRepositoryImpl(
          remoteDataSource: _dataSource(a),
          networkInfo: _Online(),
        );

    test('keeps errorCode and Retry-After on the AuthFailure', () async {
      final result = await repo(_HeaderAdapter(
        429,
        _error('AUTH_LOGIN_LOCKED', 429),
        headers: {
          'retry-after': ['120'],
        },
      )).signInWithIdentifier(identifier: 'ana-7kq4m9', password: 'x');

      final failure = result.fold((f) => f, (_) => null) as AuthFailure;
      expect(failure.errorCode, 'AUTH_LOGIN_LOCKED');
      expect(failure.code, 429);
      expect(failure.retryAfterSeconds, 120);
    });

    test('maps a dropped connection to NetworkFailure', () async {
      final result = await repo(_DropAdapter())
          .signInWithIdentifier(identifier: 'x@y.com', password: 'x');

      expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  group('loginErrorMessage', () {
    Future<List<String>> messages(
      WidgetTester tester,
      List<Failure> failures,
    ) async {
      final out = <String>[];
      await pumpFamilyApp(
        tester,
        overrides: const [],
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) {
              out
                ..clear()
                ..addAll(failures.map(loginErrorMessage));
              return const SizedBox();
            },
          ),
        ],
      );
      return out;
    }

    testWidgets('each business code has its own friendly message',
        (tester) async {
      final out = await messages(tester, const [
        AuthFailure(
          message: 'RAW',
          code: 401,
          errorCode: 'AUTH_INVALID_CREDENTIALS',
        ),
        AuthFailure(
          message: 'RAW',
          code: 403,
          errorCode: 'AUTH_SUPERVISED_LOGIN_DISABLED',
        ),
        AuthFailure(
          message: 'RAW',
          code: 403,
          errorCode: 'AUTH_ACCOUNT_FROZEN',
        ),
        AuthFailure(
          message: 'RAW',
          code: 429,
          errorCode: 'AUTH_LOGIN_LOCKED',
        ),
        AuthFailure(
          message: 'RAW',
          code: 429,
          errorCode: 'AUTH_LOGIN_LOCKED',
          retryAfterSeconds: 900,
        ),
        AuthFailure(message: 'RAW', code: 401),
        NetworkFailure(message: 'RAW'),
        ServerFailure(message: 'RAW', code: 500),
      ]);

      expect(out[0], contains('incorrectos'));
      expect(out[1], contains('desactivó este acceso'));
      expect(out[2], contains('no tenía un tutor vinculado'));
      expect(out[3], 'Demasiados intentos. Inténtalo de nuevo más tarde.');
      expect(out[4], contains('15 min'));
      // Un 401 sin código (backend anterior) también es "credenciales".
      expect(out[5], out[0]);
      expect(out[6], 'Error de conexión. Compruebe su red.');
      expect(out[7], 'Error al iniciar sesión');
      for (final message in out) {
        expect(message, isNot(contains('RAW')));
        expect(message, isNot(contains('Exception')));
      }
    });
  });
}
