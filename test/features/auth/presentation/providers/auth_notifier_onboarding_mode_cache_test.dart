import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';

/// El `onboarding_mode` viaja en caché junto a `cached_post_register_complete`:
/// una cuenta de solo panel restaurada sin red no debe caer en el
/// post-registro de club.

const _modeKey = AppConstants.cachedOnboardingMode;

const _panelOnlyGuardian = UserEntity(
  id: 'guardian-1',
  email: 'maria@example.com',
  name: 'María',
  onboardingMode: OnboardingMode.panelOnly,
  family: FamilySummary(isGuardian: true, dependentsCount: 1),
);

class _OfflineRepo extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Left(NetworkFailure(message: 'offline'));
}

/// `/auth/me` del tutor, o el del dependiente (modo `club`) mientras se actúa.
class _OnlineRepo extends FakeAuthRepository {
  _OnlineRepo(this._actingId);

  final String? Function() _actingId;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    final id = _actingId();
    if (id == null) return const Right(_panelOnlyGuardian);
    return Right(
      UserEntity(
        id: id,
        name: 'Ana',
        postRegisterComplete: true,
        actingFor: ActingForInfo(
          actorUserId: 'guardian-1',
          dependentUserId: id,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async => const Right(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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

  Future<FakeSecureStorage> offlineStorage() async {
    final storage = FakeSecureStorage();
    await storage.write('cached_user_id', 'user-1');
    await storage.write('cached_user_email', 'elena@example.com');
    await storage.write('cached_user_name', 'Elena');
    return storage;
  }

  Future<UserEntity?> restoreOffline(Map<String, Object> prefsValues) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final container = await buildAuthContainer(
      repo: _OfflineRepo(),
      storage: await offlineStorage(),
      prefs: prefs,
    );
    return container.read(authNotifierProvider.future);
  }

  group('offline restore', () {
    test('a cached panel_only account stays panel_only and skips post-reg',
        () async {
      final user = await restoreOffline({
        'cached_post_register_complete': false,
        _modeKey: 'panel_only',
      });

      expect(user?.onboardingMode, OnboardingMode.panelOnly);
      expect(user?.authorizationStale, isTrue);
      expect(userNeedsPostRegistration(user!), isFalse);
    });

    test('a cached club_exempt account keeps its 2-step flow', () async {
      final user = await restoreOffline({
        'cached_post_register_complete': false,
        _modeKey: 'club_exempt',
      });

      expect(user?.onboardingMode, OnboardingMode.clubExempt);
      expect(userNeedsPostRegistration(user!), isTrue);
    });

    test('a missing mode restores as club', () async {
      final user = await restoreOffline({
        'cached_post_register_complete': false,
      });

      expect(user?.onboardingMode, OnboardingMode.club);
      expect(userNeedsPostRegistration(user!), isTrue);
    });

    test('an unknown mode restores as club', () async {
      final user = await restoreOffline({
        'cached_post_register_complete': true,
        _modeKey: 'something_new',
      });

      expect(user?.onboardingMode, OnboardingMode.club);
      expect(userNeedsPostRegistration(user!), isFalse);
    });
  });

  group('writing and clearing the cached mode', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    Future<void> boot() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = await buildAuthContainer(
        repo: _OnlineRepo(
          () => container.read(actingForSessionProvider).dependentUserId,
        ),
        storage: FakeSecureStorage(),
        prefs: prefs,
      );
      await container.read(authNotifierProvider.future);
    }

    AuthNotifier notifier() => container.read(authNotifierProvider.notifier);

    test('a fresh /auth/me writes the mode next to the completion flag',
        () async {
      await boot();

      expect(prefs.getString(_modeKey), 'panel_only');
      expect(prefs.getBool('cached_post_register_complete'), isFalse);
    });

    test('refreshing with a new mode rewrites it', () async {
      await boot();
      prefs.setString(_modeKey, 'club');

      notifier().markPostRegisterComplete();

      expect(prefs.getString(_modeKey), 'panel_only');
    });

    test('is never written while acting for a dependent', () async {
      await boot();
      expect(prefs.getString(_modeKey), 'panel_only');

      final outcome = await notifier().switchProfile('ana-1', firstName: 'Ana');
      expect(outcome, SwitchProfileOutcome.entered);
      expect(
        container.read(authNotifierProvider).value?.onboardingMode,
        OnboardingMode.club,
      );
      notifier().markPostRegisterIncomplete(); // volvería a cachear
      notifier().markPostRegisterComplete();

      expect(prefs.getString(_modeKey), 'panel_only');
    });

    test('sign out clears it', () async {
      await boot();
      expect(prefs.containsKey(_modeKey), isTrue);

      expect(await notifier().signOut(), isTrue);

      expect(prefs.containsKey(_modeKey), isFalse);
      expect(prefs.containsKey('cached_post_register_complete'), isFalse);
    });

    test('an expired session clears it', () async {
      await boot();
      expect(prefs.containsKey(_modeKey), isTrue);

      notifier().expireSession();

      expect(prefs.containsKey(_modeKey), isFalse);
    });
  });
}
