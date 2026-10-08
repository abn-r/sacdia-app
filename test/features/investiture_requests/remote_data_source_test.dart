import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/investiture_requests/data/datasources/investiture_requests_remote_data_source.dart';
import 'package:sacdia_app/features/investiture_requests/data/investiture_request_error_keys.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_resolution.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';

const _base = 'https://api.test/api/v1';

Map<String, dynamic> _person({String id = 'p1', String status = 'PENDING'}) => {
      'person_id': id,
      'user_id': 'u1',
      'user_name': 'Ana',
      'class_id': 3,
      'class_name': 'Amigo',
      'section_name': 'Conquistadores',
      'enrollment_id': 11,
      'investiture_date': '2026-11-15',
      'status': status,
      'can_authorize': true,
    };

Map<String, dynamic> _request() => {
      'request_id': 'r1',
      'club_section_id': 4,
      'ecclesiastical_year_id': 9,
      'people': [_person()],
    };

/// Devuelve un datasource cuyo Dio responde con [respond] y captura la petición.
({InvestitureRequestsRemoteDataSourceImpl ds, List<RequestOptions> calls})
    _build(Response<dynamic> Function(RequestOptions) respond) {
  final calls = <RequestOptions>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        calls.add(options);
        final response = respond(options);
        final status = response.statusCode ?? 200;
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
  return (
    ds: InvestitureRequestsRemoteDataSourceImpl(dio: dio, baseUrl: _base),
    calls: calls,
  );
}

Response<dynamic> _ok(RequestOptions o, Object? data, {int status = 200}) =>
    Response<dynamic>(requestOptions: o, statusCode: status, data: data);

/// Dio que falla con un error ajeno a Dio (no llega a la red).
class _BrokenDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('raw internal detail');
}

