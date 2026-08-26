import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/camporees/data/datasources/camporees_remote_data_source.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_member_model.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_submission.dart';

// ── Fake HttpClientAdapter ────────────────────────────────────────────────────

/// Minimal fake adapter that returns a pre-configured [ResponseBody].
///
/// Captures the last [RequestOptions] so tests can assert on query params,
/// path, etc.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

/// Creates a [Dio] instance wired to a fake adapter that will return
/// [statusCode] with [bodyJson] as the response body.
({Dio dio, _FakeAdapter adapter}) _dioWith(
  Map<String, dynamic> bodyJson, {
  int statusCode = 200,
}) {
  final json = jsonEncode(bodyJson);
  final body = ResponseBody.fromString(
    json,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  final adapter = _FakeAdapter(body);
  final dio = Dio(BaseOptions(
    // Disable JSON response type auto-decoding so we can control the data.
    responseType: ResponseType.json,
  ));
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

/// Creates a [Dio] that throws a [DioException] when any request is made.
Dio _dioThatThrows(DioException Function(RequestOptions) exceptionBuilder) {
  final dio = Dio();
  dio.httpClientAdapter = _ThrowingAdapter(exceptionBuilder);
  return dio;
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this._builder);

  final DioException Function(RequestOptions) _builder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw _builder(options);
  }

  @override
  void close({bool force = false}) {}
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _memberJson({
  int id = 1,
  String userId = 'user-001',
  String name = 'Ana Lopez',
}) =>
    {
      'camporee_member_id': id,
      'user_id': userId,
      'users': {
        'user_id': userId,
        'name': name,
        'paternal_last_name': '',
        'maternal_last_name': '',
        'email': 'ana@example.com',
        'user_image': null,
      },
      'club_name': 'Club Orion',
      'insurance_verified': true,
      'active': true,
      'camporee_type': 'CONQUISTADORES',
      'insurance_id': null,
    };

Map<String, dynamic> _metaJson({
  int page = 1,
  int limit = 50,
  int total = 1,
  int totalPages = 1,
  bool hasNextPage = false,
  bool hasPreviousPage = false,
}) =>
    {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };

Map<String, dynamic> _paginatedResponse({
  List<Map<String, dynamic>>? members,
  Map<String, dynamic>? meta,
}) =>
    {
      'data': members ?? [_memberJson()],
      'meta': meta ?? _metaJson(),
    };

Map<String, dynamic> _camporeeJson({
  Object? registrationCost = 125.50,
}) =>
    {
      'local_camporee_id': 10,
      'name': 'Camporee Local',
      'description': 'Camporee de prueba',
      'start_date': '2026-07-01T00:00:00.000Z',
      'end_date': '2026-07-03T00:00:00.000Z',
      'local_camporee_place': 'Campo local',
      'lat': '19.1738',
      'long': '-96.1342',
      'registration_cost': registrationCost,
      'includes_adventurers': true,
      'includes_pathfinders': true,
      'includes_master_guides': false,
      'active': true,
      'local_field_id': 1,
    };

Map<String, dynamic> _sectionRegistrationJson({
  Object? clubSectionId = 44,
}) =>
    {
      'camporeeId': 7,
      'clubId': 12,
      'clubName': 'Orión',
      'clubSectionId': clubSectionId,
      'sectionName': 'Conquistadores',
      'clubTypeId': 2,
      'clubTypeName': 'Conquistadores',
      'status': 'registered',
      'disposition': 'open',
      'canEnroll': false,
      'blockingReason': 'already_enrolled',
      'enrollmentId': 91,
      'registeredAt': '2026-07-13T18:30:00.000Z',
      'registeredBy': {
        'userId': 'director-1',
        'displayName': 'Directora Activa',
      },
    };

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const baseUrl = 'http://localhost:3000';

  group('CamporeesRemoteDataSourceImpl section registration', () {
    test('GET parses direct and data-enveloped contextual responses', () async {
      for (final response in [
        _sectionRegistrationJson(),
        {'data': _sectionRegistrationJson()},
      ]) {
        final (:dio, :adapter) = _dioWith(response);
        final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

        final result = await ds.getActiveSectionRegistration(7);

        expect(
          adapter.lastOptions!.path,
          '$baseUrl/camporees/7/section-registration',
        );
        expect(result.clubSectionId, 44);
        expect(result.status, CamporeeSectionRegistrationStatus.registered);
        expect(result.registeredBy?.displayName, 'Directora Activa');
      }
    });

    test('POST sends no body or client-controlled section and parses response',
        () async {
      final (:dio, :adapter) = _dioWith({
        'data': _sectionRegistrationJson(),
      }, statusCode: 201);
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.registerActiveSection(7);

      expect(
        adapter.lastOptions!.path,
        '$baseUrl/camporees/7/section-registration',
      );
      expect(adapter.lastOptions!.data, isNull);
      expect(result.clubSectionId, 44);
    });

    test('maps malformed contextual payloads to ServerException', () async {
      final (:dio, :adapter) = _dioWith(
        _sectionRegistrationJson(clubSectionId: '44'),
      );
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await expectLater(
        ds.getActiveSectionRegistration(7),
        throwsA(isA<ServerException>()),
      );
      expect(adapter.lastOptions, isNotNull);
    });

    test('preserves auth failures produced by the real ErrorInterceptor',
        () async {
      for (final testCase in const [
        (statusCode: 401, register: false),
        (statusCode: 403, register: true),
      ]) {
        final (:dio, :adapter) = _dioWith({
          'message': 'Context authorization denied',
        }, statusCode: testCase.statusCode);
        dio.interceptors.add(ErrorInterceptor());
        final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

        final request = testCase.register
            ? ds.registerActiveSection(7)
            : ds.getActiveSectionRegistration(7);

        await expectLater(
          request,
          throwsA(
            isA<AuthException>()
                .having((error) => error.code, 'code', testCase.statusCode)
                .having(
                  (error) => error.message,
                  'message',
                  'Context authorization denied',
                ),
          ),
        );
        expect(adapter.lastOptions, isNotNull);
      }
    });

    test('preserves connection failures produced by the real ErrorInterceptor',
        () async {
      final dio = _dioThatThrows(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Network unreachable',
        ),
      );
      dio.interceptors.add(ErrorInterceptor());
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await expectLater(
        ds.getActiveSectionRegistration(7),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('CamporeesRemoteDataSourceImpl.getCamporees', () {
    test('parses string registration_cost returned by backend decimals',
        () async {
      final (:dio, :adapter) = _dioWith({
        'data': [
          _camporeeJson(registrationCost: '125.50'),
        ],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporees(active: true);

      expect(result, hasLength(1));
      expect(result.first.registrationCost, 125.50);
      expect(result.first.lat, 19.1738);
      expect(result.first.longitude, -96.1342);
      expect(adapter.lastOptions!.queryParameters['active'], true);
    });

    test('parses registered camporee events from backend data envelope',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [
          {
            'camporee_event_id': 77,
            'title': 'Orden cerrado',
            'description': 'Prueba por escuadras',
            'max_points': 100,
            'min_points': 0,
            'day_number': 2,
            'starts_at': '09:00',
            'ends_at': '10:00',
            'display_category': 'competencia',
            'status': 'programado',
            'participants_mode': 'count',
            'participants_count': 8,
            'agenda_visible': true,
            'event_type': {
              'event_type_id': 1,
              'code': 'scoring',
              'name': 'Puntaje',
            },
            'staff_assignments': [
              {
                'camporee_event_staff_assignment_id': 'assignment-1',
                'camporee_staff_member_id': 'staff-1',
                'assignment_role': 'responsible',
                'display_order': 0,
                'camporee_staff_member': {
                  'camporee_staff_member_id': 'staff-1',
                  'category': 'leadership',
                  'role_label': 'Coordinador',
                  'user': {
                    'user_id': 'user-1',
                    'name': 'Pedro',
                    'paternal_last_name': 'Gómez',
                  },
                },
              },
              {
                'camporee_event_staff_assignment_id': 'assignment-2',
                'camporee_staff_member_id': 'staff-2',
                'assignment_role': 'assistant',
                'display_order': 1,
                'camporee_staff_member': {
                  'category': 'support',
                  'user_name': 'Marco',
                },
              },
              {
                'camporee_event_staff_assignment_id': 'assignment-3',
                'camporee_staff_member_id': 'staff-3',
                'assignment_role': 'support',
                'display_order': 2,
                'staff_member_name': 'Fabio',
              },
            ],
            'sections': ['pathfinders'],
            'venue': {'camporee_venue_id': 1, 'name': 'Cancha central'},
            'schedule_blocks': [
              {
                'camporee_event_schedule_block_id': 'block-1',
                'title': 'Primer grupo',
                'day_number': 2,
                'starts_at': '09:00',
                'ends_at': '10:00',
                'venue': {'camporee_venue_id': 1, 'name': 'Cancha central'},
                'assignments': [
                  {
                    'club_section': {
                      'clubs': {'name': 'Estrellas'},
                      'club_types': {'name': 'Conquistadores'},
                    },
                  },
                ],
              },
            ],
          },
        ],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeEvents(42);

      expect(
        adapter.lastOptions!.path,
        '$baseUrl/local-camporees/42/events/preview',
      );
      expect(result, hasLength(1));
      expect(result.first.camporeeEventId, 77);
      expect(result.first.title, 'Orden cerrado');
      expect(result.first.venueName, 'Cancha central');
      expect(result.first.eventTypeCode, 'scoring');
      expect(result.first.staffAssignments, hasLength(3));
      final entity = result.first.toEntity();
      expect(entity.responsibleDisplayNames, ['Pedro Gómez']);
      expect(entity.supportingDisplayNames, ['Marco', 'Fabio']);
      expect(result.first.scheduleBlocks, hasLength(1));
      expect(result.first.scheduleBlocks.first.assignedSectionNames.first,
          'Estrellas · Conquistadores');
    });

    test('uses union camporee preview endpoint when camporeeType is union',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': <Map<String, dynamic>>[],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeEvents(42, camporeeType: 'union');

      expect(
        adapter.lastOptions!.path,
        '$baseUrl/union-camporees/42/events/preview',
      );
      expect(result, isEmpty);
    });
  });

  group('CamporeesRemoteDataSourceImpl.registerMember', () {
    test('sends the mandatory insurance id while backend infers camporee type',
        () async {
      final (:dio, :adapter) = _dioWith(_memberJson());
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.registerMember(
        42,
        userId: 'user-001',
        insuranceId: 17,
      );

      expect(adapter.lastOptions!.path, '$baseUrl/camporees/42/register');
      expect(adapter.lastOptions!.data, {
        'user_id': 'user-001',
        'insurance_id': 17,
      });
    });
  });

  group('CamporeesRemoteDataSourceImpl.enrollClub', () {
    test(
        'uses the contextual active-section endpoint without serializing a section id',
        () async {
      final (:dio, :adapter) = _dioWith({
        'camporeeId': 42,
        'clubId': 7,
        'clubName': 'Orión',
        'clubSectionId': 9,
        'sectionName': 'Conquistadores',
        'clubTypeId': 2,
        'clubTypeName': 'Conquistadores',
        'registration': {
          'id': 17,
          'status': 'registered',
        },
        'canEnroll': false,
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.enrollClub(42);

      expect(adapter.lastOptions!.path,
          '$baseUrl/camporees/42/section-registration');
      expect(adapter.lastOptions!.data, isNull);
    });
  });

  group('CamporeesRemoteDataSourceImpl camporee scoring', () {
    test('parses current judge assignments from backend data envelope',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [
          {
            'camporee_event_judge_assignment_id': 'assignment-1',
            'camporee_event_id': 77,
            'camporee_judge_id': 'judge-1',
            'camporee_club_id': 5,
            'club_section_id': 99,
            'judge_role': 'primary',
            'active': true,
            'event_title': 'Nudos',
            'can_submit_score': true,
          },
        ],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getMyJudgeAssignments();

      expect(
          adapter.lastOptions!.path, '$baseUrl/camporee-judges/me/assignments');
      expect(result, hasLength(1));
      expect(result.first.assignmentId, 'assignment-1');
      expect(result.first.judgeRole, 'primary');
      expect(result.first.canSubmitScore, isTrue);
    });

    test('parses local camporee leaderboard from backend data envelope',
        () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {
          'scope': {'type': 'local', 'camporeeId': 73},
          'rows': [
            {
              'rank': 1,
              'camporee_club_id': 5,
              'club_section_id': 2,
              'club_name': 'ACV',
              'section_name': 'Conquistadores',
              'total_awarded_points': '85.00',
              'total_max_points': '100.00',
              'percentage': '85.00',
            },
          ],
        },
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeLeaderboard(73);

      expect(
        adapter.lastOptions!.path,
        '$baseUrl/local-camporees/73/leaderboard',
      );
      expect(result.camporeeId, 73);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.clubName, 'ACV');
      expect(result.rows.first.totalAwardedPoints, 85);
    });

    test('parses event rubrics from backend data envelope', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': [
          {
            'camporee_event_rubric_id': 101,
            'camporee_event_id': 77,
            'title': 'Técnica',
            'description': 'Nudo correcto',
            'max_points': '40.50',
            'display_order': 0,
            'active': true,
          },
        ],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeEventRubrics(77);

      expect(adapter.lastOptions!.path, '$baseUrl/camporee-events/77/rubrics');
      expect(result, hasLength(1));
      expect(result.first.rubricId, 101);
      expect(result.first.maxPoints, 40.5);
    });

    test('submits one official score item per rubric', () async {
      final (:dio, :adapter) = _dioWith({
        'status': 'success',
        'data': {'camporee_event_section_result_id': 'result-1'},
      }, statusCode: 201);
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.submitCamporeeEventScore(
        77,
        99,
        submission: const CamporeeScoreSubmission(
          items: [
            CamporeeScoreSubmissionItem(rubricId: 101, awardedPoints: 35),
            CamporeeScoreSubmissionItem(rubricId: 102, awardedPoints: 50),
          ],
        ),
      );

      expect(adapter.lastOptions!.path,
          '$baseUrl/camporee-events/77/sections/99/scores');
      expect(adapter.lastOptions!.data, {
        'source': 'judge_primary',
        'items': [
          {'camporee_event_rubric_id': 101, 'awarded_points': 35.0},
          {'camporee_event_rubric_id': 102, 'awarded_points': 50.0},
        ],
      });
    });
  });

  group('CamporeesRemoteDataSourceImpl.getCamporeeMembers', () {
    // ── Happy path ───────────────────────────────────────────────────────────

    test('returns PaginatedResult with 1 member on happy-path response',
        () async {
      final (:dio, :adapter) = _dioWith(_paginatedResponse());
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeMembers(42);

      expect(result, isA<PaginatedResult<CamporeeMemberModel>>());
      expect(result.data, hasLength(1));
      expect(result.data.first.userId, 'user-001');
      expect(result.meta.total, 1);
      expect(result.meta.page, 1);
      expect(result.meta.limit, 50);
      expect(result.meta.hasNextPage, isFalse);
      expect(result.meta.hasPreviousPage, isFalse);
    });

    // ── Query params ────────────────────────────────────────────────────────

    test('sends page, limit and status as query params', () async {
      final (:dio, :adapter) = _dioWith(_paginatedResponse(
        members: [_memberJson()],
        meta: _metaJson(page: 2, limit: 20, total: 1, totalPages: 1),
      ));
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.getCamporeeMembers(7, page: 2, limit: 20, status: 'approved');

      final params = adapter.lastOptions!.queryParameters;
      expect(params['page'], 2);
      expect(params['limit'], 20);
      expect(params['status'], 'approved');
    });

    test('does not send status param when null', () async {
      final (:dio, :adapter) = _dioWith(_paginatedResponse());
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.getCamporeeMembers(1);

      expect(
          adapter.lastOptions!.queryParameters.containsKey('status'), isFalse);
    });

    // ── Empty data ───────────────────────────────────────────────────────────

    test('returns empty list with total=0 when data is empty array', () async {
      final (:dio, :adapter) = _dioWith(_paginatedResponse(
        members: [],
        meta: _metaJson(total: 0, totalPages: 1),
      ));
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeMembers(1);

      expect(result.data, isEmpty);
      expect(result.meta.total, 0);
    });

    // ── Malformed response (T2 fix) ──────────────────────────────────────────

    test('throws ServerException when response body is a plain String',
        () async {
      // Use a raw-string body — Dio will decode it as a String, not a Map/List.
      final body = ResponseBody.fromString(
        '"unexpected string"',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
      final adapter = _FakeAdapter(body);
      final dio = Dio(BaseOptions(responseType: ResponseType.json));
      dio.httpClientAdapter = adapter;
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      expect(
        () => ds.getCamporeeMembers(1),
        throwsA(isA<ServerException>()),
      );
    });

    // ── 404 DioException ─────────────────────────────────────────────────────

    test('throws ServerException (not NotFoundException) when Dio throws 404',
        () async {
      final dio = _dioThatThrows((opts) => DioException(
            requestOptions: opts,
            response: Response(
              requestOptions: opts,
              statusCode: 404,
              data: {'message': 'Camporee not found'},
            ),
            type: DioExceptionType.badResponse,
          ));
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      // The datasource's _rethrow maps any DioException → ServerException.
      expect(
        () => ds.getCamporeeMembers(999),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 404),
        ),
      );
    });
  });
}
