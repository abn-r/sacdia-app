import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../../family/family_test_harness.dart';
import 'auth_notifier_test_support.dart';

const _grant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  permissions: ['clubs:read'],
  clubId: 1,
  sectionId: 4,
  clubTypeId: 2,
  clubName: 'ACV',
  clubTypeName: 'Conquistadores',
  status: 'active',
);

UserEntity _me({
  List<String> capabilities = const ['club.operational_staff'],
  List<String> permissions = const ['clubs:read'],
  AuthorizationTerritory? territory,
  String id = 'adult-1',
  String? name = 'Laura',
  PrincipalKind kind = PrincipalKind.user,
}) =>
    UserEntity(
      id: id,
      email: '$id@example.com',
      name: name,
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: permissions,
        clubAssignments: const [_grant],
        activeAssignmentId: 'a1',
        capabilities: capabilities,
        territory: territory,
      ),
      principal: PrincipalInfo(kind: kind),
    );

class _Repo extends FakeAuthRepository {
  _Repo(this.me);

  Either<Failure, UserEntity?> me;
  int meCalls = 0;

  /// Si está, cada `/auth/me` espera a que se complete (vuelo controlado).
  Completer<void>? gate;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    meCalls++;
    final pending = gate;
    if (pending != null) await pending.future;
    return me;
  }
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

