import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_folders_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_folders_repository_impl.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';

SupervisionFoldersRemoteDataSourceImpl _ds(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionFoldersRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

SupervisionFoldersRemoteDataSourceImpl _returning(int status, Object body) =>
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

/// Captures the request and answers with [status].
({SupervisionFoldersRemoteDataSourceImpl ds, RequestOptions Function() req})
    _capturing(int status, [Object body = const {'data': {}}]) {
  late RequestOptions captured;
  final ds = _ds((o, h) {
    captured = o;
    h.resolve(
        Response<Object>(requestOptions: o, statusCode: status, data: body));
  });
  return (ds: ds, req: () => captured);
}

void main() {
  group('queue', () {
    test('sends params and reads the nested data.data paging', () async {
      late Uri uri;
      final ds = _ds((o, h) {
        uri = o.uri;
        h.resolve(Response<Object>(requestOptions: o, statusCode: 200, data: {
          'status': 'success',
          'data': {
            'data': [
              {'annual_folder_id': 'f1', 'club_name': 'Orion'},
            ],
            'total': 30,
            'page': 2,
            'limit': 25,
          },
        }));
      });
      final page = await ds.getQueue(
        filter: SupervisionFolderQueueFilter.evaluated,
        page: 2,
        limit: 25,
      );
      expect(uri.path, '/api/v1/annual-folders/evaluation/queue');
      expect(uri.queryParameters,
          {'status': 'evaluated', 'page': '2', 'limit': '25'});
      expect(page.items.single.id, 'f1');
      expect(page.items.single.clubName, 'Orion');
      expect(page.total, 30);
      expect(page.page, 2);
    });

    test('defaults to needs_review, page 1, limit 25; 201 accepted', () async {
      final c = _capturing(201, {
        'data': {'data': [], 'total': 0}
      });
      await c.ds.getQueue();
      expect(c.req().uri.queryParameters,
          {'status': 'needs_review', 'page': '1', 'limit': '25'});
    });

    test('non-2xx without error status is a ServerException', () async {
      final c = _capturing(204, {});
      await expectLater(c.ds.getQueue(), throwsA(isA<ServerException>()));
    });
  });

  group('folder detail', () {
    test('GET unwraps the envelope', () async {
      final c = _capturing(200, {
        'status': 'success',
        'data': {
          'annual_folder_id': 'f1',
          'status': 'submitted',
          'sections': [
            {'section_id': 's1', 'order': 1},
          ],
        },
      });
      final d = await c.ds.getFolder('f1');
      expect(c.req().method, 'GET');
      expect(c.req().uri.path, '/api/v1/annual-folders/f1');
      expect(d.status, SupervisionFolderStatus.submitted);
      expect(d.sections.single.id, 's1');
    });

    test('unparsable body is a ServerException', () async {
      final c = _capturing(200, {'data': 'nope'});
      await expectLater(c.ds.getFolder('f1'), throwsA(isA<ServerException>()));
    });
  });

  group('actions', () {
    test('evaluate posts points and notes', () async {
      final c = _capturing(201);
      await c.ds.evaluateSection('f1', 's1', earnedPoints: 7, notes: ' ok ');
      expect(c.req().method, 'POST');
      expect(
          c.req().uri.path, '/api/v1/annual-folders/f1/sections/s1/evaluate');
      expect(c.req().data, {'earned_points': 7, 'notes': 'ok'});
    });

    test('evaluate omits blank or null notes', () async {
      final c = _capturing(201);
      await c.ds.evaluateSection('f1', 's1', earnedPoints: 0, notes: '   ');
      expect(c.req().data, {'earned_points': 0});
      await c.ds.evaluateSection('f1', 's1', earnedPoints: 3);
      expect(c.req().data, {'earned_points': 3});
    });

    test('reopen posts without body', () async {
      final c = _capturing(201);
      await c.ds.reopenSection('f1', 's1');
      expect(c.req().method, 'POST');
      expect(c.req().uri.path, '/api/v1/annual-folders/f1/sections/s1/reopen');
      expect(c.req().data, isNull);
    });

    test('confirm-union maps approve to the decision', () async {
      final c = _capturing(201);
      await c.ds.confirmUnion('f1', 's1', approve: true);
      expect(c.req().uri.path,
          '/api/v1/annual-folders/f1/sections/s1/confirm-union');
      expect(c.req().data, {'decision': 'APPROVED'});
      await c.ds.confirmUnion('f1', 's1', approve: false, notes: ' why ');
      expect(c.req().data, {'decision': 'REJECTED_OVERRIDE', 'notes': 'why'});
    });

    test('close posts without body', () async {
      final c = _capturing(201, {'annual_folder_id': 'f1'});
      await c.ds.closeFolder('f1');
      expect(c.req().method, 'POST');
      expect(c.req().uri.path, '/api/v1/annual-folders/f1/close');
      expect(c.req().data, isNull);
    });

    test('reviewer note PATCH sends the note, 200 accepted', () async {
      final c = _capturing(200);
      await c.ds.saveReviewerNote('e1', ' hello ');
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path,
          '/api/v1/annual-folders/evidences/e1/reviewer-note');
      expect(c.req().data, {'reviewer_note': 'hello'});
    });

    test('reviewer note is null when blank or null', () async {
      final c = _capturing(200);
      await c.ds.saveReviewerNote('e1', '   ');
      expect(c.req().data, {'reviewer_note': null});
      await c.ds.saveReviewerNote('e1', null);
      expect(c.req().data, {'reviewer_note': null});
    });
  });

  group('errors', () {
    test('403 read maps to AuthException recognized as forbidden', () async {
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
      await expectLater(ds.getFolder('f'), throwsA(isA<AuthException>()));
    });

    for (final c in const [
      (404, 'ANNUAL_FOLDER_NOT_FOUND'),
      (404, 'ANNUAL_FOLDER_SECTION_NOT_IN_TEMPLATE'),
      (404, 'ANNUAL_FOLDER_EVIDENCE_NOT_FOUND'),
      (400, 'ANNUAL_FOLDER_STATUS_INVALID_FOR_EVALUATE'),
      (400, 'ANNUAL_FOLDER_STATUS_INVALID_FOR_REOPEN'),
      (400, 'ANNUAL_FOLDER_EARNED_POINTS_EXCEED_MAX'),
      (400, 'ANNUAL_FOLDER_SECTION_PENDING'),
      (400, 'ANNUAL_FOLDER_SECTION_TERMINAL'),
      (400, 'ANNUAL_FOLDER_SECTION_NOT_REOPENABLE'),
      (400, 'ANNUAL_FOLDER_UNION_CONFIRMATION_NOT_REQUIRED'),
      (400, 'ANNUAL_FOLDER_SECTION_NOT_PREAPPROVED'),
      (400, 'ANNUAL_FOLDER_SECTION_MISSING_LF_DATA'),
      (409, 'ANNUAL_FOLDER_STATUS_CONFLICT'),
    ]) {
      test('${c.$2} (${c.$1}) surfaces code and message', () async {
        final ds = _returning(c.$1, {'code': c.$2, 'message': 'msg ${c.$2}'});
        await expectLater(
          ds.evaluateSection('f', 's', earnedPoints: 1),
          throwsA(isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode', c.$2)
              .having((e) => e.message, 'message', 'msg ${c.$2}')
              .having((e) => e.code, 'code', c.$1)),
        );
      });
    }

    for (final code in const [
      'ANNUAL_FOLDER_EVIDENCE_TERRITORY_DENIED',
      'ANNUAL_FOLDER_FOLDER_ACCESS_DENIED',
      'ANNUAL_FOLDER_EVIDENCE_ACCESS_DENIED',
      'ANNUAL_FOLDER_UNION_ROLE_REQUIRED',
      'ADMIN_USER_SCOPE_MISSING',
    ]) {
      test('403 $code surfaces its code on an action', () async {
        final ds = _returning(403, {'code': code, 'message': 'denied'});
        await expectLater(
          ds.confirmUnion('f', 's', approve: true),
          throwsA(isA<AuthException>()
              .having((e) => e.errorCode, 'errorCode', code)
              .having((e) => e.message, 'message', 'denied')),
        );
      });
    }

    test('repository maps failures and success', () async {
      final fail = SupervisionFoldersRepositoryImpl(
          remoteDataSource: _returning(409, {
        'code': 'ANNUAL_FOLDER_STATUS_CONFLICT',
        'message': 'stale',
      }));
      (await fail.closeFolder('f')).fold(
        (f) {
          expect(f, isA<ServerFailure>());
          expect(f.errorCode, 'ANNUAL_FOLDER_STATUS_CONFLICT');
          expect(f.message, 'stale');
        },
        (_) => fail_('expected failure'),
      );

      final forbidden = SupervisionFoldersRepositoryImpl(
          remoteDataSource:
              _returning(403, {'code': 'GUARD_PERMISSION_DENIED'}));
      (await forbidden.getQueue()).fold(
        (f) {
          expect(f, isA<AuthFailure>());
          expect(isForbiddenFailure(f), isTrue);
        },
        (_) => fail_('expected failure'),
      );
      (await forbidden.getFolder('f')).fold(
        (f) => expect(isForbiddenFailure(f), isTrue),
        (_) => fail_('expected failure'),
      );

      final ok = SupervisionFoldersRepositoryImpl(
          remoteDataSource: _returning(201, {'data': {}}));
      expect((await ok.reopenSection('f', 's')).isRight(), isTrue);
      expect((await ok.saveReviewerNote('e', null)).isRight(), isTrue);
    });
  });
}

void fail_(String m) => fail(m);
