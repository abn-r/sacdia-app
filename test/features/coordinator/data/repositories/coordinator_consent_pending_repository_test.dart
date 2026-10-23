import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/coordinator/data/datasources/coordinator_remote_data_source.dart';
import 'package:sacdia_app/features/coordinator/data/repositories/coordinator_repository_impl.dart';

import '../../coordinator_test_support.dart';

class _Net implements NetworkInfo {
  @override
  dynamic noSuchMethod(Invocation invocation) => true;
}

/// Un backend que responde [status] con [body] a cualquier petición y registra
/// la consulta.
({CoordinatorRepositoryImpl repo, List<RequestOptions> requests}) _repo(
  int status,
  Object body,
) {
  final requests = <RequestOptions>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final response = Response<Object>(
          requestOptions: options,
          statusCode: status,
          data: body,
        );
        // Like the real client: a 4xx/5xx is a DioException.
        if (status >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
        } else {
          handler.resolve(response);
        }
      },
    ),
  );
  final dataSource = CoordinatorRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
  return (
    repo: CoordinatorRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _Net(),
    ),
    requests: requests,
  );
}

Map<String, Object?> _error(int status, String code) => {
      'statusCode': status,
      'code': code,
      'message': 'mensaje en cualquier idioma',
      'details': {'secret': 'never read'},
    };

void main() {
  test('asks the aggregate endpoint with limit and offset', () async {
    final h = _repo(200, {
      'status': 'success',
      'data': pendingPageJson(
        items: [pendingItemJson(id: 'a1', sectionId: 7)],
        total: 1,
      ),
    });

    final result = await h.repo.getConsentPending(limit: 25, offset: 50);

    expect(h.requests.single.path,
        'https://api.test/api/v1/coordination/me/consent-pending');
    expect(h.requests.single.queryParameters, {'limit': 25, 'offset': 50});
    final page = result.getOrElse(() => throw StateError('expected a page'));
    expect(page.total, 1);
    expect(page.items.single.request.assignmentId, '7/membership-requests/a1');
  });

  test('keeps the business error code of a 403, never the message', () async {
    final h = _repo(403, _error(403, 'GUARD_CLUB_SCOPE_REQUIRED'));

    final result = await h.repo.getConsentPending();

    final failure = result.swap().getOrElse(() => throw StateError('no error'));
    expect(failure, isA<AuthFailure>());
    expect(failure.code, 403);
    expect(failure.errorCode, 'GUARD_CLUB_SCOPE_REQUIRED');
  });

  test('keeps the business error code of other statuses too', () async {
    final h = _repo(400, _error(400, 'VALIDATION_ERROR'));

    final result = await h.repo.getConsentPending();

    final failure = result.swap().getOrElse(() => throw StateError('no error'));
    expect(failure.code, 400);
    expect(failure.errorCode, 'VALIDATION_ERROR');
  });
}
