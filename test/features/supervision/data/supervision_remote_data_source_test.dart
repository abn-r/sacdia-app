import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_repository_impl.dart';

SupervisionRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionRemoteDataSourceImpl _returning(int status, Object body) =>
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
  test('unwraps the envelope and hits the right URL', () async {
    late String url;
    final ds = _ds((o, h) {
      url = o.uri.toString();
      h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
        'status': 'success',
        'data': {
          'territory_level': 'union',
          'counts': {'club_enrollments': 3, 'transfers': null},
        },
      }));
    });
    final result = await ds.getPendingCounts();
    expect(url, 'https://api.test/api/v1/supervision/pending-counts');
    expect(result.territoryLevel, 'union');
    expect(result.clubEnrollments, 3);
    expect(result.transfers, isNull);
  });

  test('403 maps to AuthException that isForbiddenFailure recognizes',
      () async {
    final ds = _returning(403, {'code': 'GUARD_PERMISSION_DENIED'});
    await expectLater(
      ds.getPendingCounts(),
      throwsA(isA<AuthException>()
          .having((e) => e.code, 'code', 403)
          .having((e) => e.errorCode, 'errorCode', 'GUARD_PERMISSION_DENIED')
          .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
    );
  });

  test('network error maps to ServerException', () async {
    final ds = _ds((o, h) => h.reject(DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
        message: 'offline')));
    await expectLater(
      ds.getPendingCounts(),
      throwsA(isA<ServerException>()
          .having((e) => isForbiddenFailure(e), 'forbidden', isFalse)),
    );
  });

  test('repository maps 403 to AuthFailure and success to Right', () async {
    final forbidden = SupervisionRepositoryImpl(
        remoteDataSource: _returning(403, {'code': 'GUARD_PERMISSION_DENIED'}));
    final left = await forbidden.getPendingCounts();
    left.fold(
      (f) {
        expect(f, isA<AuthFailure>());
        expect(isForbiddenFailure(f), isTrue);
      },
      (_) => fail('expected failure'),
    );

    final ok = SupervisionRepositoryImpl(
        remoteDataSource: _returning(200, {
      'data': {'territory_level': 'all', 'counts': <String, Object?>{}}
    }));
    expect((await ok.getPendingCounts()).isRight(), isTrue);
  });
}
