/// Tests for the coordinator persona shell and S-15 context-switch scenario (T-24, T-25).
///
/// Tests:
/// 1. _CoordinatorShell nav slot config: coordinator persona config has exactly
///    5 slots with the correct labelKeys (Hub, Clubes, Reportes, Actividades, Perfil).
/// 2. branchIndex values are scoped 0–4 (coordinator shell, NOT main shell 0–17).
/// 3. Coordinator Activities slot has badgeSource=activities.
/// 4. Coordinator Hub slot has badgeSource=hub.
/// 5. _CoordinatorShell widget test: renders 5 NavigationDestinations using
///    coordinator persona config directly (mirrors _CoordinatorShell build path).
/// 6. S-15 routing: personaLandingRoute(Persona.coordinador) == RouteNames.coordinator
///    (coordinator lands in coordinator shell; switching to director sends to main shell).
/// 7. S-15 redirect logic: context-switch from coordinator to director persona
///    changes personaLandingRoute output to main-shell route.
/// 8. Coordinator persona nav config route fields match PR-4 coordinator routes.
///
/// NOTE: _CoordinatorShell is private to router.dart. We mirror its NavigationBar
/// build path using a _TestCoordShell widget that reads personaNavConfig[Persona.coordinador]
/// directly (the same constant _CoordinatorShell uses), avoiding router coupling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/index.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

// ── Fake helpers ──────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final UserEntity? _user;
  _FakeAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeCountNotifier extends UnreadNotificationsCountNotifier {
  @override
  int build() => 0;
}

