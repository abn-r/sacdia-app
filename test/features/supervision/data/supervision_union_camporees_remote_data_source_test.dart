import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/features/supervision/data/datasources/supervision_union_camporees_remote_data_source.dart';
import 'package:sacdia_app/features/supervision/data/repositories/supervision_union_camporees_repository_impl.dart';

typedef _Handler = void Function(RequestOptions, RequestInterceptorHandler);

SupervisionUnionCamporeesRemoteDataSourceImpl _ds(_Handler onRequest) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return SupervisionUnionCamporeesRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

void _answer(
    RequestOptions o, RequestInterceptorHandler h, int status, Object? body) {
  final res =
      Response<Object?>(requestOptions: o, statusCode: status, data: body);
  if (status >= 400) {
    h.reject(DioException(
        requestOptions: o, response: res, type: DioExceptionType.badResponse));
  } else {
    h.resolve(res);
  }
}

SupervisionUnionCamporeesRemoteDataSourceImpl _returning(
        int status, Object body) =>
    _ds((o, h) => _answer(o, h, status, body));

({
  SupervisionUnionCamporeesRemoteDataSourceImpl ds,
  RequestOptions Function() req
}) _capturing(int status, [Object body = const {}]) {
  late RequestOptions captured;
  final ds = _ds((o, h) {
    captured = o;
    _answer(o, h, status, body);
  });
  return (ds: ds, req: () => captured);
}

const _pendingBody = {
  'clubs': [
    {'camporee_club_id': 1},
    {'camporee_club_id': 2},
  ],
  'members': [
    {
      'camporee_member_id': 10,
      'club_name': 'Orión',
      'users': {'name': 'Ana'},
    },
  ],
  'payments': [
    {'camporee_payment_id': 'p1', 'amount': '10.00'},
  ],
};

const _clubsBody = [
  {
    'camporee_club_id': 1,
    'club_sections': {
      'club_types': {'name': 'Aventureros'},
      'clubs': {'name': 'Sol'},
    },
  },
];

