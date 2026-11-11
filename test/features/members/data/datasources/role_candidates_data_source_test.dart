import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/members/data/datasources/members_remote_data_source.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';

/// Answers in memory with [status] / [body] and records what was sent.
class _FakeApi extends Interceptor {
  _FakeApi(this.status, this.body);

  final int status;
  final Object? body;
  final List<RequestOptions> requests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    );
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
  }
}

MembersRemoteDataSourceImpl _ds(_FakeApi api) => MembersRemoteDataSourceImpl(
      dio: Dio()..interceptors.add(api),
      baseUrl: 'http://api',
    );

void main() {
  const page = {
    'status': 'success',
    'data': {
      'section': {
        'id': 163,
        'club_type_id': 1,
        'club_type_name': 'Aventureros'
      },
      'slots': [
        {'role': 'counselor', 'occupied': 3, 'max': null},
      ],
      'items': [
        {'user_id': 'u1', 'name': 'Laura', 'group': 'available'},
      ],
    },
    'meta': {'page': 2, 'limit': 20, 'total': 21},
  };

  test('getRoleCandidates calls the section endpoint with the query', () async {
    final api = _FakeApi(200, page);

    final result = await _ds(api).getRoleCandidates(
      clubId: 1,
      sectionId: 163,
      search: '  laura ',
      filter: RoleCandidatesFilter.withRole,
      page: 2,
    );

    final request = api.requests.single;
    expect(request.method, 'GET');
    expect(request.path, 'http://api/clubs/1/sections/163/role-candidates');
    expect(request.queryParameters, {
      'search': 'laura',
      'filter': 'with_role',
      'page': 2,
      'limit': 20,
    });
    expect(result.items.single.userId, 'u1');
    expect(result.page, 2);
    expect(result.total, 21);
    expect(result.slotFor('counselor')?.max, isNull);
  });

  test('an empty search is not sent', () async {
    final api = _FakeApi(200, page);

    await _ds(api).getRoleCandidates(clubId: 1, sectionId: 163);

    expect(api.requests.single.queryParameters.containsKey('search'), isFalse);
    expect(api.requests.single.queryParameters['filter'], 'available');
  });

  test('getRoleCandidateDetail calls the per-user endpoint', () async {
    final api = _FakeApi(200, {
      'data': {
        'user_id': 'u1',
        'name': 'Laura',
        'group': 'available',
        'honors_count': 3,
      },
    });

    final detail = await _ds(api).getRoleCandidateDetail(
      clubId: 1,
      sectionId: 163,
      userId: 'u1',
    );

    expect(
      api.requests.single.path,
      'http://api/clubs/1/sections/163/role-candidates/u1',
    );
    expect(detail.honorsCount, 3);
  });

  test('a 404 keeps the HTTP status (club without Guías Mayores section)',
      () async {
    final api = _FakeApi(404, {'message': 'Not found'});

    await expectLater(
      _ds(api).getRoleCandidates(clubId: 1, sectionId: 163),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 404)),
    );
  });

  test('a business error keeps only the code and message', () async {
    final api = _FakeApi(403, {
      'code': 'GUARD_CLUB_SCOPE_REQUIRED',
      'message': 'Fuera de alcance',
      'details': {'secret': 'never read'},
    });

    await expectLater(
      _ds(api).getRoleCandidates(clubId: 1, sectionId: 163),
      throwsA(
        isA<AuthException>()
            .having(
                (e) => e.errorCode, 'errorCode', 'GUARD_CLUB_SCOPE_REQUIRED')
            .having((e) => e.message, 'message', 'Fuera de alcance'),
      ),
    );
  });

  test('the existing assignment POST keeps the new business codes', () async {
    for (final code in const [
      'CLUB_ROLE_SLOT_LIMIT_REACHED',
      'CLUB_ROLE_EXCLUSIVE_CONFLICT',
      'MR_CONSENT_NOT_VERIFIED',
      'CLUB_ROLE_GM_MEMBERSHIP_REQUIRED',
      'CLUB_ROLE_ALREADY_HELD',
    ]) {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/catalogs/roles')) {
                handler.resolve(Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'role_id': 'r-1', 'name': 'counselor'},
                  ],
                ));
                return;
              }
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 409,
                    data: {'code': code, 'message': 'x'},
                  ),
                ),
              );
            },
          ),
        );
      final ds = MembersRemoteDataSourceImpl(dio: dio, baseUrl: 'http://api');

      await expectLater(
        ds.assignClubRole(
          clubId: 1,
          sectionId: 163,
          userId: 'u1',
          role: 'counselor',
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode', code)
              .having((e) => e.code, 'code', 409),
        ),
        reason: code,
      );
    }
  });
}