class _NullDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<ProviderContainer> build(
    _Repo repo, {
    FakeSecureStorage? storage,
    List<Override> extra = const [],
  }) async {
    final container = await buildAuthContainer(
      repo: repo,
      storage: storage,
      extraOverrides: [
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        ...extra,
      ],
    );
    await container.read(authNotifierProvider.future);
    return container;
  }

  group('refreshAuthorization', () {
    test('publishes when the capabilities change (adult too)', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      expect(
        hasCapability(c.read(authNotifierProvider).value, 'units.manage'),
        isFalse,
      );

      repo.me = Right(_me(capabilities: const ['units.manage']));
      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isTrue);
      expect(
        hasCapability(c.read(authNotifierProvider).value, 'units.manage'),
        isTrue,
      );
    });

    test('publishes when permissions or territory change', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      final notifier = c.read(authNotifierProvider.notifier);

      repo.me = Right(_me(permissions: const ['clubs:read', 'units:update']));
      expect(await notifier.refreshAuthorization(minInterval: Duration.zero),
          isTrue);

      repo.me = Right(_me(
        permissions: const ['clubs:read', 'units:update'],
        territory: const AuthorizationTerritory(level: 'all'),
      ));
      expect(await notifier.refreshAuthorization(minInterval: Duration.zero),
          isTrue);
      expect(
        c.read(authNotifierProvider).value!.authorization!.territory!.level,
        'all',
      );
    });

    test('an unchanged authorization does not republish (no churn)', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      final before = c.read(authNotifierProvider).value;

      // Otro nombre: no es autorización, no se republica.
      repo.me = Right(_me(name: 'Laura G.'));
      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isFalse);
      expect(identical(c.read(authNotifierProvider).value, before), isTrue);
    });

    test('the minimum interval throttles; Duration.zero does not', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      final notifier = c.read(authNotifierProvider.notifier);
      final calls = repo.meCalls;

      await notifier.refreshAuthorization();
      await notifier.refreshAuthorization();
      await notifier.refreshAuthorization();
      expect(repo.meCalls - calls, 1);

      await notifier.refreshAuthorization(minInterval: Duration.zero);
      expect(repo.meCalls - calls, 2);
    });

    test('a failure leaves the state alone', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      final before = c.read(authNotifierProvider).value;

      repo.me = const Left(NetworkFailure(message: 'offline'));
      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isFalse);
      expect(c.read(authNotifierProvider).value, before);
      expect(c.read(authNotifierProvider).hasError, isFalse);
    });

    test('a failed fetch does not consume the minimum interval', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);
      final notifier = c.read(authNotifierProvider.notifier);
      final calls = repo.meCalls;

      // Sin red: cada `resumed` vuelve a intentarlo, nada lo bloquea 30 s.
      repo.me = const Left(NetworkFailure(message: 'offline'));
      expect(await notifier.refreshAuthorization(), isFalse);
      expect(await notifier.refreshAuthorization(), isFalse);
      expect(repo.meCalls - calls, 2);

      // La primera respuesta fresca abre la ventana.
      repo.me = Right(_me());
      expect(await notifier.refreshAuthorization(), isFalse);
      expect(repo.meCalls - calls, 3);
      expect(await notifier.refreshAuthorization(), isFalse);
      expect(repo.meCalls - calls, 3, reason: 'throttled after a success');
    });

    test('a response that lands after acting started is discarded', () async {
      final storage = FakeSecureStorage();
      final repo = _Repo(Right(_me()));
      final session = ActingForSession();
      final c = await build(
        repo,
        storage: storage,
        extra: [actingForSessionProvider.overrideWithValue(session)],
      );
      final notifier = c.read(authNotifierProvider.notifier);
      final before = c.read(authNotifierProvider).value;

      repo.gate = Completer<void>();
      repo.me = Right(_me(capabilities: const ['units.manage']));
      final inFlight =
          notifier.refreshAuthorization(minInterval: Duration.zero);
      // El usuario empieza a actuar por un menor mientras `/auth/me` vuela.
      session.enter(const ActingDependent(userId: 'ana-1'));
      repo.gate!.complete();

      expect(await inFlight, isFalse);
      expect(identical(c.read(authNotifierProvider).value, before), isTrue);
      expect(
        hasCapability(c.read(authNotifierProvider).value, 'units.manage'),
        isFalse,
      );
      // Tampoco se cachea como la autorización del perfil activo.
      expect(
        jsonDecode(
          (await storage.read(AppConstants.cachedAuthorizationCapabilities))!,
        ),
        ['club.operational_staff'],
      );
    });

    test('a response for another account is ignored', () async {
      final repo = _Repo(Right(_me()));
      final c = await build(repo);

      repo.me = Right(_me(id: 'someone-else', capabilities: const []));
      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isFalse);
      expect(c.read(authNotifierProvider).value!.id, 'adult-1');
    });

    test('never runs while acting for a minor', () async {
      final repo = _Repo(Right(_me()));
      final session = ActingForSession();
      final c = await build(
        repo,
        extra: [actingForSessionProvider.overrideWithValue(session)],
      );
      session.enter(const ActingDependent(userId: 'ana-1'));
      final calls = repo.meCalls;

      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isFalse);
      expect(repo.meCalls, calls);
    });

    test('authorizationChanged compares only what decides access', () {
      final a = _me();
      expect(AuthNotifier.authorizationChanged(a, _me(name: 'x')), isFalse);
      expect(
        AuthNotifier.authorizationChanged(
            a, _me(capabilities: const ['units.manage'])),
        isTrue,
      );
      expect(
        AuthNotifier.authorizationChanged(
          a,
          UserEntity(
            id: a.id,
            email: a.email,
            authorization: a.authorization,
            authorizationStale: true,
          ),
        ),
        isTrue,
      );
    });
  });

  group('offline restore marks the authorization stale', () {
    FakeSecureStorage cachedSession() {
      final storage = FakeSecureStorage();
      storage.write(AppConstants.cachedUserId, 'adult-1');
      storage.write(AppConstants.cachedUserEmail, 'adult-1@example.com');
      storage.write(AppConstants.cachedUserName, 'Laura');
      storage.write(AppConstants.cachedActiveAssignmentId, 'a1');
      storage.write(AppConstants.cachedActiveRoleName, 'counselor');
      storage.write(AppConstants.cachedActiveClubId, '1');
      storage.write(AppConstants.cachedActiveSectionId, '4');
      storage.write(
        AppConstants.cachedActivePermissions,
        jsonEncode(['clubs:read']),
      );
      storage.write(
        AppConstants.cachedAuthorizationCapabilities,
        jsonEncode(['club.operational_staff', 'club.staff_mode']),
      );
      storage.write(
        AppConstants.cachedAuthorizationFetchedAt,
        '2026-11-03T20:00:00.000Z',
      );
      return storage;
    }

    test('restores capabilities from the cache, read-only until /auth/me',
        () async {
      final repo = _Repo(const Left(NetworkFailure(message: 'offline')));
      final c = await build(repo, storage: cachedSession());

      final user = c.read(authNotifierProvider).value!;
      expect(user.id, 'adult-1');
      expect(user.authorizationStale, isTrue);
      expect(hasCapability(user, 'club.staff_mode'), isTrue);
      expect(hasCapability(user, 'club.operational_staff'), isTrue);
      expect(user.authorization!.activeGrant?.assignmentId, 'a1');
    });

    test('the next fresh /auth/me clears the stale flag', () async {
      final repo = _Repo(const Left(NetworkFailure(message: 'offline')));
      final c = await build(repo, storage: cachedSession());
      expect(c.read(authNotifierProvider).value!.authorizationStale, isTrue);

      // Misma autorización que la cacheada: aun así se publica, porque la
      // marca de obsolescencia cambia.
      repo.me = Right(_me(
        capabilities: const ['club.operational_staff', 'club.staff_mode'],
      ));
      final changed = await c
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero);

      expect(changed, isTrue);
      expect(c.read(authNotifierProvider).value!.authorizationStale, isFalse);
    });

    test('recovering the network refreshes a stale authorization at once',
        () async {
      final repo = _Repo(const Left(NetworkFailure(message: 'offline')));
      final c = await build(repo, storage: cachedSession());
      final notifier = c.read(authNotifierProvider.notifier);
      expect(c.read(authNotifierProvider).value!.authorizationStale, isTrue);

      // Mientras no hay red, el reintento falla y no consume la ventana.
      expect(await notifier.onConnectivityRestored(), isFalse);
      expect(c.read(authNotifierProvider).value!.authorizationStale, isTrue);

      // Vuelve la red: se refresca sin esperar el intervalo mínimo.
      repo.me = Right(_me(
        capabilities: const ['club.operational_staff', 'club.staff_mode'],
      ));
      final calls = repo.meCalls;
      expect(await notifier.onConnectivityRestored(), isTrue);
      expect(repo.meCalls - calls, 1);
      expect(c.read(authNotifierProvider).value!.authorizationStale, isFalse);

      // Con la autorización fresca, recuperar la red no pide nada.
      expect(await notifier.onConnectivityRestored(), isFalse);
      expect(repo.meCalls - calls, 1);
    });

    test('a session without cached capabilities restores with none (deny)',
        () async {
      final storage = cachedSession();
      await storage.delete(AppConstants.cachedAuthorizationCapabilities);
      final repo = _Repo(const Left(NetworkFailure(message: 'offline')));
      final c = await build(repo, storage: storage);

      final user = c.read(authNotifierProvider).value!;
      expect(user.authorizationStale, isTrue);
      expect(user.authorization!.capabilities, isEmpty);
      expect(hasCapability(user, 'club.staff_mode'), isFalse);
    });
  });

  group('cache lifecycle', () {
    test('a fresh /auth/me caches the capabilities and the fetch time',
        () async {
      final storage = FakeSecureStorage();
      final repo = _Repo(Right(_me()));
      final c = await build(repo, storage: storage);
      expect(c.read(authNotifierProvider).value, isNotNull);

      expect(
        jsonDecode(
          (await storage.read(AppConstants.cachedAuthorizationCapabilities))!,
        ),
        ['club.operational_staff'],
      );
      expect(
        await storage.read(AppConstants.cachedAuthorizationFetchedAt),
        isNotNull,
      );
    });

    test('expiring the session deletes both keys', () async {
      final storage = FakeSecureStorage();
      final repo = _Repo(Right(_me()));
      final c = await build(repo, storage: storage);

      c.read(authNotifierProvider.notifier).expireSession();

      expect(
        await storage.read(AppConstants.cachedAuthorizationCapabilities),
        isNull,
      );
      expect(
        await storage.read(AppConstants.cachedAuthorizationFetchedAt),
        isNull,
      );
    });
  });
}
