import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/device_mode/data/datasources/device_pairing_remote_data_source.dart';
import 'package:sacdia_app/features/device_mode/data/models/device_pairing_models.dart';
import 'package:sacdia_app/features/device_mode/data/repositories/device_pairing_repository_impl.dart';
import 'package:sacdia_app/features/device_mode/domain/entities/device_pairing.dart';

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

const _input = DevicePairingInput(
  pairingToken: 'SECRET-token_1',
  label: 'Tablet de Ana',
  platform: 'android',
  appVersion: '2.4.0',
);

Map<String, Object?> _pairBody() => {
      'accessToken': 'device-jwt',
      'refreshToken': 'session-token',
      'expiresAt': 1900000000,
      'tokenType': 'bearer',
      'device': {'linked_device_id': 'dev-1', 'label': 'Tablet de Ana'},
      'user': {'id': 'kid-1', 'name': 'Ana', 'avatar': null},
    };

DevicePairingRepositoryImpl _repo(_Recording adapter) =>
    DevicePairingRepositoryImpl(
      remoteDataSource: DevicePairingRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
          ..httpClientAdapter = adapter,
        baseUrl: 'http://localhost:3000',
      ),
    );

void main() {
  group('POST /auth/device/pair', () {
    test('sends the contract body and skips X-Acting-For', () async {
      final adapter =
          _Recording(200, {'status': 'success', 'data': _pairBody()});

      final result = await _repo(adapter).pair(_input);

      expect(result.isRight(), isTrue);
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, 'http://localhost:3000/auth/device/pair');
      expect(req.data, {
        'pairing_token': 'SECRET-token_1',
        'label': 'Tablet de Ana',
        'platform': 'android',
        'app_version': '2.4.0',
      });
      expect(req.extra[AuthInterceptor.skipActingForKey], isTrue);
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('parses the session from the wrapped and the bare envelope', () async {
      for (final body in [
        {'status': 'success', 'data': _pairBody()},
        _pairBody(),
      ]) {
        final result = await _repo(_Recording(200, body)).pair(_input);
        final session = result.getOrElse(() => throw StateError('left'));
        expect(session.accessToken, 'device-jwt');
        expect(session.refreshToken, 'session-token');
        expect(session.expiresAt, 1900000000);
        expect(session.tokenType, 'bearer');
        expect(session.linkedDeviceId, 'dev-1');
        expect(session.deviceLabel, 'Tablet de Ana');
        expect(session.userId, 'kid-1');
        expect(session.userName, 'Ana');
        expect(session.userAvatar, isNull);
      }
    });

    test('a response without tokens or user is a server failure', () async {
      for (final body in [
        <String, Object?>{},
        {
          'data': {'accessToken': 'x'}
        },
        {
          'data': {
            'accessToken': 'x',
            'refreshToken': 'y',
            'user': <String, Object?>{},
          }
        },
      ]) {
        final result = await _repo(_Recording(200, body)).pair(_input);
        expect(result.isLeft(), isTrue, reason: '$body');
      }
    });

    test('keeps the business code (uniform invalid token)', () async {
      final result = await _repo(_Recording(400, {
        'status': 'error',
        'statusCode': 400,
        'code': 'DEVICE_PAIRING_TOKEN_INVALID',
        'message': 'raw server text',
        'details': {'reason': 'expired', 'ignored': true},
      })).pair(_input);

      final failure = result.fold((f) => f, (_) => null)!;
      expect(failure.errorCode, 'DEVICE_PAIRING_TOKEN_INVALID');
      expect(failure.code, 400);
    });

    test('keeps the device limit and feature-disabled codes', () async {
      final limit = await _repo(_Recording(409, {
        'code': 'DEVICE_LIMIT_REACHED',
        'message': 'x',
      })).pair(_input);
      expect(
          limit.fold((f) => f.errorCode, (_) => null), 'DEVICE_LIMIT_REACHED');

      final off = await _repo(_Recording(404, {
        'code': 'FAMILY_FEATURE_DISABLED',
        'message': 'x',
      })).pair(_input);
      expect(
          off.fold((f) => f.errorCode, (_) => null), 'FAMILY_FEATURE_DISABLED');
    });

    test('a network failure is a NetworkFailure', () async {
      final repo = DevicePairingRepositoryImpl(
        remoteDataSource: DevicePairingRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
            ..httpClientAdapter = _Failing(),
          baseUrl: 'http://localhost:3000',
        ),
      );
      final result = await repo.pair(_input);
      expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  group('the pairing token never prints', () {
    test('toString and props leave the secrets out', () {
      expect(_input.toString(), isNot(contains('SECRET')));
      expect(_input.props, isNot(contains('SECRET-token_1')));
      const session = DevicePairingSession(
        accessToken: 'AT-secret',
        refreshToken: 'RT-secret',
        userId: 'kid-1',
      );
      expect(session.toString(), isNot(contains('secret')));
      expect(session.props, isNot(contains('AT-secret')));
      expect(session.props, isNot(contains('RT-secret')));
    });
  });

  group('/auth/me principal.device', () {
    test('parses the linked device block and the mode', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'kid-1',
        'name': 'Ana',
        'principal': {
          'kind': 'linked_device',
          'scopes': null,
          'supervision': null,
          'device': {
            'linked_device_id': 'dev-1',
            'label': 'Tablet de Ana',
            'paired_at': '2026-10-20T10:00:00.000Z',
          },
        },
        'family_features': {'linked_device': true},
        'legal': {'requires_acceptance': true},
        'family': null,
      }, postRegisterComplete: true);

      expect(user.principal!.kind, PrincipalKind.linkedDevice);
      expect(user.principal!.device!.linkedDeviceId, 'dev-1');
      expect(user.principal!.device!.label, 'Tablet de Ana');
      expect(user.principal!.device!.pairedAt, isNotNull);
      expect(user.mode, AccountMode.linkedDevice);
      expect(user.isLinkedDevice, isTrue);
      expect(user.isLimitedAccount, isTrue);
      expect(user.canIdentifyInAnalytics, isFalse);
      expect(user.legalAcceptancePending, isTrue);
      expect(user.familyFeatures!.linkedDevice, isTrue);
    });

    test('a device principal wins over any mode the server declares', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'kid-1',
        'mode': 'adult',
        'analytics_anonymous': false,
        'principal': {'kind': 'linked_device'},
      });
      expect(user.mode, AccountMode.linkedDevice);
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('an unknown kind still fails closed, never as a device', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'x',
        'principal': {'kind': 'linked_gadget'},
      });
      expect(user.mode, AccountMode.restricted);
      expect(user.isLinkedDevice, isFalse);
    });

    test('the confirmed device /auth/me shape: mode device, no family', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'kid-1',
        'name': 'Ana',
        'mode': 'device',
        'analytics_anonymous': true,
        'family': null,
        'acting_for': null,
        'principal': {
          'kind': 'linked_device',
          'scopes': [
            'self:read',
            'evidence:upload',
            'evidence:submit',
            'push:register',
            'agenda:read',
            'credential:read',
          ],
          'supervision': null,
          'device': {
            'linked_device_id': 'dev-1',
            'label': 'Tablet',
            'paired_at': '2026-10-20T10:00:00.000Z',
          },
        },
      });

      expect(user.mode, AccountMode.linkedDevice);
      expect(user.serverMode, AccountMode.linkedDevice);
      expect(user.family, isNull);
      expect(user.actingFor, isNull);
      expect(user.analyticsAnonymous, isTrue);
      expect(user.principal!.scopes, contains('credential:read'));
      expect(user.principal!.supervision, isNull);
    });

    test('a missing device block is tolerated', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'kid-1',
        'principal': {'kind': 'linked_device', 'device': 'oops'},
      });
      expect(user.principal!.device, isNull);
      expect(user.isLinkedDevice, isTrue);
    });
  });

  test('DevicePairingJson rejects a non-map', () {
    expect(() => DevicePairingJson.session('nope'), throwsA(anything));
    expect(() => DevicePairingJson.session(null), throwsA(anything));
  });
}

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
