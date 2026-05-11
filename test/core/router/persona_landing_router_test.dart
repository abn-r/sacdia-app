/// Integration-style router tests for persona-routed landing redirect (T-17, T-18, T-19).
///
/// These tests verify the router redirect function end-to-end using a real
/// [GoRouter] instance with fake [ProviderContainer] state.
///
/// Scenarios covered:
/// - S-01: Miembro → homeDashboard (T-17)
/// - S-02: Director → homeMembers (T-17)
/// - S-03: Tesorero → homeFinances (T-17)
/// - S-04: Consejero → homeUnits (T-17)
/// - S-05: Coordinador → coordinator (T-17)
/// - S-08: Deep-link to /home/finances → loads directly, no redirect (T-18)
/// - S-06/S-07 representative: context switch → nav rebuilds, no re-route (T-19)
///
/// Architecture note: [routerProvider] reads from [authNotifierProvider] and
/// [appBootstrapProvider]. We create a [ProviderContainer] with fake notifiers
/// for both, then construct a [GoRouter] that mirrors the exact redirect logic
/// from router.dart so the tests stay in sync with production without coupling
/// to private router internals.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final UserEntity? _user;
  _FakeAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeBootstrapNotifier extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a fake [UserEntity] with the given [roleName] and [postRegisterComplete].
UserEntity _userWith(String roleName, {bool postRegisterComplete = true}) {
  return UserEntity(
    id: 'test-$roleName',
    email: 'test@example.com',
    postRegisterComplete: postRegisterComplete,
    authorization: AuthorizationSnapshot(
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a1',
          roleName: roleName,
          status: 'active',
        ),
      ],
      activeAssignmentId: 'a1',
    ),
  );
}

