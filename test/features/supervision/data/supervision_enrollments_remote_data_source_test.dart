import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_enrollments_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_enrollments_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';

SupervisionEnrollmentsRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionEnrollmentsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionEnrollmentsRemoteDataSourceImpl _returning(
        int status, Object body) =>
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

const _item = {'enrollment_id': 9, 'status': 'active'};

void main() {
  test('queue sends query params and unwraps the envelope', () async {
    late Uri uri;
    final ds = _ds((o, h) {
      uri = o.uri;
      h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
        'status': 'success',
        'data': {
          'items': [_item],
          'meta': {
            'page': 2,
            'limit': 10,
            'total': 11,
            'counts': {'pending': 1, 'approved': 2, 'rejected': 3},
          },
        },
      }));
    });
    final page = await ds.getQueue(
      status: SupervisionEnrollmentStatus.rejected,
      search: '  orion ',
      page: 2,
      limit: 10,
    );
    expect(uri.path, '/api/v1/club-enrollments/validation/queue');
    expect(uri.queryParameters, {
      'status': 'rejected',
      'search': 'orion',
      'page': '2',
      'limit': '10',
    });
    expect(page.items.single.id, '9');
    expect(page.total, 11);
    expect(page.counts.rejected, 3);
  });

  test('empty search is omitted and 201 is accepted', () async {
    late Uri uri;
    final ds = _ds((o, h) {
      uri = o.uri;
      h.resolve(Response<Object>(requestOptions: o, statusCode: 201, data: {
        'data': {'items': [], 'meta': {}}
      }));
    });
    await ds.getQueue(search: '   ');
    expect(uri.queryParameters.containsKey('search'), isFalse);
    expect(uri.queryParameters['status'], 'pending_validation');
  });

  test('approve posts to the right URL without body', () async {
    late RequestOptions req;
    final ds = _ds((o, h) {
      req = o;
      h.resolve(Response<Object>(
          requestOptions: o, statusCode: 200, data: {'data': _item}));
    });
    final result = await ds.approve('9');
    expect(req.method, 'POST');
    expect(req.uri.path, '/api/v1/club-enrollments/9/approve');
    expect(req.data, isNull);
    expect(result.id, '9');
  });

  test('reject posts the reason', () async {
    late RequestOptions req;
    final ds = _ds((o, h) {
      req = o;
      h.resolve(Response<Object>(
          requestOptions: o, statusCode: 200, data: {'data': _item}));
    });
    await ds.reject('9', 'Missing board');
    expect(req.uri.path, '/api/v1/club-enrollments/9/reject');
    expect(req.data, {'reason': 'Missing board'});
  });

  test('403 maps to AuthException recognized as forbidden', () async {
    final ds = _returning(403, {
      'status': 'error',
      'code': 'GUARD_PERMISSION_DENIED',
      'message': 'no',
    });
    await expectLater(
      ds.getQueue(),
      throwsA(isA<AuthException>()
          .having((e) => e.errorCode, 'errorCode', 'GUARD_PERMISSION_DENIED')
          .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
    );
  });

  for (final c in const [
    (404, 'CE_ENROLLMENT_NOT_FOUND'),
    (409, 'CE_ENROLLMENT_NOT_PENDING'),
  ]) {
    test('${c.$2} surfaces code and message', () async {
      final ds = _returning(c.$1, {'code': c.$2, 'message': 'msg ${c.$2}'});
      await expectLater(
        ds.approve('1'),
        throwsA(isA<ServerException>()
            .having((e) => e.errorCode, 'errorCode', c.$2)
            .having((e) => e.message, 'message', 'msg ${c.$2}')
            .having((e) => e.code, 'code', c.$1)),
      );
    });
  }

  test('CE_SELF_REVIEW (403) surfaces its code', () async {
    final ds =
        _returning(403, {'code': 'CE_SELF_REVIEW', 'message': 'own club'});
    await expectLater(
      ds.reject('1', 'because'),
      throwsA(isA<AuthException>()
          .having((e) => e.errorCode, 'errorCode', 'CE_SELF_REVIEW')),
    );
  });

  test('400 validation list message is joined to a readable text', () async {
    final ds = _returning(400, {
      'code': 'VALIDATION_ERROR',
      'message': ['reason too short', 'other'],
    });
    await expectLater(
      ds.reject('1', 'x'),
      throwsA(isA<ServerException>()
          .having((e) => e.message, 'message', 'reason too short')),
    );
  });

  test('repository maps failures and success', () async {
    final fail = SupervisionEnrollmentsRepositoryImpl(
        remoteDataSource: _returning(
            409, {'code': 'CE_ENROLLMENT_NOT_PENDING', 'message': 'stale'}));
    (await fail.approve('1')).fold(
      (f) {
        expect(f, isA<ServerFailure>());
        expect(f.errorCode, 'CE_ENROLLMENT_NOT_PENDING');
        expect(f.message, 'stale');
      },
      (_) => fail_('expected failure'),
    );

    final forbidden = SupervisionEnrollmentsRepositoryImpl(
        remoteDataSource: _returning(403, {'code': 'GUARD_PERMISSION_DENIED'}));
    (await forbidden.getQueue()).fold(
      (f) {
        expect(f, isA<AuthFailure>());
        expect(isForbiddenFailure(f), isTrue);
      },
      (_) => fail_('expected failure'),
    );

    final ok = SupervisionEnrollmentsRepositoryImpl(
        remoteDataSource: _returning(200, {
      'data': {'items': [], 'meta': {}}
    }));
    expect((await ok.getQueue()).isRight(), isTrue);
  });
}

void fail_(String m) => fail(m);
