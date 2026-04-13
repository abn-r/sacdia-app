import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a [UserEntity] with the given authorization state.
UserEntity _buildUser({
  List<String> permissions = const [],
  List<AuthorizationGrant> globalGrants = const [],
  List<AuthorizationGrant> clubAssignments = const [],
  String? activeAssignmentId,
}) {
  return UserEntity(
    id: 'test-user-id',
    email: 'test@example.com',
    name: 'Test User',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      globalGrants: globalGrants,
      clubAssignments: clubAssignments,
      activeAssignmentId: activeAssignmentId,
    ),
  );
}

UserEntity _buildValidUser() {
  return _buildUser(
    permissions: ['classes:read', 'activities:read'],
    clubAssignments: [
      const AuthorizationGrant(
        assignmentId: 'assignment-1',
        roleName: 'conquistador',
        permissions: ['classes:read', 'activities:read'],
        clubId: 1,
        sectionId: 1,
      ),
    ],
    activeAssignmentId: 'assignment-1',
  );
}

/// Creates a [ProviderContainer] with the fake auth overridden and
/// pre-warms [authNotifierProvider] so it is already in data state before
/// [appBootstrapProvider] registers its `ref.listen`. Without this step
/// the loading→data transition fires `ref.invalidateSelf()` from inside
/// `AppBootstrapNotifier.build()`, disposing it while it is still
/// completing — causing a "disposed during loading state" crash.
Future<ProviderContainer> _makeContainer(UserEntity? user) async {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(
        () => _FakeAuthNotifier(user),
      ),
    ],
  );
  // Settle authNotifierProvider BEFORE appBootstrapProvider subscribes.
  await container.read(authNotifierProvider.future);
  return container;
}

/// Creates a [ProviderContainer] with ALL necessary overrides for nuclear
/// reset testing: auth, secureStorage, and sharedPreferences.
Future<ProviderContainer> _makeFullContainer(
  _MutableFakeAuthNotifier fakeAuth,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => fakeAuth),
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  await container.read(authNotifierProvider.future);
  return container;
}

void main() {
  group('AppBootstrapNotifier', () {
    test('returns AppBootstrapReady when user has valid authorization',
        () async {
      final container = await _makeContainer(_buildValidUser());
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapReady>());
    });

    test('returns AppBootstrapUnauthenticated when user is null', () async {
      final container = await _makeContainer(null);
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapUnauthenticated>());
    });

    test(
        'returns AppBootstrapError when user has empty permissions after retries',
        () async {
      final container = await _makeContainer(_buildUser());
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapError>());
      expect(
        (state as AppBootstrapError).attemptCount,
        equals(3),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('returns AppBootstrapError when authorization is null after retries',
        () async {
      const userWithNoAuth = UserEntity(
        id: 'test-id',
        email: 'test@test.com',
        postRegisterComplete: true,
      );

      final container = await _makeContainer(userWithNoAuth);
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapError>());
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('returns Ready when permissions present but no global grants',
        () async {
      final user = _buildUser(
        permissions: ['dashboard:read'],
        clubAssignments: [
          const AuthorizationGrant(
            assignmentId: 'a1',
            roleName: 'member',
            permissions: ['dashboard:read'],
            clubId: 1,
            sectionId: 1,
          ),
        ],
        activeAssignmentId: 'a1',
      );

      final container = await _makeContainer(user);
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapReady>());
    });

    test('returns AppBootstrapError when permissions present but roles empty',
        () async {
      final user = _buildUser(
        permissions: ['classes:read'],
        // No clubAssignments → resolvedRoleNames will be empty
      );

      final container = await _makeContainer(user);
      addTearDown(container.dispose);

      final state = await container.read(appBootstrapProvider.future);
      expect(state, isA<AppBootstrapError>());
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('retry() succeeds when auth becomes valid', () async {
      final invalidUser = _buildUser(); // empty permissions
      final fakeAuth = _MutableFakeAuthNotifier(invalidUser);
      final container = await _makeFullContainer(fakeAuth);
      addTearDown(container.dispose);

      // Wait for auto-retries to exhaust → error state
      final errorState = await container.read(appBootstrapProvider.future);
      expect(errorState, isA<AppBootstrapError>());

      // Now fix the auth data
      fakeAuth.user = _buildValidUser();

      // Call retry()
      await container.read(appBootstrapProvider.notifier).retry();

      // Should be ready now
      final state = container.read(appBootstrapProvider).valueOrNull;
      expect(state, isA<AppBootstrapReady>());
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('retry() triggers nuclear reset when auth stays invalid', () async {
      final invalidUser = _buildUser(); // empty permissions
      final fakeAuth = _MutableFakeAuthNotifier(invalidUser);
      final container = await _makeFullContainer(fakeAuth);
      addTearDown(container.dispose);

      // Wait for auto-retries to exhaust → error state
      final errorState = await container.read(appBootstrapProvider.future);
      expect(errorState, isA<AppBootstrapError>());

      // Keep invalid auth — retry should fail and nuclear reset
      await container.read(appBootstrapProvider.notifier).retry();

      // Should be unauthenticated after nuclear reset
      final state = container.read(appBootstrapProvider).valueOrNull;
      expect(state, isA<AppBootstrapUnauthenticated>());
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

/// Fake [AuthNotifier] that returns a fixed user without any network calls.
class _FakeAuthNotifier extends AuthNotifier {
  final UserEntity? _user;

  _FakeAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;
}

/// Fake [SecureStorage] that is a no-op — all reads return null/false/empty.
class _FakeSecureStorage implements SecureStorage {
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<bool> contains(String key) async => false;
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<Map<String, String>> readAll() async => {};
}

/// Mutable fake [AuthNotifier] whose returned user can be swapped mid-test.
class _MutableFakeAuthNotifier extends AuthNotifier {
  UserEntity? user;
  _MutableFakeAuthNotifier(this.user);

  @override
  Future<UserEntity?> build() async => user;
}
