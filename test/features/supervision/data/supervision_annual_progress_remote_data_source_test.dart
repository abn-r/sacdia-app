import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_annual_progress_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_annual_progress_repository_impl.dart';

SupervisionAnnualProgressRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionAnnualProgressRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

void _fail(
    RequestOptions o, RequestInterceptorHandler h, int status, Object body) {
  h.reject(DioException(
    requestOptions: o,
    response:
        Response<Object>(requestOptions: o, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  ));
}

const _query = (localFieldId: 3, clubTypeId: 2, yearId: 9);

void main() {
  group('territory summary (new server)', () {
    test('getUnions asks the summary for the caller unit and parses the rows',
        () async {
      final uris = <Uri>[];
      final ds = _ds((o, h) {
        uris.add(o.uri);
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'status': 'success',
          'data': [
            {'id': 1, 'name': 'Unión A', 'clubs_count': 8, 'configured': true},
            {'id': 2, 'name': 'Unión B', 'clubs_count': 0, 'configured': false},
            {'name': 'Sin id', 'clubs_count': 3},
          ],
        }));
      });

      final unions = await ds.getUnions(5);

      expect(uris, hasLength(1));
      expect(uris.single.path, '/api/v1/annual-rankings/territory-summary');
      expect(uris.single.queryParameters, isEmpty);
      expect(unions.map((e) => e.id), [1, 2]);
      expect(unions[0].name, 'Unión A');
      expect(unions[0].clubsCount, 8);
      expect(unions[0].configured, isTrue);
      expect(unions[1].clubsCount, 0);
      expect(unions[1].configured, isFalse);
    });

    test('getLocalFields asks the summary with union_id', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'status': 'success',
          'data': [
            {
              'id': 10,
              'name': 'Campo X',
              'clubs_count': 6,
              'configured': false
            },
          ],
        }));
      });

      final fields = await ds.getLocalFields(4);

      expect(uri.path, '/api/v1/annual-rankings/territory-summary');
      expect(uri.queryParameters, {'union_id': '4'});
      expect(fields.single.id, 10);
      expect(fields.single.configured, isFalse);
    });

    test('missing or malformed count and flag stay unknown, never 0 or true',
        () async {
      final ds = _ds((o, h) {
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'data': [
            {'id': 1, 'name': 'A'},
            {'id': 2, 'name': 'B', 'clubs_count': 'x', 'configured': 'yes'},
          ],
        }));
      });

      final unions = await ds.getUnions(5);

      expect(unions.map((e) => e.clubsCount), [null, null]);
      expect(unions.map((e) => e.configured), [null, null]);
    });

    test('a 403 on the summary is a forbidden failure, not a fallback',
        () async {
      final paths = <String>[];
      final ds = _ds((o, h) {
        paths.add(o.uri.path);
        _fail(o, h, 403, {'code': 'GUARD_PERMISSION_DENIED', 'message': 'No'});
      });
      final repo =
          SupervisionAnnualProgressRepositoryImpl(remoteDataSource: ds);

      final result = await repo.getUnions(5);

      final failure = result.fold<Failure>((f) => f, (_) => throw 'no');
      expect(isForbiddenFailure(failure), isTrue);
      expect(paths, ['/api/v1/annual-rankings/territory-summary']);
    });
  });

  group('catalogs (fallback on an old server: summary answers 404)', () {
    test('getUnions falls back to divisionId and filters by division_id',
        () async {
      final uris = <Uri>[];
      final ds = _ds((o, h) {
        uris.add(o.uri);
        if (o.uri.path.endsWith('/territory-summary')) {
          return _fail(o, h, 404, {'message': 'Cannot GET'});
        }
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: [
          {'union_id': 1, 'name': 'A', 'country_id': 1, 'division_id': 5},
          {'union_id': 2, 'name': 'B', 'country_id': 1, 'division_id': 6},
          {'union_id': 3, 'name': 'C'},
        ]));
      });
      final unions = await ds.getUnions(5);
      expect(uris.map((u) => u.path), [
        '/api/v1/annual-rankings/territory-summary',
        '/api/v1/catalogs/unions',
      ]);
      expect(uris.last.queryParameters, {'divisionId': '5'});
      expect(unions.map((e) => e.id), [1, 3]);
      expect(unions.first.name, 'A');
      // Names only: nothing invented about the clubs.
      expect(unions.first.clubsCount, isNull);
      expect(unions.first.configured, isNull);
    });

    test('getLocalFields falls back to unionId and filters by union_id',
        () async {
      final uris = <Uri>[];
      final ds = _ds((o, h) {
        uris.add(o.uri);
        if (o.uri.path.endsWith('/territory-summary')) {
          return _fail(o, h, 404, {'message': 'Cannot GET'});
        }
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: [
          {'local_field_id': 10, 'name': 'X', 'union_id': 4},
          {'local_field_id': 11, 'name': 'Y', 'union_id': 8},
          {'local_field_id': 12, 'name': 'Z'},
        ]));
      });
      final fields = await ds.getLocalFields(4);
      expect(uris.last.path, '/api/v1/catalogs/local-fields');
      expect(uris.last.queryParameters, {'unionId': '4'});
      expect(fields.map((e) => e.id), [10, 12]);
    });

    test('a failing catalogs call after the fallback is still a failure',
        () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/territory-summary')) {
          return _fail(o, h, 404, {'message': 'Cannot GET'});
        }
        _fail(o, h, 500, {'message': 'boom'});
      });
      final repo =
          SupervisionAnnualProgressRepositoryImpl(remoteDataSource: ds);

      final result = await repo.getUnions(5);

      expect(result.isLeft(), isTrue);
    });

    test('403 outside the territory is a forbidden failure', () async {
      final ds = _ds((o, h) => _fail(
          o, h, 403, {'code': 'GUARD_PERMISSION_DENIED', 'message': 'Denied'}));
      final repo =
          SupervisionAnnualProgressRepositoryImpl(remoteDataSource: ds);
      final result = await repo.getLocalFields(4);
      final failure = result.fold<Failure>((f) => f, (_) => throw 'no');
      expect(isForbiddenFailure(failure), isTrue);
      expect(failure.message, 'Denied');
    });
  });

  group('getAnnualProgress', () {
    test('sends the three required params and unwraps data', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'status': 'success',
          'total': 1,
          'data': [
            {
              'rank_position': 1,
              'club_id': 1,
              'club_section_id': 2,
              'club_name': 'Orion',
              'current_points': 10,
              'progress_percentage': 20,
            },
          ],
        }));
      });
      final result = await ds.getAnnualProgress(_query);
      expect(uri.path, '/api/v1/annual-rankings');
      expect(uri.queryParameters,
          {'local_field_id': '3', 'club_type_id': '2', 'year_id': '9'});
      expect(result.configured, isTrue);
      expect(result.clubs.single.clubName, 'Orion');
    });

    test('404 ANNUAL_RANKING_CONFIG_NOT_FOUND is configured:false', () async {
      final ds = _ds((o, h) => _fail(o, h, 404,
          {'code': 'ANNUAL_RANKING_CONFIG_NOT_FOUND', 'message': 'none'}));
      final result = await ds.getAnnualProgress(_query);
      expect(result.configured, isFalse);
      expect(result.clubs, isEmpty);
    });

    test('any other 404 is an exception', () async {
      final ds = _ds((o, h) =>
          _fail(o, h, 404, {'code': 'SOMETHING_ELSE', 'message': 'nope'}));
      await expectLater(
          ds.getAnnualProgress(_query), throwsA(isA<ServerException>()));
      final noBody = _ds((o, h) => _fail(o, h, 404, 'not found'));
      await expectLater(
          noBody.getAnnualProgress(_query), throwsA(isA<ServerException>()));
    });

    test('403 keeps the AuthException mapping', () async {
      final ds = _ds((o, h) => _fail(o, h, 403,
          {'code': 'ADMIN_USER_SCOPE_MISSING', 'message': 'No scope'}));
      await expectLater(
        ds.getAnnualProgress(_query),
        throwsA(isA<AuthException>().having(
            (e) => e.errorCode, 'errorCode', 'ADMIN_USER_SCOPE_MISSING')),
      );
    });
  });
}
