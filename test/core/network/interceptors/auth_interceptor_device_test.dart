import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';

import '../../../support/http_adapters.dart';

/// Un teléfono vinculado pierde su sesión de tres maneras (FP3-52): 401
/// `AUTH_DEVICE_REVOKED`, 401 `AUTH_DEVICE_SESSION_EXPIRED` o un refresh
/// muerto. En los tres vuelve a la pantalla de vinculación, no al login, y
/// nunca manda `X-Acting-For`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int expiredCalls;
  late List<bool> unpaired;
  late List<RequestOptions> seen;
  late Dio dio;
  late ActingForSession acting;

  Future<void> setUpWith(
    Map<String, ResponseSpec> routes, {
    bool device = true,
    bool withRefreshToken = true,
    bool withDeviceCallback = true,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'device-access',
      if (withRefreshToken) AppConstants.refreshTokenKey: 'device-refresh',
    });
    expiredCalls = 0;
    unpaired = [];
    seen = [];
    acting = ActingForSession();
    final adapter = _RoutedAdapter(routes, seen);
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshAdapter: adapter,
        actingForSession: acting,
        onAuthExpired: () => expiredCalls++,
        onDeviceUnpaired: withDeviceCallback ? unpaired.add : null,
        isDeviceSession: () => device,
      ),
    );
  }

  Future<DioException> getClasses() async {
    try {
      await dio.get('/users/kid-1/classes');
    } on DioException catch (e) {
      return e;
    }
    fail('expected a DioException');
  }

  Map<String, dynamic> body(String? code) => {
        'status': 'error',
        'statusCode': 401,
        if (code != null) 'code': code,
        'message': 'x',
        'details': {'ignored': true},
      };

  Future<void> expectTokensCleared() async {
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: AppConstants.tokenKey), isNull);
    expect(await storage.read(key: AppConstants.refreshTokenKey), isNull);
  }

  group('explicit device codes', () {
    test('AUTH_DEVICE_REVOKED clears tokens and unpairs without refreshing',
        () async {
      await setUpWith({
        '/users/kid-1/classes': ResponseSpec(401, body('AUTH_DEVICE_REVOKED')),
      });

      final error = await getClasses();

      expect(error.response?.statusCode, 401);
      expect(unpaired, [false]);
      expect(expiredCalls, 0, reason: 'no account logout');
      expect(seen.map((r) => r.path), ['/users/kid-1/classes'],
          reason: 'never tried /auth/refresh');
      await expectTokensCleared();
    });

    test('AUTH_DEVICE_SESSION_EXPIRED unpairs and flags the expiry', () async {
      await setUpWith({
        '/users/kid-1/classes':
            ResponseSpec(401, body('AUTH_DEVICE_SESSION_EXPIRED')),
      });

      await getClasses();

      expect(unpaired, [true]);
      expect(expiredCalls, 0);
      await expectTokensCleared();
    });

    test('the device code unpairs even if the in-memory mode was not set',
        () async {
      await setUpWith({
        '/users/kid-1/classes': ResponseSpec(401, body('AUTH_DEVICE_REVOKED')),
      }, device: false);

      await getClasses();

      expect(unpaired, [false]);
    });

    test('without a device callback it falls back to the expired session',
        () async {
      await setUpWith({
        '/users/kid-1/classes': ResponseSpec(401, body('AUTH_DEVICE_REVOKED')),
      }, withDeviceCallback: false);

      await getClasses();

      expect(expiredCalls, 1);
      expect(unpaired, isEmpty);
    });
  });

  group('dead refresh', () {
    test('in device mode it goes back to pairing, not to the login', () async {
      await setUpWith({
        '/users/kid-1/classes':
            ResponseSpec(401, body('GUARD_JWT_UNAUTHORIZED')),
        '/auth/refresh': ResponseSpec(401, body('AUTH_REFRESH_TOKEN_INVALID')),
      });

      await getClasses();

      expect(unpaired, [false]);
      expect(expiredCalls, 0);
      await expectTokensCleared();
    });

    test('a refresh refused for the absolute cap flags the expiry', () async {
      await setUpWith({
        '/users/kid-1/classes':
            ResponseSpec(401, body('GUARD_JWT_UNAUTHORIZED')),
        '/auth/refresh': ResponseSpec(401, body('AUTH_DEVICE_SESSION_EXPIRED')),
      });

      await getClasses();

      expect(unpaired, [true]);
      expect(expiredCalls, 0);
    });

    test('a revoked device refresh (no refresh token) unpairs too', () async {
      await setUpWith({
        '/users/kid-1/classes':
            ResponseSpec(401, body('GUARD_JWT_UNAUTHORIZED')),
      }, withRefreshToken: false);

      await getClasses();

      expect(unpaired, [false]);
      expect(expiredCalls, 0);
    });

    test('an ACCOUNT session with a dead refresh still logs out normally',
        () async {
      await setUpWith({
        '/users/kid-1/classes':
            ResponseSpec(401, body('GUARD_JWT_UNAUTHORIZED')),
        '/auth/refresh': ResponseSpec(401, body('AUTH_REFRESH_TOKEN_INVALID')),
      }, device: false);

      await getClasses();

      expect(expiredCalls, 1);
      expect(unpaired, isEmpty);
    });
  });

  group('device never acts for anyone', () {
    test('X-Acting-For is never sent, even with an acting session', () async {
      await setUpWith({
        '/users/kid-1/classes': ResponseSpec(200, {'data': []}),
      });
      acting.enter(const ActingDependent(userId: 'someone-else'));

      await dio.get('/users/kid-1/classes');

      expect(seen.single.headers.containsKey('X-Acting-For'), isFalse);
      expect(seen.single.headers['Authorization'], 'Bearer device-access');
    });

    test('an account session still sends it', () async {
      await setUpWith({
        '/users/ana-1/classes': ResponseSpec(200, {'data': []}),
      }, device: false);
      acting.enter(const ActingDependent(userId: 'ana-1'));

      await dio.get('/users/ana-1/classes');

      expect(seen.single.headers['X-Acting-For'], 'ana-1');
    });
  });

  test('the pairing endpoint is public: its 401 is not a session event',
      () async {
    await setUpWith({
      '/auth/device/pair': ResponseSpec(401, body('AUTH_DEVICE_REVOKED')),
    });

    try {
      await dio.post('/auth/device/pair', data: {'pairing_token': 'x'});
    } on DioException {
      // esperado
    }

    expect(unpaired, isEmpty);
    expect(expiredCalls, 0);
    expect(seen.length, 1, reason: 'no refresh attempt');
  });
}

class ResponseSpec {
  const ResponseSpec(this.status, this.body);
  final int status;
  final Object body;
}

/// Responde por ruta y registra las peticiones. Sirve también como adaptador
/// del refresh.
class _RoutedAdapter extends JsonAdapter {
  _RoutedAdapter(this.routes, this.seen) : super(200, const {});

  final Map<String, ResponseSpec> routes;
  final List<RequestOptions> seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    seen.add(options);
    final spec = routes[options.path] ?? const ResponseSpec(404, {});
    return JsonAdapter(spec.status, spec.body)
        .fetch(options, requestStream, cancelFuture);
  }
}
