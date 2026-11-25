import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../support/riverpod_test_support.dart';

const _supervision = 'supervision.app_view';
const _hubView = 'coordination.hub_view';
const _pastorOnly = 'admin_panel.pastor_only';
const _guardianFamily = FamilySummary(isGuardian: true, dependentsCount: 1);

/// Every capability that gates a supervision screen (Union view).
const _allSupervision = [
  _supervision,
  'club_enrollments.validate',
  'folders.evaluate',
  'requests.review_territory',
  'analytics.operations_dashboard',
  'clubs.view_territory',
  'reports.view_territory',
  'annual_progress.view_territory',
  'union_camporees.approve_registrations',
  'camporee_orders.configure_offering',
];

const _activeClubGrant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 4,
  status: 'active',
);

/// Adult account as `/auth/me` reports it for a territorial supervisor. By
/// default club-less and `club_exempt`; the capabilities decide everything.
UserEntity _user({
  List<String> capabilities = const [_supervision],
  List<AuthorizationGrant> clubAssignments = const [],
  OnboardingMode onboardingMode = OnboardingMode.clubExempt,
  FamilySummary? family,
  ActingForInfo? actingFor,
  AuthorizationTerritory? territory,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      onboardingMode: onboardingMode,
      family: family,
      actingFor: actingFor,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        clubAssignments: clubAssignments,
        activeAssignmentId: clubAssignments.isEmpty ? null : 'a1',
        capabilities: capabilities,
        territory: territory,
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

void main() {
  late BuildContext context;

  Future<ProviderContainer> setUpRouter(
    WidgetTester tester,
    UserEntity user, {
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

  List<String> navRoutes(UserEntity user) =>
      shellNavItemsForTesting(user).map((i) => i.route).toList();

  group('club member with supervision: extra «Supervisión» tab', () {
    final user = _user(
      clubAssignments: const [_activeClubGrant],
      onboardingMode: OnboardingMode.club,
    );

    test('is not a club-less supervisor and keeps the club tabs', () {
      expect(canOpenSupervision(user), isTrue);
      expect(isSupervisorWithoutClub(user), isFalse);
      final items = shellNavItemsForTesting(user);
      expect(items.first.labelKey, 'router.nav.home');
      expect(items.last.labelKey, 'router.nav.profile');
      expect(items.map((i) => i.route), contains(RouteNames.supervision));
      // The supervision tab sits right before Profile.
      expect(items[items.length - 2].route, RouteNames.supervision);
      expect(
        items[items.length - 2].labelKey,
        'router.nav.supervision',
      );
    });

    test('the tab is hidden without the capability', () {
      final plain = _user(
        capabilities: const [],
        clubAssignments: const [_activeClubGrant],
        onboardingMode: OnboardingMode.club,
      );
      expect(navRoutes(plain), isNot(contains(RouteNames.supervision)));
    });

    testWidgets('club routes are not restricted by the club-less rule',
        (tester) async {
      final c = await setUpRouter(tester, user);
      expect(await redirectFor(c, RouteNames.supervision), isNull);
      expect(await redirectFor(c, RouteNames.homeHonors), isNull);
    });
  });

  group('supervisor without a club', () {
    final user = _user(capabilities: _allSupervision);

    test('qualifies and gets Supervisión (home) and Profile', () {
      expect(isSupervisorWithoutClub(user), isTrue);
      final items = shellNavItemsForTesting(user);
      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
      ]);
      expect(items.first.labelKey, 'router.nav.supervision');
      expect(items.last.labelKey, 'router.nav.profile');
    });

    testWidgets('is not forced into post-registration and lands on the hub',
        (tester) async {
      final c = await setUpRouter(tester, user);
      expect(
        await redirectFor(c, RouteNames.splash),
        RouteNames.homeDashboard,
      );
      expect(
        await redirectFor(c, RouteNames.login),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('opens the hub, every function, profile, inbox and Mi familia',
        (tester) async {
      final c = await setUpRouter(tester, user);
      for (final allowed in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.homeMedicalInfo,
        RouteNames.notificationsInbox,
        RouteNames.accessDenied,
        RouteNames.supervision,
        RouteNames.supervisionEnrollments,
        RouteNames.supervisionFolders,
        RouteNames.supervisionFolderDetail('f1'),
        RouteNames.supervisionRequests,
        RouteNames.supervisionOperations,
        RouteNames.supervisionClubs,
        RouteNames.supervisionClubDetail('c1'),
        RouteNames.supervisionReports,
        RouteNames.supervisionAnnualProgress,
        RouteNames.supervisionUnionCamporees,
        RouteNames.supervisionUnionCamporeeApprovals('9'),
        RouteNames.supervisionUnionCamporeeOrders('9'),
        RouteNames.family,
      ]) {
        expect(await redirectFor(c, allowed), isNull, reason: allowed);
      }
    });

    testWidgets(
        'deep links to club-only, panel-only or coordination routes '
        'land on the hub', (tester) async {
      final c = await setUpRouter(tester, user);
      for (final blocked in [
        RouteNames.homeHonors,
        RouteNames.homeClasses,
        RouteNames.homeClub,
        RouteNames.homeMembers,
        RouteNames.homeActivities,
        RouteNames.investitureAuthorize,
        RouteNames.clubDetailPath('1'),
        RouteNames.coordinator,
        // Panel-only screen: a supervisor is not panel-only.
        RouteNames.panelOnlyAccount,
      ]) {
        expect(
          await redirectFor(c, blocked),
          RouteNames.homeDashboard,
          reason: blocked,
        );
      }
    });

    testWidgets('a function without its capability goes to access denied',
        (tester) async {
      // `supervision.app_view` alone opens the hub, not the folders function:
      // the catalog guard (last step) decides per screen.
      final c = await setUpRouter(tester, _user());
      expect(await redirectFor(c, RouteNames.supervision), isNull);
      expect(
        await redirectFor(c, RouteNames.supervisionFolders),
        RouteNames.accessDenied,
      );
    });

    testWidgets('an unconfigured territory still opens the hub',
        (tester) async {
      final unconfigured = _user(
        territory: const AuthorizationTerritory(level: 'unconfigured'),
      );
      expect(isSupervisorWithoutClub(unconfigured), isTrue);
      expect(navRoutes(unconfigured), [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
      ]);
      final c = await setUpRouter(tester, unconfigured);
      expect(await redirectFor(c, RouteNames.supervision), isNull);
      expect(await redirectFor(c, RouteNames.homeProfile), isNull);
      expect(
        await redirectFor(c, RouteNames.homeMembers),
        RouteNames.homeDashboard,
      );
    });

    test('pending navigation keeps supervision routes and drops club ones', () {
      expect(
        isPendingNavigationAllowed(
          user: user,
          route: RouteNames.supervisionClubs,
          acting: false,
        ),
        isTrue,
      );
      expect(
        isPendingNavigationAllowed(
          user: user,
          route: RouteNames.homeActivities,
          acting: false,
        ),
        isFalse,
      );
    });
  });

  group('unconfigured territory deep links', () {
    const unconfigured = AuthorizationTerritory(level: 'unconfigured');
    const queueCaps = [
      _supervision,
      'club_enrollments.validate',
      'folders.evaluate',
      'analytics.operations_dashboard',
    ];

    testWidgets('without a club, function routes land on the hub',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(capabilities: queueCaps, territory: unconfigured),
      );
      for (final path in [
        RouteNames.supervisionEnrollments,
        RouteNames.supervisionFolders,
        RouteNames.supervisionFolderDetail('abc'),
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.supervision,
          reason: path,
        );
      }
      expect(await redirectFor(c, RouteNames.supervision), isNull);
    });

    testWidgets('with a visible club, a function route still lands on the hub',
        (tester) async {
      final user = _user(
        capabilities: queueCaps,
        clubAssignments: const [_activeClubGrant],
        onboardingMode: OnboardingMode.club,
        territory: unconfigured,
      );
      expect(isSupervisorWithoutClub(user), isFalse);
      final c = await setUpRouter(tester, user);
      expect(
        await redirectFor(c, RouteNames.supervisionOperations),
        '/supervision',
      );
    });

    testWidgets('a configured supervisor keeps the function route',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          capabilities: queueCaps,
          territory: const AuthorizationTerritory(level: 'union', unionId: 1),
        ),
      );
      expect(await redirectFor(c, RouteNames.supervisionEnrollments), isNull);
    });
  });

  group('union camporee routes: catalog guard by capability', () {
    // Resolved location -> route template: the catalog guard reads the
    // template (`fullPath`) as go_router does for parameterised routes.
    const camporeeRoutes = {
      RouteNames.supervisionUnionCamporees:
          RouteNames.supervisionUnionCamporees,
      '/supervision/union-camporees/7/approvals':
          RouteNames.supervisionUnionCamporeeApprovalsRoute,
      '/supervision/union-camporees/7/orders':
          RouteNames.supervisionUnionCamporeeOrdersRoute,
    };

    testWidgets('a Division supervisor is sent to access denied',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          capabilities: const [
            _supervision,
            'club_enrollments.validate',
            'folders.evaluate',
            'requests.review_territory',
            'clubs.view_territory',
          ],
          territory:
              const AuthorizationTerritory(level: 'division', divisionId: 1),
        ),
      );
      for (final entry in camporeeRoutes.entries) {
        expect(
          await redirectFor(c, entry.key, fullPath: entry.value),
          RouteNames.accessDenied,
          reason: entry.key,
        );
      }
    });

    testWidgets('a Union supervisor with both capabilities reaches all three',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(
          capabilities: _allSupervision,
          territory: const AuthorizationTerritory(level: 'union', unionId: 1),
        ),
      );
      for (final entry in camporeeRoutes.entries) {
        expect(
          await redirectFor(c, entry.key, fullPath: entry.value),
          isNull,
          reason: entry.key,
        );
      }
    });
  });

  group('supervisor + coordination (hub_view)', () {
    final user = _user(
      capabilities: const [_supervision, _hubView, 'clubs.view_territory'],
    );

    test('nav: Supervisión, Coordinación, Perfil', () {
      final items = shellNavItemsForTesting(user);
      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.coordinator,
        RouteNames.homeProfile,
      ]);
      expect(items.first.labelKey, 'router.nav.supervision');
      expect(items[1].labelKey, 'router.nav.coordination');
    });

    testWidgets('allow-lists are merged', (tester) async {
      final c = await setUpRouter(tester, user);
      for (final allowed in [
        RouteNames.supervision,
        RouteNames.supervisionClubs,
        RouteNames.coordinator,
        RouteNames.coordinatorSla,
        RouteNames.coordinatorReports,
        RouteNames.coordinatorEvidenceReview,
        RouteNames.coordinatorConsentReview,
        RouteNames.family,
      ]) {
        expect(await redirectFor(c, allowed), isNull, reason: allowed);
      }
      expect(
        await redirectFor(c, RouteNames.homeHonors),
        RouteNames.homeDashboard,
      );
    });
  });

  group('supervisor + pastor', () {
    final user = _user(capabilities: const [_supervision, _pastorOnly]);

    test('the supervisor persona wins the nav and the home', () {
      expect(isPastorWithoutClub(user), isTrue);
      expect(isSupervisorWithoutClub(user), isTrue);
      final items = shellNavItemsForTesting(user);
      expect(items.first.labelKey, 'router.nav.supervision');
      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
      ]);
    });

    testWidgets(
        'supervision routes open; authorizations only with the '
        'authorizer capability', (tester) async {
      final c = await setUpRouter(tester, user);
      expect(await redirectFor(c, RouteNames.supervision), isNull);
      expect(
        await redirectFor(c, RouteNames.investitureAuthorize),
        RouteNames.homeDashboard,
      );
      final authorizer = await setUpRouter(
        tester,
        _user(
          capabilities: const [
            _supervision,
            _pastorOnly,
            'investiture.authorize_requests',
          ],
        ),
      );
      expect(
        await redirectFor(authorizer, RouteNames.investitureAuthorize),
        isNull,
      );
    });
  });

  group('supervisor + guardian', () {
    final user = _user(family: _guardianFamily);

    test('keeps the supervision home', () {
      expect(isGuardianAccount(user), isTrue);
      expect(isSupervisorWithoutClub(user), isTrue);
      expect(shellNavItemsForTesting(user).first.labelKey,
          'router.nav.supervision');
    });

    testWidgets('Mi familia stays reachable', (tester) async {
      final c = await setUpRouter(tester, user);
      expect(await redirectFor(c, RouteNames.family), isNull);
      expect(
        await redirectFor(c, RouteNames.familyDetailPath('d1')),
        isNull,
      );
      expect(await redirectFor(c, RouteNames.supervision), isNull);
    });
  });

  group('acting for a dependent', () {
    // While acting the evaluated authorization is the minor's: no supervision
    // capability, and the persona predicates are false.
    final minorView = _user(
      capabilities: const [],
      onboardingMode: OnboardingMode.club,
      actingFor: const ActingForInfo(
        actorUserId: 'u1',
        dependentUserId: 'ana-1',
      ),
    );

    test('the persona is off even if the capability leaked', () {
      final leaked = _user(
        actingFor: const ActingForInfo(
          actorUserId: 'u1',
          dependentUserId: 'ana-1',
        ),
      );
      expect(isSupervisorWithoutClub(leaked), isFalse);
      // No supervisor home: the regular home tab stays first.
      expect(
        shellNavItemsForTesting(leaked).first.labelKey,
        'router.nav.home',
      );
    });

    testWidgets('supervision routes are denied and Mi familia is blocked',
        (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      final c = await setUpRouter(tester, minorView, session: session);
      expect(
        await redirectFor(c, RouteNames.supervision),
        RouteNames.accessDenied,
      );
      expect(
        await redirectFor(c, RouteNames.supervisionClubs),
        RouteNames.accessDenied,
      );
      expect(
        await redirectFor(c, RouteNames.family),
        RouteNames.homeDashboard,
      );
      expect(await redirectFor(c, RouteNames.accessDenied), isNull);
    });
  });
}
