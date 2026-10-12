import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/honors/data/datasources/honors_remote_data_source.dart';

HonorsRemoteDataSourceImpl _dataSource(
  Dio dio,
) =>
    HonorsRemoteDataSourceImpl(dio: dio, baseUrl: 'https://api.test/api/v1');

Dio _dio({Map<String, dynamic>? ok, int? failStatus, Object? failBody}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
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
    handler.resolve(Response<Map<String, dynamic>>(
      requestOptions: options,
      statusCode: 200,
      data: ok,
    ));
  }));
  return dio;
}

const _row = {
  'user_honor_id': 10,
  'honor_id': 7,
  'user_id': 'user-1',
  'validation_status': 'IN_PROGRESS',
  'certificate': '',
  'images': [],
  'document': null,
  'date': '2026-06-11T00:00:00.000Z',
  'completed_at': '2026-09-30',
  'instructor': {'kind': 'EXTERNAL', 'display_name': 'Juan López'},
};

void main() {
  test('sends the camelCase body and parses completed_at and instructor',
      () async {
    late RequestOptions seen;
    final dio = _dio(ok: _row)
      ..interceptors.insert(
        0,
        InterceptorsWrapper(onRequest: (o, h) {
          seen = o;
          h.next(o);
        }),
      );

    final model = await _dataSource(dio).updateUserHonor('user-1', 7, {
      'instructorName': 'Juan López',
      'completedAt': '2026-09-30',
    });

    expect(seen.method, 'PATCH');
    expect(seen.path, 'https://api.test/api/v1/users/user-1/honors/7');
    expect(seen.data, {
      'instructorName': 'Juan López',
      'completedAt': '2026-09-30',
    });
    expect(model.completedAt, DateTime(2026, 9, 30));
    expect(model.instructor?.displayName, 'Juan López');
  });

  group('business code of a failed PATCH', () {
    Future<ServerException> failWith(int status, Object? body) async {
      try {
        await _dataSource(_dio(failStatus: status, failBody: body))
            .updateUserHonor('user-1', 7, {'instructorUserId': 'x'});
      } on ServerException catch (e) {
        return e;
      }
      fail('expected a ServerException');
    }

    test('reads it from code', () async {
      final e = await failWith(400, {'code': 'HONOR_INSTRUCTOR_INVALID'});
      expect(e.errorCode, 'HONOR_INSTRUCTOR_INVALID');
      expect(e.code, 400);
    });

    test('reads it from message on the legacy envelope', () async {
      final e = await failWith(400, {'message': 'HONOR_DATE_TOO_OLD'});
      expect(e.errorCode, 'HONOR_DATE_TOO_OLD');
    });

    test('ignores free text and validation lists', () async {
      expect(
          (await failWith(400, {'message': 'bad request'})).errorCode, isNull);
      expect(
          (await failWith(400, {
            'message': ['completedAt must be a date']
          }))
              .errorCode,
          isNull);
      expect((await failWith(500, null)).errorCode, isNull);
    });
  });
}
