import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/authorization/screen_catalog.dart';
import 'package:sacdia_app/core/config/access_denied_view.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/route_screen_policy.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../features/family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';
import '../../features/auth/presentation/providers/auth_notifier_test_support.dart';

const _memberGrant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 4,
  status: 'active',
);

/// Adulto con club activo. Sin [permissions] ni [capabilities] no abre nada
/// del catálogo.
UserEntity _user({
  List<String> permissions = const ['clubs:read'],
  List<String> capabilities = const [],
  List<AuthorizationGrant> clubAssignments = const [_memberGrant],
  String? activeAssignmentId = 'a1',
  bool legalPending = false,
  bool postRegisterComplete = true,
  PrincipalInfo? principal,
  ActingForInfo? actingFor,
  bool withAuthorization = true,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      principal: principal,
      actingFor: actingFor,
      authorization: withAuthorization
          ? AuthorizationSnapshot(
              effectivePermissions: permissions,
              clubAssignments: clubAssignments,
              activeAssignmentId: activeAssignmentId,
              capabilities: capabilities,
            )
          : null,
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

class _NullDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _Repo extends FakeAuthRepository {
  _Repo(this.user);

  final UserEntity user;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async => Right(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  group('routeScreenIds', () {
    test('every governed route maps to a catalog screen', () {
      for (final entry in routeScreenIds.entries) {
        expect(getScreen(entry.value), isNotNull, reason: entry.key);
        expect(entry.key, startsWith('/'), reason: entry.key);
      }
    });

    test('covers the catalog screens that have a route in the app', () {
      expect(routeScreenIds[RouteNames.homeClasses], 'app-classes');
      expect(routeScreenIds[RouteNames.homeActivities], 'activities');
      expect(routeScreenIds[RouteNames.coordinator], 'coordinator-hub');
      expect(routeScreenIds[RouteNames.homeMembers], 'app-members');
      expect(routeScreenIds[RouteNames.homeUnits], 'app-units');
      expect(routeScreenIds[RouteNames.homeClub], 'app-club');
      expect(routeScreenIds[RouteNames.homeMaterials], 'app-materials');
      expect(routeScreenIds[RouteNames.homeGroupedClass], 'app-grouped-class');
      expect(
        routeScreenIds[RouteNames.sectionInvestiture],
        'app-section-investiture',
      );
      expect(
        routeScreenIds[RouteNames.investitureAuthorize],
        'app-investiture-authorizer',
      );
      expect(routeScreenIds[RouteNames.homeFinances], 'finances');
    });

    test('screenIdForRoute tolerates a trailing slash and unknown routes', () {
      expect(screenIdForRoute('${RouteNames.homeMembers}/'), 'app-members');
      expect(screenIdForRoute(RouteNames.homeDashboard), isNull);
      expect(screenIdForRoute(null), isNull);
      expect(screenIdForRoute(''), isNull);
    });
  });

  group('router redirect (catalog guard)', () {
    late BuildContext context;

    Future<ProviderContainer> setUpRouter(
      WidgetTester tester,
      UserEntity? user, {
      ActingForSession? session,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      );
      final container = createTestContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          if (session != null)
            actingForSessionProvider.overrideWithValue(session),
        ],
      );
      addTearDown(() => container.read(routerProvider).dispose());
      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);
      return container;
    }

    Future<String?> redirectFor(
      ProviderContainer container,
      String location, {
      String? fullPath,
    }) async {
      final router = container.read(routerProvider);
      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: location,
        path: fullPath ?? location,
        fullPath: fullPath ?? location,
        pathParameters: const {},
        pageKey: ValueKey(location),
      );
      return router.configuration.topRedirect(context, state);
    }

    testWidgets('denies a governed route the user cannot view', (tester) async {
      final c = await setUpRouter(tester, _user());
      for (final denied in [
        RouteNames.homeMembers,
        RouteNames.homeUnits,
        RouteNames.homeClub,
        RouteNames.homeMaterials,
        RouteNames.homeGroupedClass,
        RouteNames.sectionInvestiture,
        RouteNames.sectionInvestitureHistory,
        RouteNames.investitureAuthorize,
        RouteNames.coordinator,
        RouteNames.homeFinances,
        RouteNames.homeCamporees,
      ]) {
        expect(
          await redirectFor(c, denied),
          RouteNames.accessDenied,
          reason: denied,
        );
      }
      // El detalle hereda el gate de su pantalla (patrón de ruta).
      expect(
        await redirectFor(
          c,
          RouteNames.investitureAuthorizeDetailPath('r1'),
          fullPath: RouteNames.investitureAuthorizeDetail,
        ),
        RouteNames.accessDenied,
      );
    });

    testWidgets('a deep link to an allowed screen passes', (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          permissions: const [
            'clubs:read',
            'users:read_detail',
            'units:update'
          ],
          capabilities: const [
            'investiture.board',
            'investiture.authorize_requests',
            'coordination.hub_view',
          ],
        ),
      );
      for (final allowed in [
        RouteNames.homeMembers,
        RouteNames.homeUnits,
        RouteNames.sectionInvestiture,
        RouteNames.investitureAuthorize,
        RouteNames.coordinator,
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.accessDenied,
      ]) {
        expect(await redirectFor(c, allowed), isNull, reason: allowed);
      }
    });

    testWidgets('the gate is the capability, not the active role',
        (tester) async {
      // Director sin `investiture.board` (servidor anterior o revocado): deny.
      final c = await setUpRouter(
        tester,
        _user(
          clubAssignments: const [
            AuthorizationGrant(
              assignmentId: 'a1',
              roleName: 'director',
              clubId: 1,
              sectionId: 4,
              status: 'active',
            ),
          ],
        ),
      );
      expect(
        await redirectFor(c, RouteNames.sectionInvestiture),
        RouteNames.accessDenied,
      );
    });

    testWidgets('a super-admin keeps the catalog bypass', (tester) async {
      final c = await setUpRouter(
        tester,
        UserEntity(
          id: 'sa',
          email: 'sa@example.com',
          postRegisterComplete: true,
          authorization: const AuthorizationSnapshot(
            globalGrants: [AuthorizationGrant(roleName: 'super-admin')],
            clubAssignments: [_memberGrant],
            activeAssignmentId: 'a1',
          ),
        ),
      );
      expect(await redirectFor(c, RouteNames.homeMembers), isNull);
    });

    testWidgets('without an authorization snapshot (transient) it lets pass',
        (tester) async {
      final c = await setUpRouter(tester, _user(withAuthorization: false));
      expect(await redirectFor(c, RouteNames.homeMembers), isNull);
    });

    testWidgets('the legal gate wins over the guard', (tester) async {
      final c = await setUpRouter(tester, _user(legalPending: true));
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.legalAcceptance,
      );
      expect(
        await redirectFor(c, RouteNames.accessDenied),
        RouteNames.legalAcceptance,
      );
    });

    testWidgets('acting for a minor: Mi familia first, then the guard',
        (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      final c = await setUpRouter(
        tester,
        _user(
          actingFor: const ActingForInfo(
            actorUserId: 'u1',
            dependentUserId: 'ana-1',
          ),
        ),
        session: session,
      );
      expect(
        await redirectFor(c, RouteNames.family),
        RouteNames.homeDashboard,
      );
      // La autorización evaluada es la del menor: sin permiso, acceso
      // restringido (y esa pantalla nunca se rebota).
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.accessDenied,
      );
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('a pending teen goes to the status screen, never the guard',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          principal: const PrincipalInfo(
            kind: PrincipalKind.supervisedUser,
            supervision:
                SupervisionInfo(status: SupervisionStatus.pendingGuardian),
          ),
        ),
      );
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.teenPendingHome,
      );
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('a supervised teen is guarded like an adult', (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          principal: const PrincipalInfo(
            kind: PrincipalKind.supervisedUser,
            supervision: SupervisionInfo(status: SupervisionStatus.active),
          ),
        ),
      );
      expect(
        await redirectFor(c, RouteNames.family),
        RouteNames.homeDashboard,
      );
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.accessDenied,
      );
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('a linked device keeps its whitelist', (tester) async {
      final c = await setUpRouter(
        tester,
        _user(principal: const PrincipalInfo(kind: PrincipalKind.linkedDevice)),
      );
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.deviceHome,
      );
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('a pastor without a club is sent home, not to the guard',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          clubAssignments: const [],
          activeAssignmentId: null,
          postRegisterComplete: false,
          capabilities: const [
            'admin_panel.pastor_only',
            'investiture.authorize_requests',
          ],
        ),
      );
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.homeDashboard,
      );
      expect(await redirectFor(c, RouteNames.investitureAuthorize), isNull);
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('a coordinator without a club is sent home, not to the guard',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          clubAssignments: const [],
          activeAssignmentId: null,
          postRegisterComplete: false,
          capabilities: const ['coordination.hub_view'],
        ),
      );
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.homeDashboard,
      );
      expect(await redirectFor(c, RouteNames.coordinator), isNull);
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });

    testWidgets('post-registration wins over the guard', (tester) async {
      final c = await setUpRouter(tester, _user(postRegisterComplete: false));
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.postRegistration,
      );
    });
  });

  group('REAL router: denied deep link lands on the access-denied screen', () {
    testWidgets('shows the restricted state and «Ir al inicio» goes home',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final c = await buildAuthContainer(
        repo: _Repo(_user()),
        extraOverrides: [
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          dashboardNotifierProvider.overrideWith(_NullDashboard.new),
          profileNotifierProvider.overrideWith(_NullProfile.new),
        ],
      );
      await c.read(authNotifierProvider.future);
      addTearDown(() => c.read(routerProvider).dispose());
      final router = c.read(routerProvider);
      await pumpLocalizedRouterApp(tester, c, router);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      String where() =>
          router.routerDelegate.currentConfiguration.last.matchedLocation;
      expect(where(), RouteNames.homeDashboard);

      router.go(RouteNames.homeMembers);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(where(), RouteNames.accessDenied);
      expect(find.byType(AccessDeniedView), findsOneWidget);
      expect(find.text('Acceso restringido'), findsOneWidget);

      await tester.tap(find.text('Ir al inicio'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(where(), RouteNames.homeDashboard);
    });
  });
}