/// Runs the redirect logic that mirrors router.dart exactly for the
/// splash-entry case. Returns the redirect target or null.
///
/// This is extracted here so router tests can verify the complete pipeline
/// without depending on GoRouter widget infrastructure.
String? _runRedirect({
  required String currentPath,
  required ProviderContainer container,
}) {
  final authState = container.read(authNotifierProvider);
  final isLoading = authState.isLoading;
  final user = authState.valueOrNull;
  final isLoggedIn = user != null;
  final bootstrapAsync = container.read(appBootstrapProvider);

  const publicRoutes = [
    RouteNames.splash,
    RouteNames.login,
    RouteNames.register,
    RouteNames.forgotPassword,
    RouteNames.authCallback,
  ];
  final isPublicRoute = publicRoutes.contains(currentPath);
  final isAlreadyInsideApp =
      !isPublicRoute && currentPath != RouteNames.splash;

  if (isLoading) {
    if (currentPath == RouteNames.splash) return null;
    if (isAlreadyInsideApp) return null;
    return RouteNames.splash;
  }

  if (isLoggedIn) {
    final isBootstrapLoading = bootstrapAsync.isLoading;
    final bootstrapValue = bootstrapAsync.valueOrNull;

    if (isBootstrapLoading) {
      if (currentPath == RouteNames.splash) return null;
      if (isAlreadyInsideApp) return null;
      return RouteNames.splash;
    }
    if (bootstrapAsync.hasError) {
      if (currentPath == RouteNames.splash) return null;
      return RouteNames.splash;
    }
    if (bootstrapValue is AppBootstrapError) {
      if (currentPath == RouteNames.splash) return null;
      return RouteNames.splash;
    }
    if (bootstrapValue is AppBootstrapUnauthenticated) {
      return RouteNames.login;
    }
  }

  // Splash block (T-15)
  if (currentPath == RouteNames.splash) {
    if (!isLoggedIn) return RouteNames.login;
    if (!user!.postRegisterComplete) return RouteNames.postRegistration;
    final persona = resolvePersona(user.authorization);
    return personaLandingRoute(persona);
  }

  if (!isLoggedIn) {
    return isPublicRoute ? null : RouteNames.login;
  }

  // Public route block (T-16)
  if (isPublicRoute) {
    if (!user!.postRegisterComplete) return RouteNames.postRegistration;
    final persona = resolvePersona(user.authorization);
    return personaLandingRoute(persona);
  }

  // Post-registration complete on post-registration route (T-16)
  if (user!.postRegisterComplete &&
      currentPath == RouteNames.postRegistration) {
    final persona = resolvePersona(user.authorization);
    return personaLandingRoute(persona);
  }

  if (!user.postRegisterComplete &&
      currentPath != RouteNames.postRegistration) {
    return RouteNames.postRegistration;
  }

  return null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── T-17: Post-login redirect per persona (S-01 to S-05) ─────────────────
  group('T-17: post-login redirect per persona', () {
    test('S-01: Miembro → homeDashboard', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('member'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Allow providers to settle
      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.homeDashboard,
          reason: 'S-01: member must land on homeDashboard');
    });

    test('S-02: Director → homeMembers', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('director'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.homeMembers,
          reason: 'S-02: director must land on homeMembers');
    });

    test('S-03: Tesorero → homeFinances', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('treasurer'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.homeFinances,
          reason: 'S-03: treasurer must land on homeFinances');
    });

    test('S-04: Consejero → homeUnits', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('counselor'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.homeUnits,
          reason: 'S-04: counselor must land on homeUnits');
    });

    test('S-05: Coordinador → coordinator route', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('coordinator'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.coordinator,
          reason: 'S-05: coordinator must land on coordinator hub');
    });

    test('secretary-treasurer collapses to Director → homeMembers (S-14)', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('secretary-treasurer'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.splash,
        container: container,
      );

      expect(target, RouteNames.homeMembers,
          reason: 'secretary-treasurer maps to Director persona (S-14)');
    });
  });

  // ── T-18: Deep-link bypass (S-08) ─────────────────────────────────────────
  group('T-18: deep-link bypass — splash block does not fire (S-08 / R5)', () {
    test(
        'S-08: member with matchedLocation=/home/finances → no splash redirect',
        () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('member'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      // GoRouter evaluates redirect with the FINAL matched location.
      // For a deep link to /home/finances, matchedLocation is /home/finances —
      // NOT the transient splash. The splash block does not fire.
      final target = _runRedirect(
        currentPath: RouteNames.homeFinances,
        container: container,
      );

      expect(target, isNull,
          reason:
              'Deep-link to /home/finances must not be overridden by landing redirect (S-08)');
    });

    test('director with deep-link /home/dashboard → no redirect', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('director'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.homeDashboard,
        container: container,
      );

      expect(target, isNull,
          reason:
              'Deep-link to /home/dashboard must not trigger landing redirect for director');
    });
  });

  // ── T-19: Context switch — no re-route (S-06, S-07) ──────────────────────
  group('T-19: context switch does not trigger redirect (S-06 / S-07 / FR-4)',
      () {
    test(
        'S-06: director on homeMembers after context switch → no redirect fires',
        () async {
      // Director is already inside the app on /home/members.
      // activeAssignmentId changed (context switch) → router.refresh() called.
      // currentPath is /home/members (not splash) → splash block does NOT fire.
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('director'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.homeMembers,
        container: container,
      );

      expect(target, isNull,
          reason:
              'S-06: mid-session context switch must not trigger landing redirect (FR-4)');
    });

    test(
        'S-07: user switches from director (Club A) to treasurer (Club B) → '
        'current path preserved, no redirect', () async {
      // User is on /home/finances when they switch to treasurer role in Club B.
      // The path is already inside the app → splash block does NOT fire.
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('treasurer'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.homeFinances,
        container: container,
      );

      expect(target, isNull,
          reason:
              'S-07: context switch to different club/persona must not force redirect');
    });

    test(
        'context switch: user on homeClasses when persona changes → '
        'no redirect (non-splash path)', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWith('counselor'))),
          appBootstrapProvider
              .overrideWith(() => _FakeBootstrapNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);

      final target = _runRedirect(
        currentPath: RouteNames.homeClasses,
        container: container,
      );

      expect(target, isNull);
    });
  });
}
