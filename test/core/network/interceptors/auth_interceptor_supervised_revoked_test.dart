import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';

import '../../../support/http_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int expiredCalls;
  late int revokedCalls;
  late int requests;
  late Dio dio;

  Future<void> setUpWith(
    int status,
    Object body, {
    bool withRevokedCallback = true,
    bool withRefreshToken = true,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
      if (withRefreshToken) AppConstants.refreshTokenKey: 'refresh-token',
    });
    expiredCalls = 0;
    revokedCalls = 0;
    requests = 0;
    final adapter = _CountingAdapter(status, body, onFetch: () => requests++);
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshAdapter: adapter,
        onAuthExpired: () => expiredCalls++,
        onSupervisedAccessRevoked:
            withRevokedCallback ? () => revokedCalls++ : null,
      ),
    );
  }

  Future<DioException> getMe() async {
    try {
      await dio.get('/users/me/supervision');
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

  test('a revoked supervised token clears the session without refreshing',
      () async {
    await setUpWith(401, body('AUTH_SUPERVISED_ACCESS_REVOKED'));

    final error = await getMe();

    expect(error.response?.statusCode, 401);
    // Una sola petición: nunca se intentó /auth/refresh ni un reintento.
    expect(requests, 1);
    expect(revokedCalls, 1);
    expect(expiredCalls, 0);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: AppConstants.tokenKey), isNull);
    expect(await storage.read(key: AppConstants.refreshTokenKey), isNull);
  });

  test('without a dedicated callback it falls back to the expired session',
      () async {
    await setUpWith(
      401,
      body('AUTH_SUPERVISED_ACCESS_REVOKED'),
      withRevokedCallback: false,
    );

    await getMe();

    expect(expiredCalls, 1);
    expect(requests, 1);
  });

  test('a plain 401 still goes through the refresh path', () async {
    await setUpWith(401, body(null), withRefreshToken: false);

    await getMe();

    expect(revokedCalls, 0);
    expect(expiredCalls, 1);
  });

  test('another 401 code does not trigger the revoked callback', () async {
    await setUpWith(401, body('AUTH_TOKEN_EXPIRED'), withRefreshToken: false);

    await getMe();

    expect(revokedCalls, 0);
    expect(expiredCalls, 1);
  });

  test('the same code on the login endpoint is not a session event', () async {
    await setUpWith(401, body('AUTH_SUPERVISED_ACCESS_REVOKED'));

    try {
      await dio.post('/auth/login', data: {'identifier': 'x', 'password': 'y'});
    } on DioException {
      // esperado
    }

    expect(revokedCalls, 0);
    expect(expiredCalls, 0);
  });
}

class _CountingAdapter extends JsonAdapter {
  _CountingAdapter(super.statusCode, super.body, {required this.onFetch});

  final void Function() onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    onFetch();
    return super.fetch(options, requestStream, cancelFuture);
  }
}