void main() {
  group('InvestitureRequestsRemoteDataSourceImpl', () {
    test('presentationContext calls the exact route and unwraps data',
        () async {
      final t = _build(
        (o) => _ok(o, {
          'status': 'success',
          'data': {
            'club_section_id': 4,
            'ecclesiastical_year_id': 9,
            'window': {
              'start_date': '2026-10-01',
              'end_date': '2026-12-20',
              'open_today': true,
              'time_zone_invalid': false,
            },
            'year_open': true,
            'open_request_id': null,
            'candidates': <dynamic>[],
          },
        }),
      );

      final ctx = await t.ds.getPresentationContext(4, 9);

      expect(t.calls.single.method, 'GET');
      expect(
        t.calls.single.path,
        '$_base/club-sections/4/investiture-requests/presentation-context',
      );
      expect(t.calls.single.queryParameters, {'ecclesiastical_year_id': 9});
      expect(ctx.window.openToday, isTrue);
    });

    test('present sends the exact body to the exact route', () async {
      final t = _build((o) =>
          _ok(o, {'status': 'success', 'data': _request()}, status: 201));

      final req = await t.ds.present(
        sectionId: 4,
        yearId: 9,
        investitureDate: DateTime(2026, 11, 5),
        enrollmentIds: const [11, 12],
      );

      final call = t.calls.single;
      expect(call.method, 'POST');
      expect(call.path, '$_base/club-sections/4/investiture-requests');
      expect(call.data, {
        'ecclesiastical_year_id': 9,
        'investiture_date': '2026-11-05',
        'enrollment_ids': [11, 12],
      });
      expect(req.requestId, 'r1');
      expect(req.people.single.status, PersonStatus.pending);
    });

    test('getSectionRequest returns null when data is null', () async {
      final t = _build((o) => _ok(o, {'status': 'success', 'data': null}));
      final req = await t.ds.getSectionRequest(4, 9);
      expect(req, isNull);
      expect(
          t.calls.single.path, '$_base/club-sections/4/investiture-requests');
      expect(t.calls.single.queryParameters, {'ecclesiastical_year_id': 9});
    });

    test('addPeople, removePerson and changeDates hit their routes', () async {
      final t = _build((o) {
        if (o.method == 'DELETE') {
          return _ok(o, {'status': 'success', 'data': _person()});
        }
        return _ok(o, {'status': 'success', 'data': _request()});
      });

      await t.ds.addPeople(
        requestId: 'r1',
        investitureDate: DateTime(2026, 11, 5),
        enrollmentIds: const [13],
      );
      await t.ds.removePerson(requestId: 'r1', personId: 'p1');
      await t.ds.changeDates(
        requestId: 'r1',
        investitureDate: DateTime(2026, 11, 20),
        personIds: const ['p1', 'p2'],
      );

      expect(t.calls[0].method, 'POST');
      expect(t.calls[0].path, '$_base/investiture-requests/r1/people');
      expect(t.calls[0].data, {
        'investiture_date': '2026-11-05',
        'enrollment_ids': [13],
      });
      expect(t.calls[1].method, 'DELETE');
      expect(t.calls[1].path, '$_base/investiture-requests/r1/people/p1');
      expect(t.calls[2].method, 'PATCH');
      expect(t.calls[2].path, '$_base/investiture-requests/r1/dates');
      expect(t.calls[2].data, {
        'investiture_date': '2026-11-20',
        'person_ids': ['p1', 'p2'],
      });
    });

    test('a 409 INVESTITURE_REQUEST_STALE maps to the translated message',
        () async {
      final t = _build(
        (o) => _ok(
          o,
          {
            'statusCode': 409,
            'code': 'INVESTITURE_REQUEST_STALE',
            'message': 'texto crudo del servidor',
          },
          status: 409,
        ),
      );

      await expectLater(
        t.ds.present(
          sectionId: 4,
          yearId: 9,
          investitureDate: DateTime(2026, 11, 5),
          enrollmentIds: const [11],
        ),
        throwsA(
          isA<ServerException>()
              .having(
                (e) => e.message,
                'message',
                tr('investiture_requests.errors.stale'),
              )
              .having((e) => e.code, 'code', 409),
        ),
      );
    });

    test('a 403 maps to AuthException', () async {
      final t = _build(
        (o) => _ok(
          o,
          {'code': 'INVESTITURE_REQUEST_FORBIDDEN', 'message': 'Forbidden'},
          status: 403,
        ),
      );
      await expectLater(
        t.ds.getPresentationContext(4, 9),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            tr('investiture_requests.errors.forbidden'),
          ),
        ),
      );
    });

    test('the backend error code travels on the exception', () async {
      final forbidden = _build(
        (o) => _ok(
          o,
          {'code': 'INVESTITURE_REQUEST_FORBIDDEN', 'message': 'Forbidden'},
          status: 403,
        ),
      );
      await expectLater(
        forbidden.ds.getPresentationContext(4, 9),
        throwsA(
          isA<AuthException>().having(
              (e) => e.errorCode, 'errorCode', 'INVESTITURE_REQUEST_FORBIDDEN'),
        ),
      );
      final closed = _build(
        (o) => _ok(
          o,
          {'code': 'INVESTITURE_REQUEST_WINDOW_CLOSED', 'message': 'x'},
          status: 409,
        ),
      );
      await expectLater(
        closed.ds.getPresentationContext(4, 9),
        throwsA(
          isA<ServerException>().having(
            (e) => e.errorCode,
            'errorCode',
            'INVESTITURE_REQUEST_WINDOW_CLOSED',
          ),
        ),
      );
    });

    test('an unknown code falls back to the server message', () async {
      final t = _build(
        (o) => _ok(
          o,
          {'code': 'SOMETHING_NEW', 'message': 'mensaje del servidor'},
          status: 400,
        ),
      );
      await expectLater(
        t.ds.getPresentationContext(4, 9),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'mensaje del servidor'),
        ),
      );
    });

    test('an unexpected error never leaks its raw text', () async {
      final ds = InvestitureRequestsRemoteDataSourceImpl(
        dio: _BrokenDio(),
        baseUrl: _base,
      );
      await expectLater(
        ds.getPresentationContext(4, 9),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            tr('investiture_requests.errors.generic'),
          ),
        ),
      );
    });

    test('own history unwraps a list inside data', () async {
      final t = _build(
        (o) => _ok(o, {
          'status': 'success',
          'data': [
            {
              'person_id': 'p1',
              'user_id': 'u1',
              'class_id': 3,
              'club_section_id': 4,
              'ecclesiastical_year_id': 9,
              'investiture_date': '2026-11-15',
              'status': 'INVESTED',
              'person_text': null,
            },
          ],
        }),
      );
      final list = await t.ds.getOwnHistory();
      expect(t.calls.single.path, '$_base/investiture-history');
      expect(list.single.status, PersonStatus.invested);
    });

    test('section history and yearbook use section routes', () async {
      final t = _build((o) {
        if (o.path.endsWith('/investiture-yearbook')) {
          return _ok(o, {
            'status': 'success',
            'data': {
              'club_section_id': 4,
              'entries': [
                {
                  'enrollment_id': 11,
                  'user_id': 'u1',
                  'class_id': 3,
                  'class_name': 'Amigo',
                  'ecclesiastical_year_id': 9,
                },
              ],
            },
          });
        }
        return _ok(o, {'status': 'success', 'data': <dynamic>[]});
      });

      final history = await t.ds.getSectionHistory(4);
      final yearbook = await t.ds.getSectionYearbook(4);

      expect(t.calls[0].path, '$_base/club-sections/4/investiture-history');
      expect(t.calls[1].path, '$_base/club-sections/4/investiture-yearbook');
      expect(history, isEmpty);
      expect(yearbook.single.className, 'Amigo');
    });

    test('authorizer list and read use the authorizer routes', () async {
      final t = _build((o) {
        if (o.path.endsWith('/investiture-requests')) {
          return _ok(o, {
            'status': 'success',
            'data': [_request()],
          });
        }
        return _ok(o, {'status': 'success', 'data': _request()});
      });

      final list = await t.ds.listForAuthorizer(9);
      final one = await t.ds.readForAuthorizer('r1');

      expect(t.calls[0].method, 'GET');
      expect(t.calls[0].path, '$_base/investiture-requests');
      expect(t.calls[0].queryParameters, {'ecclesiastical_year_id': 9});
      expect(list.single.requestId, 'r1');
      expect(t.calls[1].path, '$_base/investiture-requests/r1');
      expect(one.people.single.canAuthorize, isTrue);
    });

    test('resolve sends invest/reject decisions and parses the view', () async {
      final t = _build(
        (o) => _ok(
          o,
          {
            'status': 'success',
            'data': {
              'request_id': 'r1',
              'invested': [_person(status: 'INVESTED')],
              'rejected_by_person': [
                _person(id: 'p2', status: 'REJECTED_BY_PERSON')
              ],
              'rejected_by_system': <dynamic>[],
              'retired': <dynamic>[],
              'blocked': [
                {'person_id': 'p3', 'code': 'INVESTITURE_REQUEST_NOT_PENDING'},
              ],
              'already_resolved': [
                {'person_id': 'p4', 'status': 'INVESTED'},
              ],
            },
          },
          status: 201,
        ),
      );

      final result = await t.ds.resolve(
        requestId: 'r1',
        invest: const [
          InvestDecision(personId: 'p1'),
          InvestDecision(personId: 'p5', comment: 'Bien'),
        ],
        reject: const [
          RejectDecision(personId: 'p2', reason: 'Faltan evidencias'),
        ],
      );

      final call = t.calls.single;
      expect(call.method, 'POST');
      expect(call.path, '$_base/investiture-requests/r1/resolutions');
      expect(call.data, {
        'invest': [
          {'person_id': 'p1'},
          {'person_id': 'p5', 'comment': 'Bien'},
        ],
        'reject': [
          {'person_id': 'p2', 'reason': 'Faltan evidencias'},
        ],
      });
      expect(result.invested.single.status, PersonStatus.invested);
      expect(result.rejectedByPerson.single.personId, 'p2');
      expect(result.blocked.single.code, 'INVESTITURE_REQUEST_NOT_PENDING');
      expect(result.alreadyResolved.single.personId, 'p4');
    });
  });

  group('error keys', () {
    const codes = [
      'INVESTITURE_REQUEST_FORBIDDEN',
      'INVESTITURE_REQUEST_STALE',
      'INVESTITURE_REQUEST_ACTIVE_EXISTS',
      'INVESTITURE_REQUEST_ALREADY_INVESTED',
      'INVESTITURE_REQUEST_LEGACY_PIPELINE_ACTIVE',
      'INVESTITURE_REQUEST_CLASS_NOT_ELIGIBLE',
      'INVESTITURE_REQUEST_NOT_ELIGIBLE',
      'INVESTITURE_REQUEST_OUTSIDE_SECTION',
      'INVESTITURE_REQUEST_WINDOW_CLOSED',
      'INVESTITURE_REQUEST_YEAR_CLOSED',
      'INVESTITURE_REQUEST_DATE_OUTSIDE_WINDOW',
      'INVESTITURE_REQUEST_PROGRESS_LOCKED',
      'INVESTITURE_REQUEST_TIME_ZONE_INVALID',
      'INVESTITURE_DURATION_MIN_NOT_MET',
      'INVESTITURE_DURATION_EXPIRED',
    ];

    test('every code maps to a key that exists in the four languages', () {
      for (final lang in ['es', 'en', 'fr', 'pt-BR']) {
        final json = jsonDecode(
          File('assets/translations/$lang.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        for (final code in codes) {
          final key = investitureRequestErrorKey(code);
          expect(key, isNotNull, reason: code);
          final parts = key!.split('.');
          dynamic node = json;
          for (final p in parts) {
            node = (node as Map<String, dynamic>)[p];
          }
          expect(node, isA<String>(), reason: '$lang:$key');
        }
      }
    });

    test('unknown or null codes map to null', () {
      expect(investitureRequestErrorKey('NOPE'), isNull);
      expect(investitureRequestErrorKey(null), isNull);
    });

    test('es texts come from the backend catalog', () {
      final es = jsonDecode(
        File('assets/translations/es.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final errors = (es['investiture_requests'] as Map)['errors'] as Map;
      expect(
        errors['stale'],
        'Esta solicitud ya no es la activa de la sección. Hay que volver a cargar el listado',
      );
    });
  });
}
