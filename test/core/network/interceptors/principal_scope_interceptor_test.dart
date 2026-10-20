import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/dio_client.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/principal_scope_interceptor.dart';

import '../../../support/http_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int scopeDenied;
  late int actingForbidden;
  late int expired;
  late Dio dio;
  late ActingForSession session;

  void setUpWith(int status, Object body, {bool acting = false}) {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
      AppConstants.refreshTokenKey: 'refresh-token',
    });
    scopeDenied = 0;
    actingForbidden = 0;
    expired = 0;
    session = ActingForSession();
    if (acting) {
      session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    }
    dio = DioClient.createDio(
      onAuthExpired: () => expired++,
      onPrincipalScopeDenied: () => scopeDenied++,
      actingForSession: session,
      onActingForbidden: (_) => actingForbidden++,
    )..httpClientAdapter = JsonAdapter(status, body);
  }

  Future<DioException> get(String path) async {
    try {
      await dio.get(path);
    } on DioException catch (e) {
      return e;
    }
    fail('expected a DioException');
  }

  Map<String, dynamic> body(int status, String code) => {
        'status': 'error',
        'statusCode': status,
        'code': code,
        'message': 'x',
        'details': {'required_scope': 'member:read', 'kind': 'supervised_user'},
      };

  test('PRINCIPAL_SCOPE_DENIED asks the app to refresh the mode, once',
      () async {
    setUpWith(403, body(403, PrincipalScopeInterceptor.scopeDeniedCode));

    final error = await get('/clubs/1/units');

    expect(scopeDenied, 1);
    // El error de esa acción sigue su camino: la pantalla lo muestra.
    expect(error.response?.statusCode, 403);
    expect(expired, 0);
    expect(actingForbidden, 0);
  });

  test('it does not touch an acting session or log anyone out', () async {
    setUpWith(
      403,
      body(403, PrincipalScopeInterceptor.scopeDeniedCode),
      acting: true,
    );

    await get('/clubs/1/units');

    expect(scopeDenied, 1);
    expect(session.isActing, isTrue);
    expect(actingForbidden, 0);
    expect(expired, 0);
  });

  test('ACTING_FOR_SCOPE_DENIED is the guardian error and does not refresh',
      () async {
    setUpWith(403, body(403, 'ACTING_FOR_SCOPE_DENIED'), acting: true);

    await get('/clubs/1/units');

    expect(scopeDenied, 0);
  });

  test('another 403 does not refresh the mode', () async {
    setUpWith(403, body(403, 'GUARD_PERMISSION_DENIED'));

    await get('/clubs/1/units');

    expect(scopeDenied, 0);
  });

  test('the same code on a non-403 is ignored', () async {
    setUpWith(401, body(401, PrincipalScopeInterceptor.scopeDeniedCode));

    await get('/clubs/1/units');

    expect(scopeDenied, 0);
  });

  test('a callback that throws never breaks the error chain', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    final broken = Dio()
      ..httpClientAdapter = JsonAdapter(
        403,
        body(403, PrincipalScopeInterceptor.scopeDeniedCode),
      );
    broken.interceptors.add(
      PrincipalScopeInterceptor(onScopeDenied: () => throw StateError('boom')),
    );

    await expectLater(
      broken.get('http://localhost:3000/x'),
      throwsA(isA<DioException>()),
    );
  });

  test('a teen token never carries X-Acting-For (no acting session)', () async {
    setUpWith(200, {'status': 'success', 'data': {}});
    final adapter = JsonAdapter(200, {'status': 'success', 'data': {}});
    dio.httpClientAdapter = adapter;

    await dio.get('/users/me/supervision');

    expect(
      adapter.lastRequest?.headers.containsKey(AuthInterceptor.actingForHeader),
      isFalse,
    );
  });
}
