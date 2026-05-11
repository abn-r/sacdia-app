/// Unit tests for the post-login landing redirect guard (T-20).
///
/// These tests cover the logic described in design §4 (Router Changes) and
/// FR-3/FR-4/FR-6 of the spec:
///
/// - The redirect MUST fire only when [currentPath == RouteNames.splash].
/// - The redirect MUST use [personaLandingRoute(resolvePersona(snapshot))].
/// - Any non-splash path (including deep-link targets) MUST fall through —
///   the redirect must NOT hijack in-progress navigation.
/// - On context switch, [activeAssignmentId] changes but the current path is
///   already inside the app (not splash) → the guard condition is false →
///   no redirect fires (FR-4).
///
/// Approach: Since the redirect callback is a closure inside [routerProvider]
/// that reads from providers, we test the two constituent pure functions
/// ([resolvePersona] + [personaLandingRoute]) combined with explicit
/// path-guard assertions that document the splash-only gate.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

AuthorizationSnapshot _snapshot(String roleName) {
  return AuthorizationSnapshot(
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'a1',
        roleName: roleName,
        status: 'active',
      ),
    ],
    activeAssignmentId: 'a1',
  );
}

/// Mirrors the redirect guard condition from router.dart.
///
/// Returns the redirect target when the guard fires, or null when it does not.
/// This is the EXACT conditional used in the router:
///   `if (currentPath == RouteNames.splash) { … return personaLandingRoute(persona); }`
String? _simulateRedirect({
  required String currentPath,
  required bool isLoggedIn,
  required bool postRegisterComplete,
  AuthorizationSnapshot? authorization,
}) {
  // Splash-only gate (T-15/T-17 — landing redirect fires only from '/').
  if (currentPath == RouteNames.splash) {
    if (!isLoggedIn) return RouteNames.login;
    if (!postRegisterComplete) return RouteNames.postRegistration;
    final persona = resolvePersona(authorization);
    return personaLandingRoute(persona);
  }
  // All other paths: no redirect from this block (FR-4, FR-6).
  return null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── T-20a: Post-login landing per persona ────────────────────────────────────
  group('post-login landing route per persona (T-20 / FR-3)', () {
    test('Miembro (member) → homeDashboard', () {
      final snapshot = _snapshot('member');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.miembro);
      expect(personaLandingRoute(persona), RouteNames.homeDashboard);
    });

    test('Consejero (counselor) → homeUnits', () {
      final snapshot = _snapshot('counselor');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.consejero);
      expect(personaLandingRoute(persona), RouteNames.homeUnits);
    });

    test('Director (director) → homeMembers', () {
      final snapshot = _snapshot('director');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.director);
      expect(personaLandingRoute(persona), RouteNames.homeMembers);
    });

    test('Director via deputy-director role → homeMembers', () {
      final snapshot = _snapshot('deputy-director');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.director);
      expect(personaLandingRoute(persona), RouteNames.homeMembers);
    });

    test('Director via secretary-treasurer role → homeMembers', () {
      final snapshot = _snapshot('secretary-treasurer');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.director);
      expect(personaLandingRoute(persona), RouteNames.homeMembers);
    });

    test('Tesorero (treasurer) → homeFinances', () {
      final snapshot = _snapshot('treasurer');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.tesorero);
      expect(personaLandingRoute(persona), RouteNames.homeFinances);
    });

    test('Coordinador (coordinator) → coordinator route', () {
      final snapshot = _snapshot('coordinator');
      final persona = resolvePersona(snapshot);
      expect(persona, Persona.coordinador);
      expect(personaLandingRoute(persona), RouteNames.coordinator);
    });

    test('No snapshot → Miembro → homeDashboard (FR-10)', () {
      final persona = resolvePersona(null);
      expect(persona, Persona.miembro);
      expect(personaLandingRoute(persona), RouteNames.homeDashboard);
    });
  });

  // ── T-20b: Splash-only guard (FR-3 "fires only once") ─────────────────────
  group('redirect fires ONLY from splash path (T-20 / FR-3 guard)', () {
    test('from splash → logged-in → complete → redirects to persona landing',
        () {
      final result = _simulateRedirect(
        currentPath: RouteNames.splash,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('director'),
      );
      expect(result, RouteNames.homeMembers);
    });

    test('from splash → not logged-in → redirects to login', () {
      final result = _simulateRedirect(
        currentPath: RouteNames.splash,
        isLoggedIn: false,
        postRegisterComplete: false,
      );
      expect(result, RouteNames.login);
    });

    test('from splash → logged-in → incomplete → redirects to postRegistration',
        () {
      final result = _simulateRedirect(
        currentPath: RouteNames.splash,
        isLoggedIn: true,
        postRegisterComplete: false,
        authorization: _snapshot('member'),
      );
      expect(result, RouteNames.postRegistration);
    });

    test(
        'from deep-link target /home/finances → guard does NOT fire (FR-6 / R5)',
        () {
      final result = _simulateRedirect(
        currentPath: RouteNames.homeFinances,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('member'),
      );
      // Deep-link path is not splash → guard returns null (no redirect override)
      expect(result, isNull);
    });

    test('from /home/dashboard (mid-session) → guard does NOT fire (FR-4)', () {
      final result = _simulateRedirect(
        currentPath: RouteNames.homeDashboard,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('director'),
      );
      // Mid-session navigation is not splash → no redirect
      expect(result, isNull);
    });

    test('from /home/members (director mid-session) → guard does NOT fire', () {
      final result = _simulateRedirect(
        currentPath: RouteNames.homeMembers,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('director'),
      );
      expect(result, isNull);
    });

    test('from /login (public route) → guard does NOT fire via splash block',
        () {
      // /login is a public route but NOT the splash — the splash block doesn't
      // fire. The public-route block (T-16) handles this separately.
      final result = _simulateRedirect(
        currentPath: RouteNames.login,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('member'),
      );
      expect(result, isNull);
    });
  });

  // ── T-20c: Context switch does not trigger redirect (FR-4) ─────────────────
  group('context switch scenario — redirect guard is path-based (T-20 / FR-4)',
      () {
    test(
        'director viewing homeMembers after context switch → no splash → no redirect',
        () {
      // Simulate: user is on /home/members (after context switch to a different
      // club). currentPath is /home/members (not splash) → guard does not fire.
      final result = _simulateRedirect(
        currentPath: RouteNames.homeMembers,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('director'),
      );
      expect(result, isNull,
          reason:
              'Mid-session context switch must not trigger the landing redirect (FR-4)');
    });

    test(
        'treasurer viewing homeFinances after context switch to treasurer role → no redirect',
        () {
      final result = _simulateRedirect(
        currentPath: RouteNames.homeFinances,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('treasurer'),
      );
      expect(result, isNull);
    });
  });

  // ── T-20d: Deep-link bypass (S-08) ─────────────────────────────────────────
  group('deep-link bypass — non-splash path is never redirected (T-20 / S-08)',
      () {
    test('member with deep-link /home/finances → no redirect from splash block',
        () {
      // GoRouter evaluates redirect with state.matchedLocation == /home/finances
      // (the final intended destination) — NOT the transient splash.
      // So the splash block never fires for a deep link.
      final result = _simulateRedirect(
        currentPath: RouteNames.homeFinances,
        isLoggedIn: true,
        postRegisterComplete: true,
        authorization: _snapshot('member'),
      );
      expect(result, isNull,
          reason:
              'Deep-link target must not be overridden by landing redirect (S-08 / R5)');
    });

    test('any deep-link path to a known route → no redirect interference', () {
      final deepLinkPaths = [
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeUnits,
        RouteNames.homeProfile,
        RouteNames.homeClub,
        RouteNames.homeCamporees,
      ];

      for (final path in deepLinkPaths) {
        final result = _simulateRedirect(
          currentPath: path,
          isLoggedIn: true,
          postRegisterComplete: true,
          authorization: _snapshot('member'),
        );
        expect(result, isNull,
            reason: 'Deep-link to $path must not trigger redirect');
      }
    });
  });
}
