import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/features/family/data/datasources/linked_devices_remote_data_source.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/data/models/linked_device_models.dart';
import 'package:sacdia_app/features/family/data/repositories/linked_devices_repository_impl.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/linked_device.dart';

import '../family_fixtures.dart';

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

final _now = DateTime.utc(2026, 10, 20, 10);

LinkedDevicesRepositoryImpl _repo(_Recording adapter) =>
    LinkedDevicesRepositoryImpl(
      remoteDataSource: LinkedDevicesRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
          ..httpClientAdapter = adapter,
        baseUrl: 'http://localhost:3000',
        now: () => _now,
      ),
    );

Map<String, Object?> _deviceJson(
  String id, {
  String? revokedAt,
  String? status,
}) =>
    {
      'linked_device_id': id,
      'label': 'Tablet de Ana',
      'platform': 'android',
      'app_version': '2.4.0',
      'paired_at': '2026-10-20T09:00:00.000Z',
      'paired_by_display_name': 'María Pérez',
      'last_seen_at': '2026-10-20T09:30:00.000Z',
      'absolute_expires_at': '2027-04-18T09:00:00.000Z',
      if (revokedAt != null) 'revoked_at': revokedAt,
      if (status != null) 'status': status,
    };

void main() {
  group('GET .../devices', () {
    test('requests as the guardian herself and parses devices and limit',
        () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {
          'devices': [_deviceJson('d1'), _deviceJson('d2')],
          'limits': {'max_devices': 2},
        },
      });

      final result = await _repo(adapter).list('ana-1');

      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path,
          'http://localhost:3000/guardianships/me/dependents/ana-1/devices');
      expect(req.extra[AuthInterceptor.skipActingForKey], isTrue);
      final list = result.getOrElse(() => throw StateError('left'));
      expect(list.devices, hasLength(2));
      expect(list.maxDevices, 2);
      expect(list.isFull, isTrue);
      final first = list.devices.first;
      expect(first.id, 'd1');
      expect(first.label, 'Tablet de Ana');
      expect(first.platform, 'android');
      expect(first.pairedByDisplayName, 'María Pérez');
      expect(first.lastSeenAt, DateTime.utc(2026, 10, 20, 9, 30));
      expect(first.isRevoked, isFalse);
    });

    test('revoked devices (by date or status) are history, not active',
        () async {
      final result = await _repo(_Recording(200, {
        'data': {
          'devices': [
            _deviceJson('d1'),
            _deviceJson('d2', revokedAt: '2026-10-19T10:00:00.000Z'),
            _deviceJson('d3', status: 'revoked'),
          ],
        },
      })).list('ana-1');

      final list = result.getOrElse(() => throw StateError('left'));
      expect(list.active.map((d) => d.id), ['d1']);
      expect(list.revoked.map((d) => d.id), ['d2', 'd3']);
      expect(list.isFull, isFalse, reason: 'revoked ones do not count');
    });

    test('a missing, zero or negative limit falls back to the agreed 2', () {
      for (final limits in [
        null,
        <String, Object?>{},
        {'max_devices': 0},
        {'max_devices': -3},
        {'max_devices': 'x'}
      ]) {
        final list =
            LinkedDeviceJson.list({'devices': <Object?>[], 'limits': limits});
        expect(list.maxDevices, kDefaultMaxLinkedDevices, reason: '$limits');
      }
      expect(
        LinkedDeviceJson.list({
          'devices': <Object?>[],
          'limits': {'max_devices': 3},
        }).maxDevices,
        3,
      );
    });

    test('a malformed body is a failure, never a crash', () async {
      final result =
          await _repo(_Recording(200, {'unexpected': true})).list('x');
      expect(result.isLeft(), isTrue);
    });
  });

  group('POST .../devices/pairing-tokens', () {
    test('posts to the design path and parses the token', () async {
      final adapter = _Recording(201, {
        'status': 'success',
        'data': {
          'pairing_token': 'ABCDEFGHIJKLMNOPQRSTUV',
          'qr_payload': 'sacdia://pair?t=ABCDEFGHIJKLMNOPQRSTUV',
          'expires_at': '2026-10-20T10:10:00.000Z',
          'expires_in': 600,
        },
      });

      final result = await _repo(adapter).issuePairingToken('ana-1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(
        req.path,
        'http://localhost:3000/guardianships/me/dependents/ana-1'
        '/devices/pairing-tokens',
      );
      expect(req.extra[AuthInterceptor.skipActingForKey], isTrue);
      final token = result.getOrElse(() => throw StateError('left'));
      expect(token.token, 'ABCDEFGHIJKLMNOPQRSTUV');
      expect(token.qrPayload, 'sacdia://pair?t=ABCDEFGHIJKLMNOPQRSTUV',
          reason: 'the server payload is kept when it carries this token');
      expect(token.expiresAt, DateTime.utc(2026, 10, 20, 10, 10));
      expect(token.secondsLeftAt(_now), 600);
      expect(token.isExpiredAt(_now), isFalse);
      expect(token.isExpiredAt(DateTime.utc(2026, 10, 20, 10, 10)), isTrue);
      expect(token.secondsLeftAt(DateTime.utc(2026, 10, 20, 11)), 0);
    });

    test('a payload that does not carry this token is replaced', () {
      for (final payload in [
        null,
        'https://evil.example/pair?c=ABC',
        'sacdia://pair?c=OTHER',
        'sacdia://pair',
        '',
      ]) {
        final token = LinkedDeviceJson.pairingToken({
          'pairing_token': 'ABC',
          'qr_payload': payload,
          'expires_in': 600,
        }, now: _now);
        expect(token.qrPayload, 'sacdia://pair?c=ABC', reason: '$payload');
      }
    });

    test('without expires_at the expiry comes from expires_in (default 10 min)',
        () {
      final a = LinkedDeviceJson.pairingToken(
        {'pairing_token': 'ABC', 'expires_in': 120},
        now: _now,
      );
      expect(a.expiresAt, _now.add(const Duration(seconds: 120)));
      final b =
          LinkedDeviceJson.pairingToken({'pairing_token': 'ABC'}, now: _now);
      expect(b.expiresAt, _now.add(const Duration(minutes: 10)));
    });

    test('a response without the token is a failure', () async {
      final result = await _repo(_Recording(201, {
        'data': {'qr_payload': 'sacdia://pair?c=x'},
      })).issuePairingToken('ana-1');
      expect(result.isLeft(), isTrue);
    });

    test('the token never prints', () {
      final token = DevicePairingToken(
        token: 'SECRET-TOKEN',
        qrPayload: 'sacdia://pair?c=SECRET-TOKEN',
        expiresAt: _farFuture,
        issuedAt: _farFuture,
      );
      expect(token.toString(), isNot(contains('SECRET')));
      expect(token.props.toString(), isNot(contains('SECRET')));
    });

    test(
        'keeps the business codes: limit, not eligible, feature off, not found',
        () async {
      for (final entry in {
        409: 'DEVICE_LIMIT_REACHED',
        422: 'DEVICE_PAIRING_NOT_ELIGIBLE',
        404: 'FAMILY_FEATURE_DISABLED',
      }.entries) {
        final result = await _repo(_Recording(entry.key, {
          'status': 'error',
          'statusCode': entry.key,
          'code': entry.value,
          'message': 'raw',
          'details': {'reason': 'consent_not_verified'},
        })).issuePairingToken('ana-1');

        final failure = result.fold((f) => f, (_) => null)!;
        expect(failure.errorCode, entry.value);
        expect(failure.code, entry.key);
      }
    });
  });

  group('POST .../devices/:id/revoke', () {
    test('posts to the design path and parses the result', () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {
          'linked_device_id': 'd1',
          'revoked_at': '2026-10-20T12:00:00.000Z',
          'revoked_reason': 'guardian',
        },
      });

      final result = await _repo(adapter).revoke('ana-1', 'd1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(
        req.path,
        'http://localhost:3000/guardianships/me/dependents/ana-1'
        '/devices/d1/revoke',
      );
      expect(req.extra[AuthInterceptor.skipActingForKey], isTrue);
      final revoked = result.getOrElse(() => throw StateError('left'));
      expect(revoked.linkedDeviceId, 'd1');
      expect(revoked.revokedAt, DateTime.utc(2026, 10, 20, 12));
    });

    test('a foreign device is a 404 with its code', () async {
      final result = await _repo(_Recording(404, {
        'code': 'DEVICE_NOT_FOUND',
        'message': 'x',
      })).revoke('ana-1', 'nope');
      expect(result.fold((f) => f.errorCode, (_) => null), 'DEVICE_NOT_FOUND');
    });

    test('no connection is a NetworkFailure', () async {
      final repo = LinkedDevicesRepositoryImpl(
        remoteDataSource: LinkedDevicesRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
            ..httpClientAdapter = _Failing(),
          baseUrl: 'http://localhost:3000',
        ),
      );
      final result = await repo.revoke('ana-1', 'd1');
      expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  group('DependentSummary: canPairDevice', () {
    DependentSummary s({
      String consent = 'verified',
      bool frozen = false,
      String access = 'guardian_managed',
      bool milestone = false,
      int devices = 0,
    }) =>
        FamilyJson.summary(dependentJson(
          consent: consent,
          frozen: frozen,
          accessMode: access,
          ageMilestoneReached: milestone,
          linkedDevices: devices,
        ));

    test('verified, active, guardian-managed and under the login age', () {
      expect(s().canPairDevice, isTrue);
    });

    test('no for a pending guardian, a frozen child, own login or 13+', () {
      expect(s(consent: 'pending').canPairDevice, isFalse);
      expect(s(frozen: true).canPairDevice, isFalse);
      expect(s(access: 'supervised_login').canPairDevice, isFalse);
      expect(s(milestone: true).canPairDevice, isFalse);
    });

    test('the count of linked phones is parsed', () {
      expect(s(devices: 2).linkedDevicesCount, 2);
    });
  });
}

final _farFuture = DateTime.utc(2099);

class _Failing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async =>
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );

  @override
  void close({bool force = false}) {}
}
