/// Widget/unit tests for the «Más» sheet (T-30, T-31).
///
/// Coverage:
/// T-30 — filterSheetDestinations (pure function, no widget tree):
///   1. Miembro persona — nav-slot routes are excluded from sheet items.
///   2. Director persona — nav-slot routes excluded; non-slot RBAC items shown.
///   3. Coordinador persona — coordinator-shell nav routes excluded.
///   4. User with no permissions sees no RBAC-gated items.
///   5. Null user — no items returned.
///
/// T-31 — Widget tests (sheet renders correctly):
///   6. Sheet renders non-empty item list for director with permissions.
///   7. Sheet renders empty-state text when no items pass filter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/index.dart';
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

/// Builds a [UserEntity] with the given club [roleName], optional [permissions]
/// (snapshot-level, read by [hasAnyPermission]) and optional [globalRoles]
/// (via [AuthorizationSnapshot.globalGrants], read by [hasAnyRole]).
UserEntity _userWithRole(
  String roleName, {
  List<String> permissions = const [],
  List<String> globalRoles = const [],
}) {
  return UserEntity(
    id: 'test-id',
    email: 'test@example.com',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a1',
          roleName: roleName,
          status: 'active',
        ),
      ],
      globalGrants: globalRoles
          .map((r) => AuthorizationGrant(roleName: r))
          .toList(),
      activeAssignmentId: 'a1',
    ),
  );
}

