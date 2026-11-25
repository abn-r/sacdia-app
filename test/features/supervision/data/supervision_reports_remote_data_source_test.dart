import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_reports_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_reports_repository_impl.dart';

SupervisionReportsRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionReportsRemoteDataSourceImpl(
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

const _period = (year: 2026, month: 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getPeriods', () {
    test('sends only limit=1 and unwraps the envelope', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'status': 'success',
          'data': {
            'as_of': '2026-03-15T00:00:00Z',
            'totals': {
              'monthly': {
                'by_period': [
                  {'year': 2026, 'month': 3, 'expected': 2},
                ],
              },
            },
          },
        }));
      });
      final periods = await ds.getPeriods();
      expect(uri.path, '/api/v1/reports/compliance');
      expect(uri.queryParameters, {'limit': '1'});
      expect(periods.defaultPeriod?.counts.expected, 2);
    });
  });

  group('getCompliance', () {
    test('sends year, month, page and limit only', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'data': {
            'totals': {
              'clubs': 2,
              'monthly': {'expected': 2},
            },
            'total': 70,
            'page': 2,
            'items': [
              {'club_id': 1, 'club_name': 'Orion'},
            ],
          },
        }));
      });
      final page = await ds.getCompliance(period: _period, page: 2, limit: 50);
      expect(uri.path, '/api/v1/reports/compliance');
      expect(uri.queryParameters,
          {'year': '2026', 'month': '3', 'page': '2', 'limit': '50'});
      expect(page.clubs.single.clubName, 'Orion');
      expect(page.totals.expected, 2);
      expect(page.hasMore, isFalse);
    });

    test('403 maps to a forbidden AuthFailure with the server code', () async {
      final ds = _ds((o, h) => _fail(o, h, 403, {
            'code': 'ADMIN_USER_SCOPE_MISSING',
            'message': 'No scope',
            'details': {'secret': 1},
          }));
      final repo = SupervisionReportsRepositoryImpl(remoteDataSource: ds);
      final result =
          await repo.getCompliance(period: _period, page: 1, limit: 50);
      final failure = result.fold<Failure>((f) => f, (_) => throw 'no');
      expect(failure.message, 'No scope');
      expect(isForbiddenFailure(failure), isTrue);
    });

    test('non-2xx without error status is a ServerException', () async {
      final ds = _ds((o, h) => h.resolve(
          Response<Object>(requestOptions: o, statusCode: 204, data: {})));
      await expectLater(ds.getCompliance(period: _period, page: 1, limit: 50),
          throwsA(isA<ServerException>()));
    });
  });

  group('getReports', () {
    test('sends year, month, page and limit only', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'data': {
            'total': 30,
            'page': 1,
            'limit': 25,
            'items': [
              {'monthly_report_id': 'uuid-1', 'status': 'submitted'},
            ],
          },
        }));
      });
      final page = await ds.getReports(period: _period, page: 1, limit: 25);
      expect(uri.path, '/api/v1/monthly-reports/admin/list');
      expect(uri.queryParameters,
          {'year': '2026', 'month': '3', 'page': '1', 'limit': '25'});
      expect(page.items.single.id, 'uuid-1');
      expect(page.hasMore, isTrue);
    });

    test('400 keeps the business code', () async {
      final ds = _ds((o, h) => _fail(o, h, 400,
          {'code': 'MONTHLY_REPORT_INVALID_MONTH', 'message': 'Bad month'}));
      await expectLater(
        ds.getReports(period: _period, page: 1, limit: 25),
        throwsA(isA<ServerException>().having(
            (e) => e.errorCode, 'errorCode', 'MONTHLY_REPORT_INVALID_MONTH')),
      );
    });
  });

  // The download writes to the temp dir: path_provider is mocked and the
  // request is answered by an interceptor (URL + error mapping, plus a happy
  // path with an in-memory stream body).
  group('downloadReportPdf', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('sup_reports_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/path_provider'), null);
        await tmp.delete(recursive: true);
      });
    });

    test('requests the pdf URL with the string id', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        _fail(
            o,
            h,
            404,
            ResponseBody.fromBytes(
                utf8.encode(jsonEncode({'code': 'MONTHLY_REPORT_NOT_FOUND'})),
                404));
      });
      await expectLater(
          ds.downloadReportPdf('3f2b8c1e-0000-4000-8000-000000000001'),
          throwsA(isA<ServerException>()));
      expect(uri.path,
          '/api/v1/monthly-reports/3f2b8c1e-0000-4000-8000-000000000001/pdf');
    });

    test('error body as JSON bytes keeps code and message', () async {
      final ds = _ds((o, h) => _fail(
            o,
            h,
            400,
            ResponseBody.fromBytes(
              utf8.encode(jsonEncode({
                'code': 'REPORT_PDF_NOT_GENERATED',
                'message': 'Not generated',
                'details': {'x': 1},
              })),
              400,
            ),
          ));
      await expectLater(
        ds.downloadReportPdf('abc'),
        throwsA(isA<ServerException>()
            .having((e) => e.errorCode, 'errorCode', 'REPORT_PDF_NOT_GENERATED')
            .having((e) => e.message, 'message', 'Not generated')),
      );
    });

    test('403 keeps the AuthException mapping', () async {
      final ds = _ds((o, h) => _fail(
            o,
            h,
            403,
            ResponseBody.fromBytes(
              utf8.encode(jsonEncode(
                  {'code': 'GUARD_CLUB_SCOPE_REQUIRED', 'message': 'Scope'})),
              403,
            ),
          ));
      await expectLater(
        ds.downloadReportPdf('abc'),
        throwsA(isA<AuthException>().having(
            (e) => e.errorCode, 'errorCode', 'GUARD_CLUB_SCOPE_REQUIRED')),
      );
    });

    test('undecodable error body becomes a plain exception', () async {
      final ds = _ds((o, h) => _fail(
          o, h, 500, ResponseBody.fromBytes(Uint8List.fromList([1, 2]), 500)));
      await expectLater(
          ds.downloadReportPdf('abc'), throwsA(isA<AppException>()));
    });

    test('writes the file named by Content-Disposition; rejects empty',
        () async {
      Response<ResponseBody> ok(RequestOptions o, List<int> bytes) =>
          Response<ResponseBody>(
            requestOptions: o,
            statusCode: 200,
            headers: Headers.fromMap({
              'content-disposition': [
                'attachment; filename="informe-club.pdf"'
              ],
            }),
            data: ResponseBody.fromBytes(bytes, 200, headers: {
              'content-disposition': [
                'attachment; filename="informe-club.pdf"'
              ],
            }),
          );

      final good = _ds((o, h) => h.resolve(ok(o, [37, 80, 68, 70])));
      final path = await good.downloadReportPdf('abc');
      expect(path, '${tmp.path}/informe-club.pdf');
      expect(File(path).lengthSync(), 4);

      final empty = _ds((o, h) => h.resolve(ok(o, [])));
      await expectLater(
          empty.downloadReportPdf('abc'),
          throwsA(isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode', 'REPORT_PDF_EMPTY')));
    });
  });
}
