import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/providers/achievements_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';

import 'auth_notifier_test_support.dart';

/// El purge corre DENTRO del `Ref` de `AuthNotifier` (switchProfile, salir de
/// actuar, logout). Los providers del registro observan `authNotifierProvider`,
/// así que invalidarlos con ese `Ref` dispara el assert de debug
/// `CircularDependencyError` de Riverpod y el cambio de perfil muere antes de
/// pedir `/auth/me`. Los tests anteriores usaban centinelas sin dependencia de
/// auth y no lo veían.

/// Stand-in mínimo de `AuthNotifier`: expone la purga corriendo con SU `Ref`.
class _AuthLike extends Notifier<int> {
  @override
  int build() => 0;

  void purge() => purgeProfileScopeProviders(ref);
}

final _authLikeProvider = NotifierProvider<_AuthLike, int>(_AuthLike.new);

int _derivedBuilds = 0;

/// Depende de "auth" como lo hacen decenas de providers del registro.
final _derivedFromAuth = Provider<int>((ref) {
  _derivedBuilds++;
  return ref.watch(_authLikeProvider);
});

final _neverMounted = Provider<int>((ref) {
  fail('a provider that was never mounted must not be instantiated');
});

class _FakeAchievementsRepo implements AchievementsRepository {
  _FakeAchievementsRepo(this.onCall);

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

class _Repo extends FakeAuthRepository {
  _Repo(this._actingId);

  final String? Function() _actingId;
  final calls = <String?>[];

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    final id = _actingId();
    calls.add(id);
    if (id == null) {
      return const Right(
        UserEntity(
          id: 'guardian-1',
          email: 'maria@example.com',
          name: 'María',
          postRegisterComplete: true,
          family: FamilySummary(isGuardian: true, dependentsCount: 1),
        ),
      );
    }
    return Right(
      UserEntity(
        id: id,
        name: 'Ana',
        actingFor:
            ActingForInfo(actorUserId: 'guardian-1', dependentUserId: id),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async => const Right(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _derivedBuilds = 0;
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

  group('purgeProfileScopeProviders', () {
    ProviderContainer build(List<ProviderOrFamily> registry) {
      final container = ProviderContainer(
        overrides: [profileScopedProvidersProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
        'invalidates a registered provider that watches the provider running '
        'the purge, without CircularDependencyError', () {
      final container = build([_derivedFromAuth]);
      container.listen<int>(_derivedFromAuth, (_, __) {});
      expect(_derivedBuilds, 1);

      container.read(_authLikeProvider.notifier).purge();

      // La invalidación se materializa en la siguiente lectura.
      container.read(_derivedFromAuth);
      expect(_derivedBuilds, 2);
    });

    test('skips providers that were never mounted', () {
      final container = build([_neverMounted, _derivedFromAuth]);
      container.listen<int>(_derivedFromAuth, (_, __) {});

      container.read(_authLikeProvider.notifier).purge();

      expect(container.exists(_neverMounted), isFalse);
    });
  });

  group('with the REAL profileScopedProviders registry', () {
    test(
        'switchProfile reaches /auth/me even when a mounted registry provider '
        'watches authNotifierProvider', () async {
      late ProviderContainer container;
      final repo = _Repo(
        () => container.read(actingForSessionProvider).dependentUserId,
      );
      var achievementCalls = 0;
      container = await buildAuthContainer(
        repo: repo,
        extraOverrides: [
          jsonFileCacheProvider.overrideWithValue(MemoryJsonFileCache()),
          achievementsRepositoryProvider.overrideWithValue(
            _FakeAchievementsRepo(() => achievementCalls++),
          ),
          // NO se sobreescribe profileScopedProvidersProvider: registro real.
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      // `userAchievementsProvider` está en el registro real y hace
      // `ref.watch(authNotifierProvider.selectAsync(...))`.
      container.listen(userAchievementsProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.exists(userAchievementsProvider), isTrue);
      final callsBefore = achievementCalls;

      final outcome = await container
          .read(authNotifierProvider.notifier)
          .switchProfile('ana-1', firstName: 'Ana');

      expect(outcome, SwitchProfileOutcome.entered);
      expect(repo.calls.last, 'ana-1');
      expect(
        container.read(authNotifierProvider).valueOrNull?.id,
        'ana-1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        achievementCalls,
        greaterThan(callsBefore),
        reason: 'the mounted provider was invalidated and rebuilt',
      );

      // Salir de actuar corre la misma purga con el Ref de AuthNotifier.
      final exited = await container
          .read(authNotifierProvider.notifier)
          .switchProfile(null);
      expect(exited, SwitchProfileOutcome.exited);
      await container.read(authNotifierProvider.future);
      expect(repo.calls.last, isNull);
    });
  });
}
