import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_operations_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_operations_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';

SupervisionOperationsRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionOperationsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionOperationsRemoteDataSourceImpl _returning(int status, Object body) =>
    _ds((o, h) {
      final res =
          Response<Object>(requestOptions: o, statusCode: status, data: body);
      if (status >= 400) {
        h.reject(DioException(
            requestOptions: o,
            response: res,
            type: DioExceptionType.badResponse));
      } else {
        h.resolve(res);
      }
    });

void main() {
  const own = SupervisionOperationsQuery();

  test('own scope sends no query parameters', () async {
    late Uri uri;
    final ds = _ds((o, h) {
      uri = o.uri;
      h.resolve(Response<Object>(
          requestOptions: o, statusCode: 200, data: {'data': {}}));
    });
    await ds.getDashboard(own);
    expect(uri.path, '/api/v1/admin/analytics/operations-dashboard');
    expect(uri.queryParameters, isEmpty);
  });

  test('sends only the non-null ids', () async {
    late Uri uri;
    final ds = _ds((o, h) {
      uri = o.uri;
      h.resolve(Response<Object>(
          requestOptions: o, statusCode: 200, data: {'data': {}}));
    });
    await ds.getDashboard(
        const SupervisionOperationsQuery(unionId: 4, localFieldId: 11));
    expect(uri.queryParameters, {'union_id': '4', 'local_field_id': '11'});
  });

  test('unwraps data', () async {
    final ds = _returning(200, {
      'status': 'ok',
      'data': {
        'meta': {
          'scope': {'level': 'division', 'id': 2, 'name': 'Div', 'path': []},
        },
        'summary': {
          'administrative_clubs': {'total': 5},
        },
        'children': [],
      },
    });
    final d = await ds.getDashboard(own);
    expect(d.scope.name, 'Div');
    expect(d.summary.clubsTotal, 5);
  });

  test('403 with code maps to AuthException recognized as forbidden', () async {
    final ds = _returning(403, {
      'code': 'GUARD_PERMISSION_DENIED',
      'message': 'denied',
      'details': {'secret': 1},
    });
    await expectLater(
      ds.getDashboard(own),
      throwsA(isA<AuthException>()
          .having((e) => e.code, 'code', 403)
          .having((e) => e.errorCode, 'errorCode', 'GUARD_PERMISSION_DENIED')
          .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
    );
  });

  test('repository keeps the 403 code in the failure', () async {
    final repo = SupervisionOperationsRepositoryImpl(
        remoteDataSource: _returning(
            403, {'code': 'ADMIN_USER_SCOPE_MISSING', 'message': 'x'}));
    final result = await repo.getDashboard(own);
    result.fold(
      (f) {
        expect(f.errorCode, 'ADMIN_USER_SCOPE_MISSING');
        expect(isForbiddenFailure(f), isTrue);
      },
      (_) => fail('expected failure'),
    );
  });

  test('non-2xx without error status is a ServerException', () async {
    final ds = _returning(204, {});
    await expectLater(ds.getDashboard(own), throwsA(isA<ServerException>()));
  });
}
