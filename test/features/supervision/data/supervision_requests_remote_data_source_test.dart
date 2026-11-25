import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_requests_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_requests_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';

SupervisionRequestsRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionRequestsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionRequestsRemoteDataSourceImpl _returning(int status, Object body) =>
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

const _transfer = {
  'transfer_request_id': 'T1',
  'user_id': 'U1',
  'status': 'pending',
  'user': {'name': 'Ana', 'paternal_last_name': 'Lopez'},
};

void main() {
  test('list: raw list, URL and status query', () async {
    late RequestOptions captured;
    final ds = _ds((o, h) {
      captured = o;
      h.resolve(Response<Object>(
          requestOptions: o, statusCode: 200, data: [_transfer, 'junk']));
    });
    final result = await ds.getRequests(
      kind: SupervisionRequestKind.transfer,
      status: SupervisionRequestStatus.pending,
    );
    expect(captured.uri.toString(),
        'https://api.test/api/v1/requests/transfers?status=pending');
    expect(result, hasLength(1));
    expect(result.first.id, 'T1');
  });

  test('list: {data: [...]} for assignments and no status when unknown',
      () async {
    late RequestOptions captured;
    final ds = _ds((o, h) {
      captured = o;
      h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
        'data': [
          {'request_id': 'A1', 'status': 'approved'}
        ]
      }));
    });
    final result = await ds.getRequests(
      kind: SupervisionRequestKind.assignment,
      status: SupervisionRequestStatus.unknown,
    );
    expect(captured.uri.toString(),
        'https://api.test/api/v1/requests/assignments');
    expect(result.single.kind, SupervisionRequestKind.assignment);
  });

  test('review: body omits blank comment, 201 accepted', () async {
    late RequestOptions captured;
    final ds = _ds((o, h) {
      captured = o;
      h.resolve(Response<Object>(
          requestOptions: o,
          statusCode: 201,
          data: {..._transfer, 'status': 'approved'}));
    });
    final r = await ds.review(
      kind: SupervisionRequestKind.transfer,
      requestId: 'T1',
      approve: true,
      comment: '   ',
    );
    expect(captured.method, 'POST');
    expect(captured.uri.toString(),
        'https://api.test/api/v1/requests/transfers/T1/review');
    expect(captured.data, {'action': 'approved'});
    expect(r.status, SupervisionRequestStatus.approved);
  });

  test('review: rejects with trimmed comment on assignments', () async {
    late RequestOptions captured;
    final ds = _ds((o, h) {
      captured = o;
      h.resolve(Response<Object>(
          requestOptions: o,
          statusCode: 200,
          data: {'request_id': 'A1', 'status': 'rejected'}));
    });
    await ds.review(
      kind: SupervisionRequestKind.assignment,
      requestId: 'A1',
      approve: false,
      comment: ' no ',
    );
    expect(captured.uri.path, '/api/v1/requests/assignments/A1/review');
    expect(captured.data, {'action': 'rejected', 'comment': 'no'});
  });

  for (final code in const [
    'REQUEST_TRANSFER_ALREADY_REVIEWED',
    'REQUEST_ASSIGNMENT_ALREADY_REVIEWED',
    'REQUEST_ROLE_SLOT_LIMIT_REACHED',
    'CLUB_ROLE_EXCLUSIVE_CONFLICT',
    'REQUEST_TRANSFER_NOT_FOUND',
  ]) {
    test('error $code surfaces code and message', () async {
      final status = code.endsWith('NOT_FOUND') ? 404 : 409;
      final ds = _returning(status, {
        'status': 'error',
        'statusCode': status,
        'code': code,
        'message': 'msg $code'
      });
      await expectLater(
        ds.review(
            kind: SupervisionRequestKind.transfer,
            requestId: 'T1',
            approve: true),
        throwsA(isA<ServerException>()
            .having((e) => e.errorCode, 'errorCode', code)
            .having((e) => e.message, 'message', 'msg $code')
            .having((e) => e.code, 'code', status)),
      );
    });
  }

  test('403 maps to forbidden', () async {
    final ds = _returning(403, {'code': 'GUARD_PERMISSION_DENIED'});
    await expectLater(
      ds.getRequests(
          kind: SupervisionRequestKind.transfer,
          status: SupervisionRequestStatus.pending),
      throwsA(isA<AuthException>()
          .having((e) => e.errorCode, 'errorCode', 'GUARD_PERMISSION_DENIED')
          .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
    );
  });

  test('repository maps errors to failures and success to Right', () async {
    final conflict = SupervisionRequestsRepositoryImpl(
        remoteDataSource: _returning(409, {
      'code': 'REQUEST_TRANSFER_ALREADY_REVIEWED',
      'message': 'already'
    }));
    (await conflict.review(
            kind: SupervisionRequestKind.transfer,
            requestId: 'T1',
            approve: true))
        .fold((f) {
      expect(f, isA<ServerFailure>());
      expect(f.errorCode, 'REQUEST_TRANSFER_ALREADY_REVIEWED');
      expect(f.message, 'already');
    }, (_) => fail('expected failure'));

    final forbidden = SupervisionRequestsRepositoryImpl(
        remoteDataSource:
            _returning(403, {'code': 'ADMIN_USER_SCOPE_MISSING'}));
    (await forbidden.getRequests(
            kind: SupervisionRequestKind.assignment,
            status: SupervisionRequestStatus.pending))
        .fold((f) {
      expect(f, isA<AuthFailure>());
      expect(isForbiddenFailure(f), isTrue);
    }, (_) => fail('expected failure'));

    final ok = SupervisionRequestsRepositoryImpl(
        remoteDataSource: _returning(200, [_transfer]));
    final right = await ok.getRequests(
        kind: SupervisionRequestKind.transfer,
        status: SupervisionRequestStatus.pending);
    expect(right.isRight(), isTrue);
  });
}
