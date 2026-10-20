import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/teen/data/datasources/teen_remote_data_source.dart';
import 'package:sacdia_app/features/teen/data/models/teen_models.dart';
import 'package:sacdia_app/features/teen/data/repositories/teen_repository_impl.dart';

class _Recording implements HttpClientAdapter {
  _Recording(this.status, this.body);

  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TeenRemoteDataSourceImpl _ds(_Recording adapter) => TeenRemoteDataSourceImpl(
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
        ..httpClientAdapter = adapter,
      baseUrl: 'http://localhost:3000',
    );

void main() {
  group('TeenJson.supervision', () {
    test('parses status, clock, guardians and the open code', () {
      final s = TeenJson.supervision({
        'status': 'pending_guardian',
        'pending_since': '2026-10-01T00:00:00.000Z',
        'guardians': [
          {
            'guardianship_id': 'gs-1',
            'display_name': 'María Pérez',
            'relationship_type_name': 'Madre',
            'consent_status': 'pending',
            // Contacto: nunca se lee.
            'email': 'maria@example.com',
            'phone': '555',
          },
        ],
        'open_link_code': {'expires_at': '2026-10-22T10:00:00.000Z'},
        'summary_visible_to_guardians': true,
      });

      expect(s.status, SupervisionStatus.pendingGuardian);
      expect(s.isPending, isTrue);
      expect(s.pendingSince, DateTime.utc(2026, 10, 1));
      expect(s.guardians.single.guardianshipId, 'gs-1');
      expect(s.guardians.single.displayName, 'María Pérez');
      expect(s.guardians.single.relationshipTypeName, 'Madre');
      expect(s.guardians.single.verified, isFalse);
      expect(s.guardians.single.canBeRemovedByTeen, isTrue);
      expect(s.openLinkCode!.expiresAt, DateTime.utc(2026, 10, 22, 10));
      expect(s.guardians.single.props, isNot(contains('maria@example.com')));
    });

    test('days left count from pending_since and never go negative', () {
      final s = TeenJson.supervision({
        'status': 'pending_guardian',
        'pending_since': '2026-10-01T00:00:00.000Z',
      });
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 1)), 90);
      expect(s.daysLeftAt(DateTime.utc(2026, 12, 20)), 10);
      expect(s.daysLeftAt(DateTime.utc(2027, 6, 1)), 0);
    });

    test('an active supervision has no clock', () {
      final s = TeenJson.supervision({
        'status': 'active',
        'pending_since': '2026-10-01T00:00:00.000Z',
      });
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 5)), isNull);
    });

    test('a verified guardian cannot be removed by the teen', () {
      final s = TeenJson.supervision({
        'status': 'active',
        'guardians': [
          {
            'guardianship_id': 'gs-2',
            'display_name': 'Luis',
            'consent_status': 'verified',
          },
        ],
      });
      expect(s.guardians.single.verified, isTrue);
      expect(s.guardians.single.canBeRemovedByTeen, isFalse);
    });

    test('a guardian without an id cannot be removed', () {
      final s = TeenJson.supervision({
        'status': 'pending_guardian',
        'guardians': [
          {'display_name': 'Ana', 'consent_status': 'pending'},
        ],
      });
      expect(s.guardians.single.canBeRemovedByTeen, isFalse);
    });

    test('a missing consent status is treated as unverified (safe side)', () {
      final s = TeenJson.supervision({
        'status': 'pending_guardian',
        'guardians': [
          {'guardianship_id': 'gs-3', 'display_name': 'X'},
        ],
      });
      expect(s.guardians.single.verified, isFalse);
    });

    test('null status and an empty payload are tolerated', () {
      final s = TeenJson.supervision({'status': null});
      expect(s.status, isNull);
      expect(s.guardians, isEmpty);
      expect(s.openLinkCode, isNull);
      expect(s.summaryVisibleToGuardians, isTrue);
    });
  });

  group('datasource', () {
    test('GET /users/me/supervision', () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {'status': 'active', 'guardians': []},
      });

      final s = await _ds(adapter).getSupervision();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/users/me/supervision');
      expect(s.status, SupervisionStatus.active);
    });

    test('POST /users/me/guardian-link-codes returns the plain code once',
        () async {
      final adapter = _Recording(201, {
        'status': 'success',
        'data': {'code': '7KQ4-M9TX', 'expires_at': '2026-10-22T10:00:00.000Z'},
      });

      final code = await _ds(adapter).issueLinkCode();

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/users/me/guardian-link-codes');
      expect(adapter.requests.single.data, <String, dynamic>{});
      expect(code.code, '7KQ4-M9TX');
      expect(code.expiresAt, DateTime.utc(2026, 10, 22, 10));
    });

    test('POST /users/me/guardian-links/:id/revoke', () async {
      final adapter = _Recording(200, {'status': 'success', 'data': {}});

      await _ds(adapter).revokePendingLink('gs-1');

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.uri.path,
        '/users/me/guardian-links/gs-1/revoke',
      );
    });

    test('a business error keeps the code and never reads details', () async {
      final adapter = _Recording(409, {
        'status': 'error',
        'code': 'GUARDIANSHIP_ALREADY_GUARDIAN',
        'message': 'RAW',
        'details': {'secret': 'leak'},
      });

      await expectLater(
        _ds(adapter).issueLinkCode(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode',
                  'GUARDIANSHIP_ALREADY_GUARDIAN')
              .having((e) => e.code, 'code', 409),
        ),
      );
    });
  });

  group('repository', () {
    test('maps failures keeping errorCode', () async {
      final repo = TeenRepositoryImpl(
        remoteDataSource: _ds(_Recording(403, {
          'status': 'error',
          'code': 'PRINCIPAL_SCOPE_DENIED',
          'message': 'x',
        })),
      );

      final result = await repo.issueLinkCode();

      final failure = result.fold((f) => f, (_) => null);
      expect(failure, isA<AuthFailure>());
      expect(failure!.errorCode, 'PRINCIPAL_SCOPE_DENIED');
      expect(failure.code, 403);
    });

    test('a 404 on revoke is a ServerFailure with the code', () async {
      final repo = TeenRepositoryImpl(
        remoteDataSource: _ds(_Recording(404, {
          'status': 'error',
          'code': 'GUARDIANSHIP_NOT_FOUND',
          'message': 'x',
        })),
      );

      final result = await repo.revokePendingLink('gs-9');

      final failure = result.fold((f) => f, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect(failure!.errorCode, 'GUARDIANSHIP_NOT_FOUND');
    });
  });
}
