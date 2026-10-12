import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/honors/data/datasources/honors_remote_data_source.dart';
import 'package:sacdia_app/features/honors/domain/entities/instructor_proposal.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_update.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';

HonorsRemoteDataSourceImpl _dataSource(Dio dio) =>
    HonorsRemoteDataSourceImpl(dio: dio, baseUrl: 'https://api.test/api/v1');

/// Answers every request with [data] (or rejects with [failStatus]) and
/// records the request in [seen].
Dio _dio(
  List<RequestOptions> seen, {
  Object? data,
  int status = 201,
  int? failStatus,
  Object? failBody,
}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    seen.add(options);
    if (failStatus != null) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: failStatus,
          data: failBody,
        ),
      ));
      return;
    }
    handler.resolve(Response(
      requestOptions: options,
      statusCode: status,
      data: data,
    ));
  }));
  return dio;
}

const _created = {
  'proposal_id': 'p-1',
  'status': 'PENDING',
  'instructor': {
    'kind': 'USER',
    'user_id': 'u-ana',
    'display_name': 'Ana Gómez',
  },
};

void main() {
  test('the body is camelCase and has exactly one field', () {
    expect(
      honorInstructorProposalBody(const InstructorSelection.user(
        id: 'u-ana',
        displayName: 'Ana Gómez',
      )),
      {'instructorUserId': 'u-ana'},
    );
    expect(
      honorInstructorProposalBody(const InstructorSelection.external('Juan')),
      {'instructorName': 'Juan'},
    );
    expect(
      () => honorInstructorProposalBody(const InstructorSelection.none()),
      throwsArgumentError,
    );
  });

  test('POST sends the body to .../instructor-proposal and parses the answer',
      () async {
    final seen = <RequestOptions>[];
    final proposal = await _dataSource(_dio(seen, data: _created))
        .proposeHonorInstructor('user-1', 7, {'instructorUserId': 'u-ana'});

    expect(seen.single.method, 'POST');
    expect(seen.single.path,
        'https://api.test/api/v1/users/user-1/honors/7/instructor-proposal');
    expect(seen.single.data, {'instructorUserId': 'u-ana'});
    expect(proposal.proposalId, 'p-1');
    expect(proposal.status, InstructorProposalStatus.pending);
    expect(proposal.instructor?.displayName, 'Ana Gómez');
  });

  test('POST tolerates a wrapped or empty answer', () async {
    final wrapped = await _dataSource(_dio([], data: {'data': _created}))
        .proposeHonorInstructor('user-1', 7, {'instructorName': 'Juan'});
    expect(wrapped.proposalId, 'p-1');

    final empty = await _dataSource(_dio([], data: null))
        .proposeHonorInstructor('user-1', 7, {'instructorName': 'Juan'});
    expect(empty.status, InstructorProposalStatus.pending);
  });

  test('DELETE hits the same path', () async {
    final seen = <RequestOptions>[];
    await _dataSource(_dio(seen, data: _created, status: 200))
        .cancelHonorInstructorProposal('user-1', 7);

    expect(seen.single.method, 'DELETE');
    expect(seen.single.path,
        'https://api.test/api/v1/users/user-1/honors/7/instructor-proposal');
  });

  group('failures keep the status and the business code', () {
    Future<ServerException> fail(int status, Object? body,
        {bool cancel = false}) async {
      final ds = _dataSource(_dio([], failStatus: status, failBody: body));
      try {
        if (cancel) {
          await ds.cancelHonorInstructorProposal('user-1', 7);
        } else {
          await ds.proposeHonorInstructor('user-1', 7, {'instructorName': 'x'});
        }
      } on ServerException catch (e) {
        return e;
      }
      throw TestFailure('no exception');
    }

    test('a 400 with its code', () async {
      final e = await fail(400, {'code': 'HONOR_INSTRUCTOR_UNCHANGED'});
      expect(e.code, 400);
      expect(e.errorCode, 'HONOR_INSTRUCTOR_UNCHANGED');
    });

    test('the 429 throttle has no code', () async {
      final e = await fail(429, {'message': 'ThrottlerException: Too Many'});
      expect(e.code, 429);
      expect(e.errorCode, isNull);
    });

    test('a 404 on DELETE', () async {
      final e = await fail(
        404,
        {'code': 'HONOR_INSTRUCTOR_PROPOSAL_NOT_FOUND'},
        cancel: true,
      );
      expect(e.errorCode, 'HONOR_INSTRUCTOR_PROPOSAL_NOT_FOUND');
    });
  });
}