/// Shorthand: call [filterSheetDestinations] for a [persona] + [user] combo
/// (no dynamic route resolvers, no WidgetRef needed).
List<MoreSheetResolvedItem> _filterFor(Persona persona, UserEntity? user) {
  final navRoutes =
      personaNavConfig[persona]!.map((s) => s.route).toSet();
  return filterSheetDestinations(navRoutes: navRoutes, user: user);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── T-30: Pure-function RBAC + slot-dedup unit tests ──────────────────────

  group('filterSheetDestinations (T-30)', () {
    test('1. Miembro — nav-slot routes excluded from sheet items', () {
      // Miembro nav slots: homeDashboard, homeClasses, homeActivities,
      // homeMyRanking, homeProfile.
      // moreSheetDestinations includes homeMyRanking (member_rankings:read_self)
      // → that item IS in the miembro nav and must be excluded.
      // homeResources (folders:read) is NOT in miembro nav → must appear.
      final user = _userWithRole(
        'member',
        permissions: ['member_rankings:read_self', 'folders:read'],
      );

      final items = _filterFor(Persona.miembro, user);
      final routes = items.map((i) => i.resolvedRoute).toSet();

      // No nav-slot route may appear.
      for (final slot in personaNavConfig[Persona.miembro]!) {
        expect(
          routes.contains(slot.route),
          isFalse,
          reason: 'Miembro nav route ${slot.route} must not appear in sheet',
        );
      }
      // homeResources must appear (folders:read, not in miembro nav).
      expect(routes.contains(RouteNames.homeResources), isTrue,
          reason: 'homeResources should appear for member with folders:read');
    });

    test(
        '2. Director — nav-slot routes excluded, non-slot RBAC-allowed shown',
        () {
      // Director nav: homeMembers, homeClub, homeFinances, homeActivities,
      // homeProfile.
      // homeEvidences (users:read_detail) is NOT in director nav → must appear.
      // homeUnits (units:update) is NOT in director nav → must appear.
      final user = _userWithRole(
        'director',
        permissions: [
          'users:read_detail',
          'clubs:update',
          'finances:read',
          'units:update',
          'classes:submit_progress',
          'insurance:read',
          'inventory:read',
          'folders:read',
          'member_rankings:read_self',
        ],
      );

      final items = _filterFor(Persona.director, user);
      final routes = items.map((i) => i.resolvedRoute).toSet();

      // No nav-slot route may appear.
      for (final slot in personaNavConfig[Persona.director]!) {
        expect(
          routes.contains(slot.route),
          isFalse,
          reason: 'Director nav route ${slot.route} must not appear in sheet',
        );
      }

      // Non-slot destinations with matching RBAC must appear.
      expect(routes.contains(RouteNames.homeEvidences), isTrue,
          reason:
              'homeEvidences should appear for director with users:read_detail');
      expect(routes.contains(RouteNames.homeUnits), isTrue,
          reason: 'homeUnits should appear for director with units:update');
    });

    test('3. Coordinador — coordinator-shell nav routes excluded', () {
      // Coordinador nav uses coordinator-shell routes (RouteNames.coordinator,
      // coordinatorClubs, coordinatorReports, coordinatorActivities,
      // coordinatorProfile). These must NOT appear in the sheet.
      final user = _userWithRole(
        'coordinator',
        globalRoles: ['coordinator'],
        permissions: ['folders:read'],
      );

      final items = _filterFor(Persona.coordinador, user);
      final routes = items.map((i) => i.resolvedRoute).toSet();

      for (final slot in personaNavConfig[Persona.coordinador]!) {
        expect(
          routes.contains(slot.route),
          isFalse,
          reason:
              'Coordinator nav route ${slot.route} must not appear in sheet',
        );
      }
    });

    test('4. User with no permissions sees no RBAC-gated items', () {
      // All moreSheetDestinations require at least one permission or role.
      final user = _userWithRole('member', permissions: [], globalRoles: []);
      final items = _filterFor(Persona.miembro, user);
      expect(items, isEmpty,
          reason: 'User with no permissions should see no sheet items');
    });

    test('5. Null user — no items returned', () {
      final items = _filterFor(Persona.miembro, null);
      expect(items, isEmpty,
          reason: 'Null user should see no sheet items');
    });
  });

  // ── T-31: Widget tests ─────────────────────────────────────────────────────

  group('MoreSheet widget (T-31)', () {
    /// Pumps the [_MoreSheetContentTestWrapper] inside a ProviderScope with
    /// the given [user] override.
    Future<void> pumpSheet(
      WidgetTester tester, {
      required UserEntity? user,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
            unreadNotificationsCountProvider
                .overrideWith(() => _FakeCountNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: _MoreSheetContentTestWrapper(),
              ),
            ),
          ),
        ),
      );
      // Allow async notifiers to settle.
      await tester.pumpAndSettle();
    }

    testWidgets(
        '6. Sheet renders non-empty item list for director with permissions',
        (tester) async {
      final user = _userWithRole(
        'director',
        permissions: ['users:read_detail', 'folders:read'],
      );
      await pumpSheet(tester, user: user);

      // homeEvidences item (users:read_detail) should render.
      // EasyLocalization not initialized → raw key is rendered.
      expect(
        find.text('dashboard.quick_access.evidence_folder'),
        findsAtLeastNWidgets(1),
        reason:
            'Sheet should show evidence_folder for director with users:read_detail',
      );
    });

    testWidgets(
        '7. Sheet renders empty-state when no items pass RBAC filter',
        (tester) async {
      // User with no permissions → empty sheet.
      final user = _userWithRole('member', permissions: [], globalRoles: []);
      await pumpSheet(tester, user: user);

      expect(
        find.text('common.no_results'),
        findsOneWidget,
        reason: 'Empty sheet should show no_results key',
      );
    });
  });
}

// ── Test widget helpers ───────────────────────────────────────────────────────

/// Renders the sheet item list using the public [filterSheetDestinations] API
/// and the watched [currentPersonaProvider] + [authNotifierProvider].
///
/// This widget mirrors what [_MoreSheetContent] does internally and lets tests
/// inspect the rendered item labels without coupling to the private class.
class _MoreSheetContentTestWrapper extends ConsumerWidget {
  const _MoreSheetContentTestWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(currentPersonaProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final navRoutes =
        personaNavConfig[persona]!.map((s) => s.route).toSet();
    final items = filterSheetDestinations(
      navRoutes: navRoutes,
      user: user,
      ref: ref,
    );

    if (items.isEmpty) {
      return const Center(child: Text('common.no_results'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Padding(
          key: ValueKey(item.resolvedRoute),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(item.dest.labelKey),
        );
      },
    );
  }
}
