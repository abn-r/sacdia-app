import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

const _activeClubGrant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 4,
  status: 'active',
);

const _pendingClubGrant = AuthorizationGrant(
  assignmentId: 'a2',
  roleName: 'member',
  clubId: 1,
  sectionId: 4,
  status: 'pending',
);

UserEntity _user({
  List<String> globalRoles = const [],
  List<String> permissions = const [],
  List<AuthorizationGrant> clubAssignments = const [],
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: permissions,
        globalGrants: [
          for (final role in globalRoles) AuthorizationGrant(roleName: role),
        ],
        clubAssignments: clubAssignments,
      ),
    );

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

List<String> _routes(UserEntity? user) =>
    shellNavItemsForTesting(user).map((i) => i.route).toList();

void main() {
  group('coordination tab in the shell navigation', () {
    const coordinatorPermissions = ['classes:read', 'activities:read'];

    test('a coordinator with a club sees 5 tabs, coordination before profile',
        () {
      final items = shellNavItemsForTesting(
        _user(
          globalRoles: const ['coordinator'],
          permissions: coordinatorPermissions,
          clubAssignments: const [_activeClubGrant],
        ),
      );

      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.coordinator,
        RouteNames.homeProfile,
      ]);
      expect(
        items.firstWhere((i) => i.route == RouteNames.coordinator).labelKey,
        'router.nav.coordination',
      );
    });

    test('a coordinator without a club sees home, coordination and profile',
        () {
      expect(
        _routes(_user(globalRoles: const ['coordinator'])),
        [
          RouteNames.homeDashboard,
          RouteNames.coordinator,
          RouteNames.homeProfile,
        ],
      );
    });

    test(
        'a coordinator whose only membership is pending keeps coordination '
        '(it bypasses the club operational surface check)', () {
      final routes = _routes(
        _user(
          globalRoles: const ['coordinator'],
          permissions: coordinatorPermissions,
          clubAssignments: const [_pendingClubGrant],
        ),
      );

      expect(routes, contains(RouteNames.coordinator));
      // Club tabs still require the club surface.
      expect(routes, isNot(contains(RouteNames.homeClasses)));
      expect(routes, isNot(contains(RouteNames.homeActivities)));
      expect(routes.indexOf(RouteNames.coordinator),
          lessThan(routes.indexOf(RouteNames.homeProfile)));
    });

    test('a regular member does not see coordination', () {
      final routes = _routes(
        _user(
          permissions: coordinatorPermissions,
          clubAssignments: const [_activeClubGrant],
        ),
      );

      expect(routes, isNot(contains(RouteNames.coordinator)));
      expect(routes, [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
      ]);
    });

    test('without an authorization snapshot the tab is hidden', () {
      const user = UserEntity(id: 'u1', email: 'u1@example.com');
      expect(_routes(user), isNot(contains(RouteNames.coordinator)));
      expect(_routes(null), isNot(contains(RouteNames.coordinator)));
    });

    test('a pastor without a club keeps the pastor navigation', () {
      expect(
        _routes(_user(globalRoles: const ['pastor'])),
        [RouteNames.homeDashboard, RouteNames.homeProfile],
      );
    });
  });

  group('coordinator routes', () {
    Future<GoRouter> setUpRouter(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              _user(globalRoles: const ['coordinator']),
            ),
          ),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        ],
      );
      final router = container.read(routerProvider);
      addTearDown(() {
        router.dispose();
        container.dispose();
      });
      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);
      return router;
    }

    bool insideShell(RouteMatchList list) =>
        list.matches.first is ShellRouteMatch;

    testWidgets('coordination is the fifth shell branch rooted at /coordinator',
        (tester) async {
      final router = await setUpRouter(tester);
      final shell =
          router.configuration.routes.whereType<StatefulShellRoute>().single;

      expect(shell.branches, hasLength(5));
      final root = shell.branches[4].routes.single as GoRoute;
      expect(root.path, RouteNames.coordinator);
      expect(
        root.routes.whereType<GoRoute>().map((r) => r.path),
        unorderedEquals(['evidence-review', 'clubs', 'sla', 'reports']),
      );
    });

    testWidgets('tab root and drill-ins keep their full paths inside the shell',
        (tester) async {
      final router = await setUpRouter(tester);

      for (final path in [
        RouteNames.coordinator,
        RouteNames.coordinatorEvidenceReview,
        RouteNames.coordinatorClubs,
        RouteNames.coordinatorSla,
        RouteNames.coordinatorReports,
      ]) {
        final match = router.configuration.findMatch(Uri.parse(path));
        expect(match.isError, isFalse, reason: path);
        expect(match.fullPath, path, reason: path);
        expect(insideShell(match), isTrue, reason: path);
      }
    });

    testWidgets(
        'evidence detail does not collide with the nested list child: it '
        'resolves to the top-level route outside the shell', (tester) async {
      final router = await setUpRouter(tester);

      final match = router.configuration.findMatch(
        Uri.parse(RouteNames.coordinatorEvidenceReviewDetail('class', '42')),
      );

      expect(match.isError, isFalse);
      expect(
        match.fullPath,
        RouteNames.coordinatorEvidenceReviewDetailRoute,
      );
      expect(insideShell(match), isFalse);
      expect(match.pathParameters, {'type': 'class', 'id': '42'});
    });

    testWidgets('retired coordinator tab routes no longer exist',
        (tester) async {
      final router = await setUpRouter(tester);

      for (final path in [
        '/coordinator/coord-activities',
        '/coordinator/coord-profile',
      ]) {
        expect(
          router.configuration.findMatch(Uri.parse(path)).isError,
          isTrue,
          reason: path,
        );
      }
    });
  });
}
