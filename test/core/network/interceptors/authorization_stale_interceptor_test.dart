import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/business_error.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/network/api_error_mapper.dart';
import 'package:sacdia_app/core/network/interceptors/authorization_stale_interceptor.dart';

import '../../../support/http_adapters.dart';

void main() {
  late bool stale;
  late JsonAdapter adapter;
  late Dio dio;

  setUp(() {
    stale = true;
    adapter = JsonAdapter(200, {'ok': true});
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.insert(
        0,
        AuthorizationStaleInterceptor(isStale: () => stale),
      );
  });

  Future<DioException?> run(Future<Response<dynamic>> Function() call) async {
    try {
      await call();
      return null;
    } on DioException catch (e) {
      return e;
    }
  }

  test('rejects POST/PUT/PATCH/DELETE while stale, without sending them',
      () async {
    for (final call in <Future<Response<dynamic>> Function()>[
      () => dio.post('/activities', data: {}),
      () => dio.put('/activities/1', data: {}),
      () => dio.patch('/activities/1', data: {}),
      () => dio.delete('/activities/1'),
    ]) {
      final error = await run(call);
      expect(error, isNotNull);
      expect(error!.response?.statusCode, 403);
      expect(error.response?.data['code'], kAuthorizationStaleCode);
      expect(adapter.lastRequest, isNull, reason: 'never reached the network');
    }
  });

  test('GET is never touched', () async {
    expect(await run(() => dio.get('/activities')), isNull);
    expect(adapter.lastRequest?.path, '/activities');
  });

  test('a fresh authorization lets mutations through', () async {
    stale = false;
    expect(await run(() => dio.post('/activities', data: {})), isNull);
    expect(adapter.lastRequest?.method, 'POST');
  });

  test('session routes and explicit opt-outs pass while stale', () async {
    expect(await run(() => dio.post('/auth/logout')), isNull);
    expect(await run(() => dio.post('/auth/refresh')), isNull);
    expect(
      await run(
        () => dio.post(
          '/users/me/fcm-tokens',
          options: Options(extra: {kAllowWhileAuthorizationStale: true}),
        ),
      ),
      isNull,
    );
  });

  test('a throwing isStale never breaks the request', () async {
    final failing = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.insert(
        0,
        AuthorizationStaleInterceptor(isStale: () => throw StateError('x')),
      );
    expect(await run(() => failing.post('/activities', data: {})), isNull);
  });

  test('the data layer maps the rejection to a failure with the code',
      () async {
    final error = (await run(() => dio.post('/activities', data: {})))!;

    final business = businessErrorFrom(error);
    expect(business, isA<AuthException>());
    expect(business.errorCode, kAuthorizationStaleCode);
    expect(business.code, 403);

    expect(
      () => rethrowApiError(error),
      throwsA(
        isA<AuthException>()
            .having((e) => e.errorCode, 'errorCode', kAuthorizationStaleCode),
      ),
    );

    // Es un error de ESA mutación, no un «acceso restringido» de la pantalla:
    // ni la excepción ni el DioException cuentan como 403 de permisos.
    expect(isForbiddenFailure(business), isFalse);
    expect(isForbiddenFailure(error), isFalse);
  });
}
