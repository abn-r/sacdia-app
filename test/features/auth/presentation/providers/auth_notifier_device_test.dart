import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/providers/achievements_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/features/device_mode/domain/entities/device_pairing.dart';
import 'package:sacdia_app/features/device_mode/domain/repositories/device_pairing_repository.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_notice_provider.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_pairing_providers.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';

import 'auth_notifier_test_support.dart';

const _input = DevicePairingInput(
  pairingToken: 'SECRET-token',
  label: 'Tablet de Ana',
  platform: 'android',
  appVersion: '2.4.0',
);

const _deviceUser = UserEntity(
  id: 'kid-1',
  name: 'Ana',
  postRegisterComplete: true,
  principal: PrincipalInfo(
    kind: PrincipalKind.linkedDevice,
    device: DeviceInfo(linkedDeviceId: 'dev-1', label: 'Tablet de Ana'),
  ),
);

class _FakePairing implements DevicePairingRepository {
  Either<Failure, DevicePairingSession> result = const Right(
    DevicePairingSession(
      accessToken: 'device-jwt',
      refreshToken: 'session-token',
      expiresAt: 1900000000,
      tokenType: 'bearer',
      linkedDeviceId: 'dev-1',
      userId: 'kid-1',
      userName: 'Ana',
    ),
  );
  int calls = 0;
  void Function()? onPair;

  @override
  Future<Either<Failure, DevicePairingSession>> pair(
    DevicePairingInput input,
  ) async {
    calls++;
    onPair?.call();
    await Future<void>.delayed(Duration.zero);
    return result;
  }
}

class _Repo extends FakeAuthRepository {
  _Repo(this.storage);

  final FakeSecureStorage storage;
  Either<Failure, UserEntity?> me = const Right(_deviceUser);
  int meCalls = 0;
  int signOuts = 0;

  @override
  Future<bool> hasLocalToken() async =>
      (await storage.read(AppConstants.tokenKey)) != null;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    meCalls++;
    return me;
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOuts++;
    // Como el datasource real: borra tokens y datos persistentes.
    await storage.deleteAll();
    return const Right(null);
  }
}

int _sentinelBuilds = 0;

/// Centinela añadido al registro REAL: cada invalidación lo reconstruye.
final _sentinel = Provider<int>((ref) => ++_sentinelBuilds);

class _AchievementsRepo implements AchievementsRepository {
  _AchievementsRepo(this.onCall);

  final void Function() onCall;

