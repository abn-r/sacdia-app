import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';
import 'package:sacdia_app/features/camporees/data/datasources/camporees_remote_data_source.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_member_model.dart';

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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const baseUrl = 'http://localhost:3000';

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
            'sections': ['pathfinders'],
            'venue': {'camporee_venue_id': 1, 'name': 'Cancha central'},
          },
        ],
      });
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      final result = await ds.getCamporeeEvents(42);

      expect(adapter.lastOptions!.path, '$baseUrl/local-camporees/42/events');
      expect(result, hasLength(1));
      expect(result.first.camporeeEventId, 77);
      expect(result.first.title, 'Orden cerrado');
      expect(result.first.venueName, 'Cancha central');
    });
  });

  group('CamporeesRemoteDataSourceImpl.registerMember', () {
    test('sends only user_id by default because backend infers camporee type',
        () async {
      final (:dio, :adapter) = _dioWith(_memberJson());
      final ds = CamporeesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);

      await ds.registerMember(
        42,
        userId: 'user-001',
      );

      expect(adapter.lastOptions!.path, '$baseUrl/camporees/42/register');
      expect(adapter.lastOptions!.data, {
        'user_id': 'user-001',
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