UserEntity _userWithRole(String roleName) {
  return UserEntity(
    id: 'test-id',
    email: 'test@example.com',
    postRegisterComplete: true,
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

// ── Test shell widget ─────────────────────────────────────────────────────────

/// Mirrors the NavigationBar portion of _CoordinatorShell.
///
/// Reads personaNavConfig[Persona.coordinador] directly (the same constant that
/// _CoordinatorShell uses in production) to render a NavigationBar with 5
/// destinations. Uses raw NavSlot.labelKey so no locale setup is needed.
class _TestCoordShell extends ConsumerWidget {
  const _TestCoordShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mirror _CoordinatorShell's slot source exactly.
    final slots = personaNavConfig[Persona.coordinador]!;

    return Scaffold(
      body: const SizedBox.shrink(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: slots
            .map(
              (slot) => NavigationDestination(
                icon: NavBadge(
                  source: slot.badgeSource,
                  child: const Icon(Icons.circle),
                ),
                selectedIcon: NavBadge(
                  source: slot.badgeSource,
                  child: const Icon(Icons.circle),
                ),
                // Raw labelKey — test stability without locale setup
                label: slot.labelKey,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Test harness ──────────────────────────────────────────────────────────────

Future<void> _pumpCoordShell(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(_userWithRole('coordinator')),
        ),
        unreadNotificationsCountProvider.overrideWith(
          () => _FakeCountNotifier(),
        ),
      ],
      child: const MaterialApp(
        home: _TestCoordShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── T-24: _CoordinatorShell nav slot config (unit assertions) ────────────

  group('T-24: coordinator persona nav config shape (FR-2, FR-5)', () {
    test('coordinator nav config has exactly 5 slots', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      expect(slots.length, 5, reason: 'Coordinator nav must have exactly 5 slots (FR-2)');
    });

    test('coordinator slots have correct labelKeys in order', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      expect(slots[0].labelKey, 'nav.hub');
      expect(slots[1].labelKey, 'nav.clubs');
      expect(slots[2].labelKey, 'nav.reports');
      expect(slots[3].labelKey, 'nav.activities');
      expect(slots[4].labelKey, 'nav.profile');
    });

    test('coordinator branch indices are scoped 0–4 (coordinator shell, NOT main 0–17)', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      final indices = slots.map((s) => s.branchIndex).toList();
      expect(indices, [0, 1, 2, 3, 4],
          reason: 'Coordinator shell branchIndex must be 0–4, independent of main shell (design R2)');
    });

    test('coordinator Hub slot has badgeSource=hub (FR-8)', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      final hubSlot = slots.firstWhere((s) => s.labelKey == 'nav.hub');
      expect(hubSlot.badgeSource, NavBadgeSource.hub);
    });

    test('coordinator Activities slot has badgeSource=activities (FR-8)', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      final actSlot = slots.firstWhere((s) => s.labelKey == 'nav.activities');
      expect(actSlot.badgeSource, NavBadgeSource.activities);
    });

    test('coordinator non-Hub/Activities slots have badgeSource=none', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      for (final slot in slots) {
        if (slot.labelKey == 'nav.hub' || slot.labelKey == 'nav.activities') {
          continue;
        }
        expect(
          slot.badgeSource,
          NavBadgeSource.none,
          reason: 'Slot ${slot.labelKey} should not have a badge source',
        );
      }
    });

    test('coordinator slot routes match PR-4 coordinator route constants', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      expect(slots[0].route, RouteNames.coordinator,
          reason: 'Hub slot must use RouteNames.coordinator');
      expect(slots[1].route, RouteNames.coordinatorClubs,
          reason: 'Clubs slot must use RouteNames.coordinatorClubs');
      expect(slots[2].route, RouteNames.coordinatorReports,
          reason: 'Reports slot must use RouteNames.coordinatorReports');
      expect(slots[3].route, RouteNames.coordinatorActivities,
          reason: 'Activities slot must use RouteNames.coordinatorActivities');
      expect(slots[4].route, RouteNames.coordinatorProfile,
          reason: 'Profile slot must use RouteNames.coordinatorProfile');
    });
  });

  // ── T-24: _CoordinatorShell widget rendering ──────────────────────────────

  group('T-24: _CoordinatorShell widget — renders 5 navigation destinations', () {
    testWidgets(
        'coordinator shell renders exactly 5 NavigationDestinations',
        (tester) async {
      await _pumpCoordShell(tester);

      expect(
        find.byType(NavigationDestination),
        findsNWidgets(5),
        reason: 'Coordinator shell must render exactly 5 nav destinations (FR-2, FR-5)',
      );
    });

    testWidgets('coordinator shell shows Hub labelKey as first destination',
        (tester) async {
      await _pumpCoordShell(tester);

      expect(find.text('nav.hub'), findsWidgets,
          reason: 'First coordinator slot must be Hub');
    });

    testWidgets('coordinator shell shows all 5 expected labelKeys', (tester) async {
      await _pumpCoordShell(tester);

      expect(find.text('nav.hub'), findsWidgets);
      expect(find.text('nav.clubs'), findsWidgets);
      expect(find.text('nav.reports'), findsWidgets);
      expect(find.text('nav.activities'), findsWidgets);
      expect(find.text('nav.profile'), findsWidgets);
    });
  });

  // ── T-25 / S-15: context-switch routing logic ─────────────────────────────

  group('T-25 / S-15: coordinator context-switch — shell routing', () {
    test('coordinator persona lands at RouteNames.coordinator (coordinator shell)', () {
      final user = _userWithRole('coordinator');
      final persona = resolvePersona(user.authorization);

      expect(persona, Persona.coordinador);
      expect(
        personaLandingRoute(persona),
        RouteNames.coordinator,
        reason: 'S-05: coordinator post-login must land at coordinator shell root',
      );
    });

    test('S-15: switching from coordinator to director persona changes landing route', () {
      // coordinator — lands in coordinator shell
      final coordUser = _userWithRole('coordinator');
      final coordPersona = resolvePersona(coordUser.authorization);
      expect(coordPersona, Persona.coordinador);
      expect(personaLandingRoute(coordPersona), RouteNames.coordinator);

      // director — lands in main shell (homeMembers)
      final directorUser = _userWithRole('director');
      final directorPersona = resolvePersona(directorUser.authorization);
      expect(directorPersona, Persona.director);
      expect(personaLandingRoute(directorPersona), RouteNames.homeMembers,
          reason: 'S-15: after context switch to director, landing route must be main shell route');
    });

    test('S-15: coordinator persona does not resolve to any main-shell persona', () {
      for (final coordRole in ['coordinator', 'admin', 'super-admin', 'assistant-admin']) {
        final user = _userWithRole(coordRole);
        final persona = resolvePersona(user.authorization);
        expect(persona, Persona.coordinador,
            reason: '$coordRole must resolve to coordinador');
        // Coordinator shell route is NOT a main-shell /home/* path
        final landingRoute = personaLandingRoute(persona);
        expect(
          landingRoute.startsWith('/home/'),
          isFalse,
          reason: 'Coordinator landing route must NOT be a main shell /home/* path (FR-5)',
        );
      }
    });

    test('non-coordinator personas do NOT land at coordinator route', () {
      for (final entry in {
        'member': RouteNames.homeDashboard,
        'director': RouteNames.homeMembers,
        'treasurer': RouteNames.homeFinances,
        'counselor': RouteNames.homeUnits,
      }.entries) {
        final user = _userWithRole(entry.key);
        final persona = resolvePersona(user.authorization);
        final landingRoute = personaLandingRoute(persona);
        expect(landingRoute, isNot(RouteNames.coordinator),
            reason: '${entry.key} must NOT land at coordinator shell');
        expect(landingRoute, entry.value);
      }
    });
  });
}