  @override
  Future<Either<Failure, UserAchievementsResponse>>
      getUserAchievements() async {
    onCall();
    return const Left(NetworkFailure(message: 'offline'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _sentinelBuilds = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (_) async => true,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  Future<
      ({
        ProviderContainer container,
        AuthNotifier auth,
        _Repo repo,
        _FakePairing pairing,
        FakeSecureStorage storage,
        List<int> achievementCalls,
      })> boot({
    Map<String, String> stored = const {},
    UserEntity? me,
  }) async {
    final storage = FakeSecureStorage();
    for (final e in stored.entries) {
      await storage.write(e.key, e.value);
    }
    final repo = _Repo(storage);
    if (me != null) repo.me = Right(me);
    final pairing = _FakePairing();
    final achievementCalls = <int>[0];
    final container = await buildAuthContainer(
      repo: repo,
      storage: storage,
      extraOverrides: [
        devicePairingRepositoryProvider.overrideWithValue(pairing),
        jsonFileCacheProvider.overrideWithValue(MemoryJsonFileCache()),
        achievementsRepositoryProvider.overrideWithValue(
          _AchievementsRepo(() => achievementCalls[0]++),
        ),
        // Registro REAL más un centinela para ver el orden de la purga.
        profileScopedProvidersProvider
            .overrideWithValue([...profileScopedProviders, _sentinel]),
      ],
    );
    await container.read(authNotifierProvider.future);
    return (
      container: container,
      auth: container.read(authNotifierProvider.notifier),
      repo: repo,
      pairing: pairing,
      storage: storage,
      achievementCalls: achievementCalls,
    );
  }

  group('pairDevice', () {
    test('purges first through the container, then stores tokens and mode',
        () async {
      final h = await boot();
      // Un provider real del registro que observa auth y está montado: purgarlo
      // con `Ref.invalidate` lanzaría CircularDependencyError.
      h.container.listen(userAchievementsProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      final before = h.achievementCalls[0];
      h.container.listen(_sentinel, (_, __) {});
      expect(_sentinelBuilds, 1);
      var sentinelAtPair = -1;
      var tokenAtPair = 'unset';
      h.pairing.onPair = () {
        // Leer materializa la invalidación pendiente: si el registro se
        // purgó antes del canje, el centinela ya se reconstruyó.
        h.container.read(_sentinel);
        sentinelAtPair = _sentinelBuilds;
        h.storage
            .read(AppConstants.tokenKey)
            .then((v) => tokenAtPair = v ?? 'none');
      };

      final error = await h.auth.pairDevice(_input);

      expect(error, isNull);
      expect(h.pairing.calls, 1);
      await Future<void>.delayed(Duration.zero);
      expect(h.achievementCalls[0], greaterThan(before),
          reason: 'the mounted registry provider was purged and rebuilt');
      expect(sentinelAtPair, 2,
          reason: 'the purge ran BEFORE the token was redeemed');
      expect(tokenAtPair, 'none', reason: 'nothing stored before the redeem');

      expect(await h.storage.read(AppConstants.tokenKey), 'device-jwt');
      expect(
          await h.storage.read(AppConstants.refreshTokenKey), 'session-token');
      expect(await h.storage.read(AppConstants.expiresAtKey), '1900000000');
      expect(await h.storage.read(AppConstants.tokenTypeKey), 'bearer');
      expect(await h.storage.read(AppConstants.sessionModeKey), 'device');
      expect(h.container.read(sessionModeProvider), SessionMode.device);

      final user = h.container.read(authNotifierProvider).valueOrNull;
      expect(user!.id, 'kid-1');
      expect(user.isLinkedDevice, isTrue);
      expect(h.repo.meCalls, 1, reason: 'one /auth/me, after pairing');
      expect(h.repo.signOuts, 0);
      // El teléfono puede restaurarse sin red: guarda lo mínimo en el
      // almacenamiento seguro.
      expect(await h.storage.read(AppConstants.cachedUserId), 'kid-1');
    });

    test('it is refused while a user session exists, with no API call',
        () async {
      final h = await boot(
        stored: {AppConstants.tokenKey: 'account-token'},
        me: const UserEntity(id: 'adult-1', postRegisterComplete: true),
      );

      final error = await h.auth.pairDevice(_input);

      expect(error, 'device.pair.errors.session_exists');
      expect(h.pairing.calls, 0);
      expect(await h.storage.read(AppConstants.tokenKey), 'account-token');
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
    });

    test('it is refused while acting for a dependent', () async {
      final h = await boot();
      h.container
          .read(actingForSessionProvider)
          .enter(const ActingDependent(userId: 'ana-1'));

      final error = await h.auth.pairDevice(_input);

      expect(error, 'device.pair.errors.session_exists');
      expect(h.pairing.calls, 0);
    });

    test('a failed redeem maps by errorCode and stores nothing', () async {
      final h = await boot();
      h.pairing.result = const Left(ServerFailure(
        message: 'RAW SERVER TEXT',
        code: 400,
        errorCode: 'DEVICE_PAIRING_TOKEN_INVALID',
      ));

      final error = await h.auth.pairDevice(_input);

      // Sin EasyLocalization montada `tr()` devuelve la clave y el mensaje cae
      // al genérico; el texto por código se comprueba en los tests de la
      // pantalla con las traducciones reales. Nunca el texto crudo.
      expect(error, 'device.pair.errors.generic');
      expect(error, isNot(contains('RAW')));
      expect(await h.storage.contains(AppConstants.tokenKey), isFalse);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
    });

    test('an unmapped failure falls back to the generic pairing message',
        () async {
      final h = await boot();
      h.pairing.result = const Left(ServerFailure(message: 'RAW', code: 500));

      expect(await h.auth.pairDevice(_input), 'device.pair.errors.generic');
    });

    test('a code-less 429 (5/min per IP) is "too many attempts"', () async {
      final h = await boot();
      h.pairing.result =
          const Left(ServerFailure(message: 'ThrottlerException', code: 429));

      expect(await h.auth.pairDevice(_input), 'errors.too_many_attempts');
    });

    test('a network failure reads as a connection error', () async {
      final h = await boot();
      h.pairing.result = const Left(NetworkFailure(message: 'offline'));

      expect(await h.auth.pairDevice(_input), 'errors.connection_error');
    });

    test(
        '/auth/me failing after pairing shows an error and leaves NO '
        'half-session', () async {
      final h = await boot();
      h.repo.me = const Left(ServerFailure(message: 'RAW', code: 500));
      // `boot` ya consumió el /auth/me inicial; el siguiente es el del emparejado.

      final error = await h.auth.pairDevice(_input);

      expect(error, 'device.pair.errors.session_load_failed');
      expect(h.repo.signOuts, 1, reason: 'the fresh server session is closed');
      expect(await h.storage.contains(AppConstants.tokenKey), isFalse);
      expect(await h.storage.contains(AppConstants.refreshTokenKey), isFalse);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
    });

    test('an empty /auth/me is also rolled back', () async {
      final h = await boot();
      h.repo.me = const Right(null);

      final error = await h.auth.pairDevice(_input);

      expect(error, isNotNull);
      expect(h.repo.signOuts, 1);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
    });

    test('an /auth/me that is not a device principal is rolled back', () async {
      final h = await boot();
      h.repo.me = const Right(UserEntity(
        id: 'kid-1',
        principal: PrincipalInfo(kind: PrincipalKind.user),
      ));

      final error = await h.auth.pairDevice(_input);

      expect(error, isNotNull);
      expect(h.repo.signOuts, 1);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
    });

    test('pairing clears a stale unpaired notice', () async {
      final h = await boot();
      h.container.read(deviceNoticeProvider.notifier).state =
          DeviceNotice.unpaired;

      await h.auth.pairDevice(_input);

      expect(h.container.read(deviceNoticeProvider), isNull);
    });
  });

  group('cold start', () {
    test('a stored device session restored offline stays a device', () async {
      final h = await boot(
        stored: {
          AppConstants.tokenKey: 'device-jwt',
          AppConstants.sessionModeKey: 'device',
          AppConstants.cachedUserId: 'kid-1',
          AppConstants.cachedUserName: 'Ana',
        },
      );
      // `boot` arrancó sin red: se re-lee con /auth/me caído.
      h.repo.me = const Left(NetworkFailure(message: 'offline'));
      h.container.invalidate(authNotifierProvider);
      final user = await h.container.read(authNotifierProvider.future);

      expect(user!.id, 'kid-1');
      expect(user.isLinkedDevice, isTrue);
      expect(h.container.read(sessionModeProvider), SessionMode.device);
    });

    test('the server principal wins: a flag that says device but a user kind',
        () async {
      final h = await boot(
        stored: {
          AppConstants.tokenKey: 't',
          AppConstants.sessionModeKey: 'device',
        },
        me: const UserEntity(
          id: 'adult-1',
          postRegisterComplete: true,
          principal: PrincipalInfo(kind: PrincipalKind.user),
        ),
      );

      final user = h.container.read(authNotifierProvider).valueOrNull;
      expect(user!.isLinkedDevice, isFalse);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
      await Future<void>.delayed(Duration.zero);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse,
          reason: 'the mismatch rewrites the flag');
    });

    test('a device principal rewrites a missing flag', () async {
      final h = await boot(
        stored: {AppConstants.tokenKey: 'device-jwt'},
        me: _deviceUser,
      );

      expect(h.container.read(sessionModeProvider), SessionMode.device);
      await Future<void>.delayed(Duration.zero);
      expect(await h.storage.read(AppConstants.sessionModeKey), 'device');
    });

    test(
        'the flag says device but /auth/me has no principal: fail closed, '
        'never an adult', () async {
      final h = await boot(
        stored: {
          AppConstants.tokenKey: 't',
          AppConstants.sessionModeKey: 'device',
        },
        me: const UserEntity(id: 'kid-1', postRegisterComplete: true),
      );

      final user = h.container.read(authNotifierProvider).valueOrNull!;
      expect(user.mode, AccountMode.restricted);
      expect(user.isLinkedDevice, isFalse);
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('an orphan flag without a token is cleared', () async {
      final h = await boot(stored: {AppConstants.sessionModeKey: 'device'});

      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
    });
  });

  group('ending a device session', () {
    Future<
        ({
          ProviderContainer container,
          AuthNotifier auth,
          _Repo repo,
          FakeSecureStorage storage,
        })> pairedDevice() async {
      final h = await boot();
      await h.auth.pairDevice(_input);
      return (
        container: h.container,
        auth: h.auth,
        repo: h.repo,
        storage: h.storage,
      );
    }

    test(
        'onDeviceUnpaired logs out locally, leaves the notice and the flag off',
        () async {
      final h = await pairedDevice();

      h.auth.onDeviceUnpaired();

      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
      expect(h.container.read(deviceNoticeProvider), DeviceNotice.unpaired);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
      await Future<void>.delayed(Duration.zero);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(await h.storage.contains(AppConstants.cachedUserId), isFalse);
    });

    test('the absolute cap leaves its own notice', () async {
      final h = await pairedDevice();

      h.auth.onDeviceUnpaired(notice: DeviceNotice.sessionExpired);

      expect(
          h.container.read(deviceNoticeProvider), DeviceNotice.sessionExpired);
    });

    test('signing out ("Desvincular") resets the mode and revokes server-side',
        () async {
      final h = await pairedDevice();

      final ok = await h.auth.signOut();

      expect(ok, isTrue);
      expect(h.repo.signOuts, 1);
      expect(h.container.read(sessionModeProvider), SessionMode.account);
      expect(h.container.read(authNotifierProvider).valueOrNull, isNull);
      expect(await h.storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(h.container.read(deviceNoticeProvider), isNull,
          reason:
              'a voluntary unlink is not a "your guardian unlinked" notice');
    });
  });

  test('a device can never switch to acting for a dependent', () async {
    final storage = FakeSecureStorage();
    final repo = _Repo(storage)..me = const Right(_deviceUser);
    await storage.write(AppConstants.tokenKey, 't');
    final container = await buildAuthContainer(repo: repo, storage: storage);
    await container.read(authNotifierProvider.future);

    final outcome = await container
        .read(authNotifierProvider.notifier)
        .switchProfile('ana-1');

    expect(outcome, SwitchProfileOutcome.failed);
    expect(container.read(actingForSessionProvider).isActing, isFalse);
  });
}
