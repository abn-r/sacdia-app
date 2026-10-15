import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';

import '../../../support/http_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int expiredCalls;
  late Dio dio;
  late JsonAdapter adapter;

  /// Sin refresh token guardado, el ciclo de refresh falla de inmediato y sin
  /// red: ese fallo (tokens borrados + `onAuthExpired`) es la señal de que el
  /// interceptor sí intentó refrescar la sesión.
  Future<void> setUpWith(int status, Object body) async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    expiredCalls = 0;
    adapter = JsonAdapter(status, body);
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(dio: dio, onAuthExpired: () => expiredCalls++),
    );
  }

  Future<DioException> deleteMe() async {
    try {
      await dio.delete('/auth/me', data: {'password': 'pw'});
    } on DioException catch (e) {
      return e;
    }
    fail('expected a DioException');
  }

  Map<String, dynamic> errorBody(String? code) => {
        'status': 'error',
        'statusCode': 401,
        if (code != null) 'code': code,
        'message': 'x',
      };

  for (final code in ['AUTH_INVALID_PASSWORD', 'AUTH_INVALID_TOKEN']) {
    test('a $code 401 is passed through without refreshing the session',
        () async {
      await setUpWith(401, errorBody(code));

      final error = await deleteMe();

      expect(error.response?.statusCode, 401);
      expect(error.response?.data['code'], code);
      expect(expiredCalls, 0);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: AppConstants.tokenKey), 'access-token');
    });
  }

  test('a 401 without code still goes through the refresh path', () async {
    await setUpWith(401, errorBody(null));

    final error = await deleteMe();

    expect(error.response?.statusCode, 401);
    expect(expiredCalls, 1);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: AppConstants.tokenKey), isNull);
  });

  test('a 401 with a session code still goes through the refresh path',
      () async {
    await setUpWith(401, errorBody('AUTH_TOKEN_EXPIRED'));

    await deleteMe();

    expect(expiredCalls, 1);
  });

  test('a 401 with a non-map body still goes through the refresh path',
      () async {
    await setUpWith(401, 'Unauthorized');

    await deleteMe();

    expect(expiredCalls, 1);
  });
}
