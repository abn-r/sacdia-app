import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_clubs_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';

SupervisionClubsRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionClubsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionClubsRemoteDataSourceImpl _returning(int status, Object body) =>
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
  group('getClubs', () {
    Future<Uri> capture(
        {required SupervisionClubActiveFilter filter,
        required String search}) async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(
            requestOptions: o,
            statusCode: 200,
            data: {'data': [], 'meta': {}}));
      });
      await ds.getClubs(filter: filter, search: search, page: 2, limit: 25);
      return uri;
    }

    test('omits blank search and active for all', () async {
      final uri =
          await capture(filter: SupervisionClubActiveFilter.all, search: '  ');
      expect(uri.path, '/api/v1/clubs');
      expect(uri.queryParameters, {'page': '2', 'limit': '25'});
    });

    test('sends trimmed search and active flag', () async {
      var uri = await capture(
          filter: SupervisionClubActiveFilter.active, search: ' ori ');
      expect(uri.queryParameters,
          {'search': 'ori', 'active': 'true', 'page': '2', 'limit': '25'});
      uri = await capture(
          filter: SupervisionClubActiveFilter.inactive, search: '');
      expect(uri.queryParameters['active'], 'false');
    });

    test('parses the page', () async {
      final ds = _returning(200, {
        'data': [
          {'club_id': 1, 'name': 'A'},
        ],
        'meta': {'page': 1, 'total': 40, 'hasNextPage': true},
      });
      final page = await ds.getClubs(
          filter: SupervisionClubActiveFilter.all,
          search: '',
          page: 1,
          limit: 25);
      expect(page.items.single.id, 1);
      expect(page.total, 40);
      expect(page.hasMore, isTrue);
    });
  });

  group('club endpoints', () {
    test('getClub hits /clubs/:id and accepts bare or enveloped', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'data': {'club_id': 8, 'name': 'X'}
        }));
      });
      final p = await ds.getClub(8);
      expect(uri.path, '/api/v1/clubs/8');
      expect(p.id, 8);
      final bare =
          await _returning(200, {'club_id': 9, 'name': 'Y'}).getClub(9);
      expect(bare.id, 9);
    });

    test('getClub without id is a ServerException', () async {
      await expectLater(_returning(200, {'name': 'x'}).getClub(1),
          throwsA(isA<ServerException>()));
    });

    test('getOverview and getLeadership paths', () async {
      final paths = <String>[];
      final ds = _ds((o, h) {
        paths.add(o.uri.path);
        h.resolve(Response<Object>(
            requestOptions: o, statusCode: 200, data: {'data': {}}));
      });
      await ds.getOverview(3);
      await ds.getLeadership(3);
      expect(paths, ['/api/v1/clubs/3/overview', '/api/v1/clubs/3/leadership']);
    });

    test('403 maps to AuthException recognized as forbidden', () async {
      final ds = _returning(403, {
        'code': 'GUARD_CLUB_SCOPE_REQUIRED',
        'message': 'denied',
        'details': {'x': 1},
      });
      await expectLater(
        ds.getClub(1),
        throwsA(isA<AuthException>()
            .having(
                (e) => e.errorCode, 'errorCode', 'GUARD_CLUB_SCOPE_REQUIRED')
            .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
      );
    });

    test('404 keeps its code', () async {
      final ds = _returning(404, {'code': 'CLUB_NOT_FOUND', 'message': 'no'});
      await expectLater(
        ds.getClub(1),
        throwsA(isA<ServerException>()
            .having((e) => e.code, 'code', 404)
            .having((e) => e.errorCode, 'errorCode', 'CLUB_NOT_FOUND')),
      );
    });
  });
}
