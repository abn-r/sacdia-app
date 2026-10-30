import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/storage/image_cache_purge.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/logout_cleanup.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

const _guardian = UserEntity(
  id: 'guardian-1',
  email: 'maria@example.com',
  name: 'María',
  postRegisterComplete: true,
  family: FamilySummary(isGuardian: true, dependentsCount: 2),
);

UserEntity _dependent(String id, String name) => UserEntity(
      id: id,
      name: name,
      actingFor: ActingForInfo(actorUserId: 'guardian-1', dependentUserId: id),
    );

typedef _Reply = Future<Either<Failure, UserEntity?>>;

/// Repositorio cuyo `/auth/me` depende de a quién se actúa: el id del
/// dependiente (o `null` si es el tutor) se lee de la sesión real.
class _ProfileRepo extends FakeAuthRepository {
  _ProfileRepo(this._actingId, this.reply);

  final String? Function() _actingId;
  _Reply Function(String? actingId) reply;
  final calls = <String?>[];
  int signOutCalls = 0;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() {
    final id = _actingId();
    calls.add(id);
    return reply(id);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOutCalls++;
    return const Right(null);
  }
}

_Reply _byId(String? id) async {
  if (id == null) return const Right(_guardian);
  return Right(_dependent(id, id == 'ana-1' ? 'Ana' : 'Luis'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _ProfileRepo repo;
  late FakeSecureStorage storage;
  late SharedPreferences prefs;
  late MemoryJsonFileCache diskCache;
  var imagePurges = 0;

  // Estado de prueba que representa "datos de un perfil": el registro real
  // tiene decenas de providers con red, aquí se usa un centinela.
  final profileData = StateProvider<String>((ref) => 'initial');

  setUp(() {
    // Salir/entrar de perfil también limpia el widget de la pantalla de inicio.
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

  Future<void> boot({_Reply Function(String? id)? reply}) async {
    imagePurges = 0;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = FakeSecureStorage();
    diskCache = MemoryJsonFileCache();
    repo = _ProfileRepo(
      () => container.read(actingForSessionProvider).dependentUserId,
      reply ?? _byId,
    );
    container = await buildAuthContainer(
      repo: repo,
      storage: storage,
      prefs: prefs,
      extraOverrides: [
        jsonFileCacheProvider.overrideWithValue(diskCache),
        profileScopedProvidersProvider.overrideWithValue([profileData]),
        imageCachePurgerProvider.overrideWithValue(() async => imagePurges++),
      ],
    );
    // Mantiene vivo el centinela, como lo haría un provider `keepAlive`.
    container.listen<String>(profileData, (_, __) {});
    await container.read(authNotifierProvider.future);
  }

  AuthNotifier notifier() => container.read(authNotifierProvider.notifier);
  UserEntity? current() => container.read(authNotifierProvider).valueOrNull;
  ActingForSession session() => container.read(actingForSessionProvider);
  FakePushNotificationService push() =>
      container.read(pushNotificationServiceProvider)
          as FakePushNotificationService;

  group('entering a dependent', () {
    test('snapshots the guardian, raises the flag and loads the dependent',
        () async {
      await boot();

      final outcome = await notifier().switchProfile('ana-1', firstName: 'Ana');

      expect(outcome, SwitchProfileOutcome.entered);
      expect(current()?.id, 'ana-1');
      expect(current()?.actingFor?.dependentUserId, 'ana-1');
      expect(session().dependentUserId, 'ana-1');
      expect(session().value?.firstName, 'Ana');
      expect(container.read(guardianUserProvider)?.id, 'guardian-1');
      expect(prefs.getBool(kActingDirtyPrefsKey), isTrue);
      // /auth/me se pidió ya con la sesión del dependiente.
      expect(repo.calls.last, 'ana-1');
    });

    test('writes nothing of the dependent to the caches (FP-49)', () async {
      await boot();
      expect(await storage.read(AppConstants.cachedUserId), 'guardian-1');
      expect(prefs.getBool('cached_post_register_complete'), isTrue);

      await notifier().switchProfile('ana-1', firstName: 'Ana');
      notifier().markPostRegisterIncomplete(); // would call _cacheUser
      notifier().markPostRegisterComplete();

      expect(await storage.read(AppConstants.cachedUserId), 'guardian-1');
      expect(await storage.read(AppConstants.cachedUserName), 'María');
      expect(
        await storage.read(AppConstants.cachedUserEmail),
        'maria@example.com',
      );
      expect(prefs.getBool('cached_post_register_complete'), isTrue);
      expect(
        (await storage.readAll()).values,
        isNot(contains('ana-1')),
        reason: 'nothing identifying the dependent is persisted',
      );
    });

    test('does not register push for the dependent (FP-49)', () async {
      await boot();
      final before = push().initializeCalls;

      await notifier().switchProfile('ana-1', firstName: 'Ana');

      expect(push().initializeCalls, before);
    });

    test('switching to the same profile or to the guardian id is a no-op',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      final calls = repo.calls.length;

      expect(
        await notifier().switchProfile('ana-1'),
        SwitchProfileOutcome.unchanged,
      );
      expect(repo.calls.length, calls);

      await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);
      expect(
        await notifier().switchProfile('guardian-1'),
        SwitchProfileOutcome.failed,
      );
      expect(session().isActing, isFalse);
    });
  });

  group('cache isolation (FP-48)', () {
    test('guardian -> Ana -> Luis -> guardian shows only each own data',
        () async {
      await boot();
      container.read(profileData.notifier).state = 'guardian-data';
      await diskCache.write(userClassesCacheKey('guardian-1'), {'c': 1});
      await diskCache.write(kAllClassesCacheKey, {'catalog': true});

      await notifier().switchProfile('ana-1');
      expect(container.read(profileData), 'initial');
      expect(await diskCache.read(userClassesCacheKey('guardian-1')), isNull);
      // El catálogo no depende del perfil: se conserva.
      expect(await diskCache.read(kAllClassesCacheKey), isNotNull);
      container.read(profileData.notifier).state = 'ana-data';

      await notifier().switchProfile('luis-1');
      expect(current()?.id, 'luis-1');
      expect(container.read(profileData), 'initial');
      container.read(profileData.notifier).state = 'luis-data';

      await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);
      expect(current()?.id, 'guardian-1');
      expect(container.read(profileData), 'initial');
      expect(session().isActing, isFalse);
    });

    test('no data of the previous profile is visible while the next loads',
        () async {
      final gate = Completer<Either<Failure, UserEntity?>>();
      await boot(
        reply: (id) => id == 'ana-1' ? gate.future : _byId(id),
      );
      container.read(profileData.notifier).state = 'guardian-data';

      final switching = notifier().switchProfile('ana-1');
      await pumpEventQueue();

      // Riverpod 2.6 conserva el valor previo dentro de `AsyncLoading`, así que
      // lo que garantiza el aislamiento es `isLoading` (el router manda al
      // splash y `selectAsync` espera) más la purga del registro, no `null`.
      final loading = container.read(authNotifierProvider);
      expect(loading.isLoading, isTrue);
      expect(container.read(profileData), 'initial');
      expect(session().dependentUserId, 'ana-1');

      gate.complete(Right(_dependent('ana-1', 'Ana')));
      expect(await switching, SwitchProfileOutcome.entered);
      expect(current()?.id, 'ana-1');
    });

    test('entering and exiting purge every virtual_card_cache_ key (C1)',
        () async {
      await boot();
      await prefs.setString('virtual_card_cache_guardian-1', '{"g":1}');
      await prefs.setString('virtual_card_cache_ana-1', '{"a":1}');
      await prefs.setString('unrelated_key', 'keep');

      await notifier().switchProfile('ana-1');
      expect(
        prefs.getKeys().where((k) => k.startsWith('virtual_card_cache_')),
        isEmpty,
        reason: 'entering a profile drops every stored card',
      );

      // La tarjeta de Ana se escribe (p. ej. una petición en vuelo) y al salir
      // tampoco puede quedar nada.
      await prefs.setString('virtual_card_cache_ana-1', '{"a":1}');
      await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);
      expect(
        prefs.getKeys().where((k) => k.startsWith('virtual_card_cache_')),
        isEmpty,
        reason: 'exiting a profile drops every stored card',
      );
      expect(prefs.getString('unrelated_key'), 'keep');
    });

    test('entering and exiting purge every non-guardian health_none flag (W1)',
        () async {
      await boot();
      const scope = 'post_registration.health_none';
      await prefs.setBool('$scope.guardian-1.allergies', true);
      await prefs.setBool('$scope.ana-1.allergies', true);
      await prefs.setBool('$scope.luis-1.medicines', true);
      await prefs.setString('unrelated_key', 'keep');

      await notifier().switchProfile('ana-1');
      expect(
        prefs.getKeys().where((k) => k.startsWith(scope)).toSet(),
        {'$scope.guardian-1.allergies'},
        reason: 'entering drops every dependent flag, keeps the guardian own',
      );

      // El paso 2 escribe mientras se actúa (para que funcione la sesión)...
      await prefs.setBool('$scope.ana-1.diseases', true);
      // ...y al salir no puede quedar rastro del menor.
      await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);
      expect(
        prefs.getKeys().where((k) => k.startsWith(scope)).toSet(),
        {'$scope.guardian-1.allergies'},
        reason: 'exiting drops the dependent flags written while acting',
      );
      expect(prefs.getString('unrelated_key'), 'keep');
    });

    test('image caches are emptied on exit, not on entering (S5)', () async {
      await boot();

      await notifier().switchProfile('ana-1');
      expect(imagePurges, 0, reason: 'the guardian images are still valid');

      await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);
      expect(imagePurges, 1, reason: "Ana's photos and evidence must not stay");
    });

    test('exiting to the guardian lowers the flag and drops the snapshot',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');

      final outcome = await notifier().switchProfile(null);
      await container.read(authNotifierProvider.future);

      expect(outcome, SwitchProfileOutcome.exited);
      expect(session().isActing, isFalse);
      expect(current()?.id, 'guardian-1');
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
      expect(container.read(guardianUserProvider), isNull);
    });
  });

  test('production purges exactly the profile scope registry', () {
    final plain = createTestContainer();

    expect(plain.read(profileScopedProvidersProvider), profileScopedProviders);
  });

  group('rapid switching (FP-54)', () {
    test('Ana in flight, Luis requested: Ana result never reaches the state',
        () async {
      final gates = <String, Completer<Either<Failure, UserEntity?>>>{
        'ana-1': Completer(),
        'luis-1': Completer(),
      };
      await boot(reply: (id) => id == null ? _byId(id) : gates[id]!.future);

      final ana = notifier().switchProfile('ana-1');
      await pumpEventQueue();
      final luis = notifier().switchProfile('luis-1');
      await pumpEventQueue();

      // Luis responde primero; Ana llega tarde.
      gates['luis-1']!.complete(Right(_dependent('luis-1', 'Luis')));
      gates['ana-1']!.complete(Right(_dependent('ana-1', 'Ana')));

      expect(await ana, SwitchProfileOutcome.superseded);
      expect(await luis, SwitchProfileOutcome.entered);
      expect(current()?.id, 'luis-1');
      expect(session().dependentUserId, 'luis-1');
      expect(container.read(guardianUserProvider)?.id, 'guardian-1');
    });

    test('Ana answers before Luis does: still Luis at the end', () async {
      final gates = <String, Completer<Either<Failure, UserEntity?>>>{
        'ana-1': Completer(),
        'luis-1': Completer(),
      };
      await boot(reply: (id) => id == null ? _byId(id) : gates[id]!.future);

      final ana = notifier().switchProfile('ana-1');
      await pumpEventQueue();
      final luis = notifier().switchProfile('luis-1');
      await pumpEventQueue();

      gates['ana-1']!.complete(Right(_dependent('ana-1', 'Ana')));
      await pumpEventQueue();
      expect(
        container.read(authNotifierProvider).isLoading,
        isTrue,
        reason: 'Ana result must not be published while Luis is loading',
      );
      expect(session().dependentUserId, 'luis-1');
      gates['luis-1']!.complete(Right(_dependent('luis-1', 'Luis')));

      expect(await ana, SwitchProfileOutcome.superseded);
      expect(await luis, SwitchProfileOutcome.entered);
      expect(current()?.id, 'luis-1');
    });

    test('exiting while a switch is in flight cancels it', () async {
      final gate = Completer<Either<Failure, UserEntity?>>();
      await boot(reply: (id) => id == 'ana-1' ? gate.future : _byId(id));

      final ana = notifier().switchProfile('ana-1');
      await pumpEventQueue();
      final exit = notifier().switchProfile(null);
      await pumpEventQueue();
      gate.complete(Right(_dependent('ana-1', 'Ana')));

      expect(await ana, SwitchProfileOutcome.superseded);
      expect(await exit, SwitchProfileOutcome.exited);
      await container.read(authNotifierProvider.future);
      expect(current()?.id, 'guardian-1');
      expect(session().isActing, isFalse);
    });
  });

  group('post-registration marks are guarded (S1)', () {
    test(
        'a late mark during a profile switch does not republish the previous '
        'profile', () async {
      final gate = Completer<Either<Failure, UserEntity?>>();
      await boot(reply: (id) => id == 'ana-1' ? gate.future : _byId(id));

      final switching = notifier().switchProfile('ana-1');
      await pumpEventQueue();
      expect(container.read(authNotifierProvider).isLoading, isTrue);

      // Una llamada tardía del post-registro del tutor llega a mitad del cambio.
      notifier().markPostRegisterIncomplete();
      notifier().markPostRegisterComplete();

      expect(
        container.read(authNotifierProvider).isLoading,
        isTrue,
        reason: 'the guardian must not be republished as data while loading',
      );
      gate.complete(Right(_dependent('ana-1', 'Ana')));
      await switching;
      expect(current()?.id, 'ana-1');
    });

    test('a mark meant for another user id is ignored', () async {
      await boot();
      await notifier().switchProfile('ana-1');
      expect(current()?.postRegisterComplete, isFalse);

      notifier().markPostRegisterComplete(forUserId: 'guardian-1');

      expect(current()?.id, 'ana-1');
      expect(current()?.postRegisterComplete, isFalse);
    });

    test('a mark for the current user still applies', () async {
      await boot();
      notifier().markPostRegisterIncomplete(forUserId: 'guardian-1');
      expect(current()?.postRegisterComplete, isFalse);

      notifier().markPostRegisterComplete(forUserId: 'guardian-1');
      expect(current()?.postRegisterComplete, isTrue);
    });
  });

  group('failures while acting (FP-50, FP-55)', () {
    test('offline on entering returns to the guardian, never the dependent',
        () async {
      await boot(
        reply: (id) async => id == null
            ? const Right(_guardian)
            : const Left(NetworkFailure(message: 'offline')),
      );

      final outcome = await notifier().switchProfile('ana-1');
      await container.read(authNotifierProvider.future);

      expect(outcome, SwitchProfileOutcome.offline);
      expect(session().isActing, isFalse);
      expect(current()?.id, 'guardian-1');
      expect(container.read(actingNoticeProvider), isNull);
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
    });

    test('ACTING_FOR_FORBIDDEN on entering exits with a message', () async {
      await boot(
        reply: (id) async => id == null
            ? const Right(_guardian)
            : const Left(AuthFailure(
                message: 'forbidden',
                code: 403,
                errorCode: 'ACTING_FOR_FORBIDDEN',
              )),
      );

      final outcome = await notifier().switchProfile('ana-1');
      await container.read(authNotifierProvider.future);

      expect(outcome, SwitchProfileOutcome.accessRevoked);
      expect(session().isActing, isFalse);
      expect(current()?.id, 'guardian-1');
      expect(container.read(actingNoticeProvider), ActingNotice.accessRevoked);
    });

    test('a generic failure on entering returns to the guardian', () async {
      await boot(
        reply: (id) async => id == null
            ? const Right(_guardian)
            : const Left(ServerFailure(message: 'boom', code: 500)),
      );

      final outcome = await notifier().switchProfile('ana-1');
      await container.read(authNotifierProvider.future);

      expect(outcome, SwitchProfileOutcome.failed);
      expect(current()?.id, 'guardian-1');
      expect(container.read(actingNoticeProvider), isNull);
    });

    test('a 403 mid-session (interceptor callback) exits to the guardian',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      container.read(profileData.notifier).state = 'ana-data';

      notifier().onActingForbidden('ana-1');
      await pumpEventQueue();
      await container.read(authNotifierProvider.future);

      expect(session().isActing, isFalse);
      expect(current()?.id, 'guardian-1');
      expect(container.read(profileData), 'initial');
      expect(container.read(actingNoticeProvider), ActingNotice.accessRevoked);
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
    });

    test('a 403 reported for a profile already left is ignored', () async {
      await boot();
      await notifier().switchProfile('ana-1');
      await notifier().switchProfile('luis-1');

      notifier().onActingForbidden('ana-1');
      await pumpEventQueue();

      expect(session().dependentUserId, 'luis-1');
      expect(current()?.id, 'luis-1');
      expect(container.read(actingNoticeProvider), isNull);
    });

    test('network failure on a rebuild while acting restores the GUARDIAN',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      // A partir de ahora no hay red.
      repo.reply = (_) async => const Left(NetworkFailure(message: 'offline'));

      container.invalidate(authNotifierProvider);
      final user = await container.read(authNotifierProvider.future);

      expect(session().isActing, isFalse);
      expect(
        user?.id,
        'guardian-1',
        reason:
            'the cached user is the guardian; the dependent is never cached',
      );
      expect(user?.actingFor, isNull);
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
    });

    test('a rebuild while acting keeps acting and does not cache', () async {
      await boot();
      await notifier().switchProfile('ana-1');
      final pushBefore = push().initializeCalls;

      container.invalidate(authNotifierProvider);
      final user = await container.read(authNotifierProvider.future);

      expect(user?.id, 'ana-1');
      expect(session().dependentUserId, 'ana-1');
      expect(prefs.getBool(kActingDirtyPrefsKey), isTrue);
      expect(await storage.read(AppConstants.cachedUserId), 'guardian-1');
      expect(push().initializeCalls, pushBefore);
    });
  });

  group('cold start cleanup (FP-51)', () {
    test('acting_dirty on launch purges the disk caches and lowers the flag',
        () async {
      SharedPreferences.setMockInitialValues({
        kActingDirtyPrefsKey: true,
        '${AppConstants.dashboardSummaryCacheKeyPrefix}_ana-1_assignment_a':
            '{"x":1}',
        'unrelated': 'keep',
      });
      prefs = await SharedPreferences.getInstance();
      storage = FakeSecureStorage();
      diskCache = MemoryJsonFileCache();
      await diskCache.write(userClassesCacheKey('ana-1'), {'c': 1});
      await diskCache.write(kAllClassesCacheKey, {'catalog': true});
      repo = _ProfileRepo(
        () => container.read(actingForSessionProvider).dependentUserId,
        _byId,
      );
      container = await buildAuthContainer(
        repo: repo,
        storage: storage,
        prefs: prefs,
        extraOverrides: [jsonFileCacheProvider.overrideWithValue(diskCache)],
      );

      final user = await container.read(authNotifierProvider.future);

      expect(user?.id, 'guardian-1', reason: 'always cold-starts as guardian');
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
      expect(await diskCache.read(userClassesCacheKey('ana-1')), isNull);
      expect(await diskCache.read(kAllClassesCacheKey), isNotNull);
      expect(
        prefs.getString(
          '${AppConstants.dashboardSummaryCacheKeyPrefix}_ana-1_assignment_a',
        ),
        isNull,
      );
      expect(prefs.getString('unrelated'), 'keep');
    });

    test('acting_dirty on launch also purges stored virtual cards (C1)',
        () async {
      SharedPreferences.setMockInitialValues({
        kActingDirtyPrefsKey: true,
        'virtual_card_cache_ana-1': '{"full_name":"Ana"}',
      });
      prefs = await SharedPreferences.getInstance();
      storage = FakeSecureStorage();
      diskCache = MemoryJsonFileCache();
      repo = _ProfileRepo(
        () => container.read(actingForSessionProvider).dependentUserId,
        _byId,
      );
      container = await buildAuthContainer(
        repo: repo,
        storage: storage,
        prefs: prefs,
        extraOverrides: [jsonFileCacheProvider.overrideWithValue(diskCache)],
      );

      await container.read(authNotifierProvider.future);

      expect(prefs.getString('virtual_card_cache_ana-1'), isNull);
    });

    test(
        'acting_dirty on launch purges dependent health_none flags but keeps '
        "the guardian's (W1)", () async {
      SharedPreferences.setMockInitialValues({
        kActingDirtyPrefsKey: true,
        'post_registration.health_none.ana-1.allergies': true,
        'post_registration.health_none.guardian-1.allergies': true,
      });
      prefs = await SharedPreferences.getInstance();
      storage = FakeSecureStorage();
      await storage.write(AppConstants.cachedUserId, 'guardian-1');
      diskCache = MemoryJsonFileCache();
      repo = _ProfileRepo(
        () => container.read(actingForSessionProvider).dependentUserId,
        _byId,
      );
      container = await buildAuthContainer(
        repo: repo,
        storage: storage,
        prefs: prefs,
        extraOverrides: [jsonFileCacheProvider.overrideWithValue(diskCache)],
      );

      await container.read(authNotifierProvider.future);

      expect(
        prefs.getKeys().where((k) => k.startsWith('post_registration.')),
        {'post_registration.health_none.guardian-1.allergies'},
      );
    });

    test(
        'acting_dirty on launch with no cached guardian purges every '
        'health_none flag (conservative)', () async {
      SharedPreferences.setMockInitialValues({
        kActingDirtyPrefsKey: true,
        'post_registration.health_none.ana-1.allergies': true,
        'post_registration.health_none.someone.allergies': true,
      });
      prefs = await SharedPreferences.getInstance();
      storage = FakeSecureStorage();
      diskCache = MemoryJsonFileCache();
      repo = _ProfileRepo(
        () => container.read(actingForSessionProvider).dependentUserId,
        _byId,
      );
      container = await buildAuthContainer(
        repo: repo,
        storage: storage,
        prefs: prefs,
        extraOverrides: [jsonFileCacheProvider.overrideWithValue(diskCache)],
      );

      await container.read(authNotifierProvider.future);

      expect(
        prefs.getKeys().where((k) => k.startsWith('post_registration.')),
        isEmpty,
      );
    });

    test('acting_dirty on launch also empties the image caches (S5)', () async {
      imagePurges = 0;
      SharedPreferences.setMockInitialValues({kActingDirtyPrefsKey: true});
      prefs = await SharedPreferences.getInstance();
      storage = FakeSecureStorage();
      diskCache = MemoryJsonFileCache();
      repo = _ProfileRepo(
        () => container.read(actingForSessionProvider).dependentUserId,
        _byId,
      );
      container = await buildAuthContainer(
        repo: repo,
        storage: storage,
        prefs: prefs,
        extraOverrides: [
          jsonFileCacheProvider.overrideWithValue(diskCache),
          imageCachePurgerProvider.overrideWithValue(() async => imagePurges++),
        ],
      );

      await container.read(authNotifierProvider.future);

      expect(imagePurges, 1);
    });

    test('a clean flag leaves the caches alone', () async {
      await boot();
      await diskCache.write(userClassesCacheKey('guardian-1'), {'c': 1});

      container.invalidate(authNotifierProvider);
      await container.read(authNotifierProvider.future);

      expect(
        await diskCache.read(userClassesCacheKey('guardian-1')),
        isNotNull,
      );
    });
  });

  group('logout while acting (FP-53)', () {
    test('signOut clears the acting session before touching auth', () async {
      await boot();
      await notifier().switchProfile('ana-1');
      container.read(actingNoticeProvider.notifier).state =
          ActingNotice.accessRevoked;

      final ok = await notifier().signOut();

      expect(ok, isTrue);
      expect(repo.signOutCalls, 1);
      expect(session().isActing, isFalse);
      expect(container.read(guardianUserProvider), isNull);
      expect(container.read(actingNoticeProvider), isNull);
      expect(current(), isNull);
    });

    test('expireSession while acting also clears the session', () async {
      await boot();
      await notifier().switchProfile('ana-1');

      notifier().expireSession();

      expect(session().isActing, isFalse);
      expect(container.read(guardianUserProvider), isNull);
      expect(current(), isNull);
    });

    test('logout cleanup lowers the flag, drops state and purges the registry',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      container.read(profileData.notifier).state = 'ana-data';
      expect(prefs.getBool(kActingDirtyPrefsKey), isTrue);

      container.read(_cleanupInvoker)();
      await pumpEventQueue();

      expect(session().isActing, isFalse);
      expect(container.read(guardianUserProvider), isNull);
      expect(prefs.getBool(kActingDirtyPrefsKey), isFalse);
      expect(container.read(profileData), 'initial');
    });

    test('logout cleanup purges stored virtual cards (C1)', () async {
      await boot();
      await notifier().switchProfile('ana-1');
      await prefs.setString('virtual_card_cache_ana-1', '{"a":1}');
      await prefs.setString('virtual_card_cache_guardian-1', '{"g":1}');

      container.read(_cleanupInvoker)();
      await pumpEventQueue();

      expect(
        prefs.getKeys().where((k) => k.startsWith('virtual_card_cache_')),
        isEmpty,
      );
    });

    test('logout cleanup purges ALL health_none flags, guardian included (W1)',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      await prefs.setBool(
          'post_registration.health_none.ana-1.allergies', true);
      await prefs.setBool(
        'post_registration.health_none.guardian-1.allergies',
        true,
      );
      await prefs.setString('unrelated_key', 'keep');

      container.read(_cleanupInvoker)();
      await pumpEventQueue();

      expect(
        prefs.getKeys().where((k) => k.startsWith('post_registration.')),
        isEmpty,
      );
      expect(prefs.getString('unrelated_key'), 'keep');
    });

    test('the next login after a logout while acting starts as guardian',
        () async {
      await boot();
      await notifier().switchProfile('ana-1');
      await notifier().signOut();

      container.invalidate(authNotifierProvider);
      final user = await container.read(authNotifierProvider.future);

      expect(user?.id, 'guardian-1');
      expect(repo.calls.last, isNull, reason: 'no dependent id on the request');
    });
  });
}

final _cleanupInvoker = Provider<void Function()>((ref) {
  return () => clearUserStateOnLogout(ref);
});