void main() {
  group('list', () {
    test('sends only active, page and limit', () async {
      final c = _capturing(200, {
        'data': [
          {'union_camporee_id': 1, 'name': 'A'},
        ],
        'meta': {'page': 1, 'total': 1},
      });
      final items = await c.ds.getCamporees();
      expect(c.req().method, 'GET');
      expect(c.req().uri.path, '/api/v1/camporees/union');
      expect(c.req().uri.queryParameters,
          {'active': 'true', 'page': '1', 'limit': '100'});
      expect(items.single.id, 1);
    });

    test('non-2xx without error status is a ServerException', () async {
      final c = _capturing(204, {});
      await expectLater(c.ds.getCamporees(), throwsA(isA<ServerException>()));
    });
  });

  group('detail', () {
    test('reads the bare object', () async {
      final c = _capturing(200, {'union_camporee_id': 4, 'name': 'X'});
      final item = await c.ds.getCamporee(4);
      expect(c.req().uri.path, '/api/v1/camporees/union/4');
      expect(item.id, 4);
      expect(item.name, 'X');
    });

    test('unparsable body is a ServerException', () async {
      final c = _capturing(200, {'name': 'no id'});
      await expectLater(c.ds.getCamporee(4), throwsA(isA<ServerException>()));
    });

    test('404 keeps the business code', () async {
      final ds = _returning(404, {
        'code': 'CAMPOREE_UNION_CAMPOREE_NOT_FOUND',
        'message': 'nf',
      });
      await expectLater(
        ds.getCamporee(4),
        throwsA(isA<ServerException>()
            .having((e) => e.errorCode, 'errorCode',
                'CAMPOREE_UNION_CAMPOREE_NOT_FOUND')
            .having((e) => e.code, 'code', 404)),
      );
    });
  });

  group('getPending', () {
    test('merges club names from /clubs and sends only status', () async {
      final seen = <RequestOptions>[];
      final ds = _ds((o, h) {
        seen.add(o);
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 200, _pendingBody);
        } else {
          _answer(o, h, 200, _clubsBody);
        }
      });
      final p = await ds.getPending(5);
      final paths = seen.map((e) => e.uri.path).toSet();
      expect(paths, {
        '/api/v1/camporees/union/5/pending',
        '/api/v1/camporees/union/5/clubs',
      });
      final clubsReq = seen.firstWhere((e) => e.uri.path.endsWith('/clubs'));
      expect(clubsReq.uri.queryParameters, {'status': 'pending_approval'});
      expect(p.clubs.map((e) => e.id), [1]);
      expect(p.clubs.single.clubName, 'Sol');
      expect(p.clubs.single.sectionName, 'Aventureros');
      expect(p.members.single.fullName, 'Ana');
      expect(p.payments.single.amount, 10.0);
    });

    test('falls back to /pending clubs when /clubs fails with 403', () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 200, _pendingBody);
        } else {
          _answer(o, h, 403, {'code': 'GUARD_PERMISSION_DENIED'});
        }
      });
      final p = await ds.getPending(5);
      expect(p.clubs.map((e) => e.id), [1, 2]);
      expect(p.clubs.every((e) => e.clubName.isEmpty), isTrue);
      expect(p.members.length, 1);
    });

    test('falls back when /clubs answers a non-2xx without error status',
        () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 200, _pendingBody);
        } else {
          _answer(o, h, 204, null);
        }
      });
      final p = await ds.getPending(5);
      expect(p.clubs.length, 2);
    });

    test('rethrows when /clubs is an authorization-stale rejection', () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 200, _pendingBody);
        } else {
          _answer(o, h, 403, {'code': 'AUTHORIZATION_STALE', 'message': 's'});
        }
      });
      await expectLater(
        ds.getPending(5),
        throwsA(isA<AuthException>()
            .having((e) => e.errorCode, 'errorCode', 'AUTHORIZATION_STALE')),
      );
    });

    test('rethrows a cancellation of /clubs', () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 200, _pendingBody);
        } else {
          h.reject(
              DioException(requestOptions: o, type: DioExceptionType.cancel));
        }
      });
      await expectLater(
        ds.getPending(5),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)),
      );
    });

    test('fails when /pending fails, even if /clubs works', () async {
      final ds = _ds((o, h) {
        if (o.uri.path.endsWith('/pending')) {
          _answer(o, h, 403, {
            'code': 'GUARD_CLUB_SCOPE_REQUIRED',
            'message': 'no',
          });
        } else {
          _answer(o, h, 200, _clubsBody);
        }
      });
      await expectLater(
        ds.getPending(5),
        throwsA(isA<AuthException>().having(
            (e) => e.errorCode, 'errorCode', 'GUARD_CLUB_SCOPE_REQUIRED')),
      );
    });

    test('fails when both fail and does not leak an unhandled error', () async {
      final ds = _returning(500, {'code': 'X', 'message': 'm'});
      await expectLater(ds.getPending(5), throwsA(isA<ServerException>()));
    });
  });

  group('decisions', () {
    test('club approve PATCHes the exact path with no body', () async {
      final c = _capturing(200, {'camporee_club_id': 3});
      await c.ds.decideClub(5, 3, approve: true, reason: 'ignored');
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/camporees/union/5/clubs/3/approve');
      expect(c.req().data, isNull);
    });

    test('club reject sends only the trimmed rejection_reason', () async {
      final c = _capturing(200);
      await c.ds.decideClub(5, 3, approve: false, reason: ' no cupo ');
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/camporees/union/5/clubs/3/reject');
      expect(c.req().data, {'rejection_reason': 'no cupo'});
    });

    test('reject with blank or null reason sends no body', () async {
      final c = _capturing(200);
      await c.ds.decideMember(5, 8, approve: false, reason: '   ');
      expect(c.req().uri.path, '/api/v1/camporees/union/5/members/8/reject');
      expect(c.req().data, isNull);
      await c.ds.decideMember(5, 8, approve: false);
      expect(c.req().data, isNull);
    });

    test('member approve path', () async {
      final c = _capturing(201);
      await c.ds.decideMember(5, 8, approve: true);
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/camporees/union/5/members/8/approve');
      expect(c.req().data, isNull);
    });

    test('payment paths do not include the camporee id', () async {
      final c = _capturing(200);
      await c.ds.decidePayment('uuid-1', approve: true);
      expect(c.req().method, 'PATCH');
      expect(c.req().uri.path, '/api/v1/camporees/payments/uuid-1/approve');
      expect(c.req().data, isNull);
      await c.ds.decidePayment('uuid-1', approve: false, reason: 'x');
      expect(c.req().uri.path, '/api/v1/camporees/payments/uuid-1/reject');
      expect(c.req().data, {'rejection_reason': 'x'});
    });

    test('non-2xx without error status is a ServerException', () async {
      final c = _capturing(204);
      await expectLater(c.ds.decideClub(1, 1, approve: true),
          throwsA(isA<ServerException>()));
    });
  });

  group('errors', () {
    for (final c in const [
      (404, 'CAMPOREE_CLUB_ENROLLMENT_PENDING_NOT_FOUND'),
      (404, 'CAMPOREE_MEMBER_ENROLLMENT_PENDING_NOT_FOUND'),
      (404, 'CAMPOREE_PAYMENT_PENDING_NOT_FOUND'),
      (404, 'CAMPOREE_PAYMENT_NOT_FOUND'),
      (400, 'CAMPOREE_CLUB_REGISTRATION_CLOSED'),
    ]) {
      test('${c.$2} (${c.$1}) surfaces code and message', () async {
        final ds = _returning(c.$1, {'code': c.$2, 'message': 'msg ${c.$2}'});
        await expectLater(
          ds.decideClub(1, 1, approve: true),
          throwsA(isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode', c.$2)
              .having((e) => e.message, 'message', 'msg ${c.$2}')
              .having((e) => e.code, 'code', c.$1)),
        );
      });
    }

    for (final code in const [
      'GUARD_CLUB_SCOPE_REQUIRED',
      'GUARD_PERMISSION_DENIED',
    ]) {
      test('403 $code maps to a forbidden AuthException', () async {
        final ds = _returning(403, {'code': code, 'message': 'denied'});
        await expectLater(
          ds.decidePayment('p', approve: false),
          throwsA(isA<AuthException>()
              .having((e) => e.errorCode, 'errorCode', code)
              .having((e) => isForbiddenFailure(e), 'forbidden', isTrue)),
        );
        await expectLater(ds.getCamporees(), throwsA(isA<AuthException>()));
      });
    }
  });

  group('repository', () {
    test('maps failures keeping the code, and success to unit', () async {
      final fail = SupervisionUnionCamporeesRepositoryImpl(
          remoteDataSource: _returning(404, {
        'code': 'CAMPOREE_PAYMENT_PENDING_NOT_FOUND',
        'message': 'gone',
      }));
      final left = await fail.decidePayment('p', approve: true);
      expect(left.isLeft(), isTrue);
      left.fold((f) {
        expect(f.errorCode, 'CAMPOREE_PAYMENT_PENDING_NOT_FOUND');
        expect(f.message, 'gone');
      }, (_) => fail_('expected failure'));

      final ok = SupervisionUnionCamporeesRepositoryImpl(
          remoteDataSource: _returning(200, {}));
      expect((await ok.decideClub(1, 2, approve: true)).isRight(), isTrue);
      expect((await ok.decideMember(1, 2, approve: false)).isRight(), isTrue);
    });

    test('read methods map forbidden', () async {
      final repo = SupervisionUnionCamporeesRepositoryImpl(
          remoteDataSource:
              _returning(403, {'code': 'GUARD_CLUB_SCOPE_REQUIRED'}));
      (await repo.getCamporees()).fold(
        (f) => expect(isForbiddenFailure(f), isTrue),
        (_) => fail_('expected failure'),
      );
      (await repo.getPending(1)).fold(
        (f) => expect(f.errorCode, 'GUARD_CLUB_SCOPE_REQUIRED'),
        (_) => fail_('expected failure'),
      );
    });
  });
}

Never fail_(String message) => throw TestFailure(message);
