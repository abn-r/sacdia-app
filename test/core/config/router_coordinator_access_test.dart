import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/coordinator_route_access.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

UserEntity _user({
  List<String> roles = const ['coordinator'],
  bool postRegisterComplete = false,
  List<AuthorizationGrant> clubAssignments = const [],
  ActingForInfo? actingFor,
  FamilySummary? family,
  AccountMode? serverMode,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: postRegisterComplete,
      actingFor: actingFor,
      family: family,
      serverMode: serverMode,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        globalGrants: [for (final r in roles) AuthorizationGrant(roleName: r)],
        clubAssignments: clubAssignments,
      ),
    );

const _activeClubGrant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 4,
  status: 'active',
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
  group('isCoordinatorWithoutClub', () {
    for (final role in coordinatorRoleNames) {
      test('a global $role with no club assignments qualifies', () {
        expect(isCoordinatorWithoutClub(_user(roles: [role])), isTrue);
      });
    }

    test('is case-insensitive on the role name', () {
      expect(
        isCoordinatorWithoutClub(_user(roles: ['Zone-Coordinator'])),
        isTrue,
      );
    });

    test('a coordinator with an active club assignment keeps the club home',
        () {
      expect(
        isCoordinatorWithoutClub(
          _user(clubAssignments: const [_activeClubGrant]),
        ),
        isFalse,
      );
    });

    test('pending, inactive or expired memberships are not club-less', () {
      for (final status in ['pending', 'inactive', 'expired']) {
        expect(
          isCoordinatorWithoutClub(
            _user(
              clubAssignments: [
                AuthorizationGrant(
                  assignmentId: 'a2',
                  roleName: 'member',
                  clubId: 1,
                  sectionId: 4,
                  status: status,
                ),
              ],
            ),
          ),
          isFalse,
          reason: status,
        );
      }
    });

    test('a designated (scheduled) assignment does not count as membership',
        () {
      expect(
        isCoordinatorWithoutClub(
          _user(
            clubAssignments: const [
              AuthorizationGrant(
                assignmentId: 'a3',
                roleName: 'director',
                clubId: 1,
                sectionId: 4,
                status: 'designated',
              ),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('is false while acting for a dependent', () {
      expect(
        isCoordinatorWithoutClub(
          _user(
            postRegisterComplete: true,
            actingFor: const ActingForInfo(
              actorUserId: 'u1',
              dependentUserId: 'ana',
            ),
          ),
        ),
        isFalse,
      );
    });

    test('other roles, pastors and anonymous users do not qualify', () {
      expect(isCoordinatorWithoutClub(null), isFalse);
      expect(isCoordinatorWithoutClub(_user(roles: ['pastor'])), isFalse);
      expect(isCoordinatorWithoutClub(_user(roles: ['director-lf'])), isFalse);
      expect(isCoordinatorWithoutClub(_user(roles: const [])), isFalse);
      expect(
        isCoordinatorWithoutClub(const UserEntity(id: 'x')),
        isFalse,
      );
    });

    test('a pastor without a club is still only a pastor', () {
      final pastor = _user(roles: ['pastor']);
      expect(isPastorWithoutClub(pastor), isTrue);
      expect(isCoordinatorWithoutClub(pastor), isFalse);
      // Y un coordinador no es pastor.
      expect(isPastorWithoutClub(_user()), isFalse);
    });
  });

  group('userNeedsPostRegistration', () {
    test('a coordinator without a club is exempt', () {
      expect(userNeedsPostRegistration(_user()), isFalse);
    });

    test('a coordinator with a club still completes it', () {
      expect(
        userNeedsPostRegistration(
          _user(clubAssignments: const [_activeClubGrant]),
        ),
        isTrue,
      );
    });

    test('a profile_incomplete account always needs it', () {
      // Sin fecha de nacimiento la restricción la levanta el servidor.
      final user = _user(serverMode: AccountMode.profileIncomplete);
      expect(userNeedsPostRegistration(user), isTrue);
    });

    test('a pastor without a club stays exempt and a plain user does not', () {
      expect(userNeedsPostRegistration(_user(roles: ['pastor'])), isFalse);
      expect(userNeedsPostRegistration(_user(roles: ['user'])), isTrue);
    });
  });

  group('isCoordinatorAllowedPath', () {
    test('allows the hub, its modules, the profile, inbox and Mi familia', () {
      for (final allowed in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.homeMedicalInfo,
        RouteNames.notificationsInbox,
        RouteNames.coordinator,
        '${RouteNames.coordinator}/',
        RouteNames.coordinatorClubs,
        RouteNames.coordinatorSla,
        RouteNames.coordinatorReports,
        RouteNames.coordinatorEvidenceReview,
        RouteNames.coordinatorEvidenceReviewDetail('folder', '9'),
        RouteNames.coordinatorConsentReview,
        RouteNames.family,
        RouteNames.familyDetailPath('d1'),
      ]) {
        expect(isCoordinatorAllowedPath(allowed), isTrue, reason: allowed);
      }
    });

    test('blocks club-only routes', () {
      for (final blocked in [
        RouteNames.homeHonors,
        RouteNames.homeClasses,
        RouteNames.homeClub,
        RouteNames.homeMembers,
        RouteNames.homeActivities,
        '/coordinator/coord-activities',
        '/coordinator/coord-profile',
        '/coordinator/camporee-approvals',
        RouteNames.investitureAuthorize,
        RouteNames.ownInvestiture,
        RouteNames.clubDetailPath('1'),
        '/coordinatorx',
        '/familyx',
      ]) {
        expect(isCoordinatorAllowedPath(blocked), isFalse, reason: blocked);
      }
    });
  });

  group('router redirect for a coordinator without a club', () {
    late BuildContext context;

    Future<ProviderContainer> setUpRouter(
      WidgetTester tester,
      UserEntity user,
    ) async {
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
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        ],
      );
      addTearDown(() {
        container.read(routerProvider).dispose();
        container.dispose();
      });
      await container.read(authNotifierProvider.future);
      await container.read(appBootstrapProvider.future);
      return container;
    }

    Future<String?> redirectFor(
      ProviderContainer container,
      String location,
    ) async {
      final router = container.read(routerProvider);
      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: location,
        path: location,
        fullPath: location,
        pathParameters: const {},
        pageKey: ValueKey(location),
      );
      return router.configuration.topRedirect(context, state);
    }

    testWidgets('is not forced into post-registration from the splash',
        (tester) async {
      final container = await setUpRouter(tester, _user());
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('leaves the post-registration route for the home',
        (tester) async {
      final container = await setUpRouter(tester, _user());
      expect(
        await redirectFor(container, RouteNames.postRegistration),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('is sent home from a public route', (tester) async {
      final container = await setUpRouter(tester, _user());
      expect(
        await redirectFor(container, RouteNames.login),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('may open the hub, its modules, profile and inbox',
        (tester) async {
      final container = await setUpRouter(tester, _user());
      for (final allowed in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.notificationsInbox,
        RouteNames.coordinator,
        RouteNames.coordinatorClubs,
        RouteNames.coordinatorSla,
        RouteNames.coordinatorReports,
        RouteNames.coordinatorEvidenceReview,
        RouteNames.coordinatorEvidenceReviewDetail('folder', '9'),
        RouteNames.coordinatorConsentReview,
        RouteNames.family,
      ]) {
        expect(await redirectFor(container, allowed), isNull, reason: allowed);
      }
    });

    testWidgets('club-only routes are redirected to the coordination home',
        (tester) async {
      final container = await setUpRouter(tester, _user());
      for (final blocked in [
        RouteNames.homeHonors,
        RouteNames.homeClasses,
        RouteNames.homeClub,
        RouteNames.homeMembers,
        RouteNames.homeActivities,
        '/coordinator/coord-activities',
        '/coordinator/coord-profile',
        '/coordinator/camporee-approvals',
        RouteNames.investitureAuthorize,
        RouteNames.clubDetailPath('1'),
      ]) {
        expect(
          await redirectFor(container, blocked),
          RouteNames.homeDashboard,
          reason: blocked,
        );
      }
    });

    testWidgets('a coordinator who is also a pastor keeps both surfaces',
        (tester) async {
      final container = await setUpRouter(
        tester,
        _user(roles: ['coordinator', 'pastor']),
      );
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.homeDashboard,
      );
      expect(
        await redirectFor(container, RouteNames.investitureAuthorize),
        isNull,
      );
      expect(
        await redirectFor(container, RouteNames.homeHonors),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('a coordinator with a club is not restricted', (tester) async {
      final container = await setUpRouter(
        tester,
        _user(
          postRegisterComplete: true,
          clubAssignments: const [_activeClubGrant],
        ),
      );
      expect(await redirectFor(container, RouteNames.homeHonors), isNull);
      expect(await redirectFor(container, RouteNames.homeClub), isNull);
    });

    testWidgets('a coordinator with a club still completes post-registration',
        (tester) async {
      final container = await setUpRouter(
        tester,
        _user(clubAssignments: const [_activeClubGrant]),
      );
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.postRegistration,
      );
    });

    testWidgets('a pastor without a club is still sent to authorizations',
        (tester) async {
      final container = await setUpRouter(tester, _user(roles: ['pastor']));
      expect(
        await redirectFor(container, RouteNames.homeHonors),
        RouteNames.investitureAuthorize,
      );
      expect(
        await redirectFor(container, RouteNames.coordinator),
        RouteNames.investitureAuthorize,
      );
    });
  });

  group('shell navigation', () {
    test('a coordinator without a club gets Coordination and Profile', () {
      final items = shellNavItemsForTesting(_user());
      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
      ]);
      expect(items.first.labelKey, 'router.nav.coordination');
      expect(items.last.labelKey, 'router.nav.profile');
    });

    test('coordination wins over authorizations for a coordinator-pastor', () {
      final items = shellNavItemsForTesting(
        _user(roles: ['coordinator', 'pastor']),
      );
      expect(items.first.labelKey, 'router.nav.coordination');
    });

    test('a coordinator with a club keeps the regular tabs', () {
      final items = shellNavItemsForTesting(
        _user(
          postRegisterComplete: true,
          clubAssignments: const [_activeClubGrant],
        ),
      );
      expect(items.first.labelKey, 'router.nav.home');
    });
  });

  group('isPendingNavigationAllowed', () {
    test('a coordinator without a club receives coordinator and inbox routes',
        () {
      for (final route in [
        RouteNames.coordinatorConsentReview,
        RouteNames.notificationsInbox,
        RouteNames.family,
      ]) {
        expect(
          isPendingNavigationAllowed(
            user: _user(),
            route: route,
            acting: false,
          ),
          isTrue,
          reason: route,
        );
      }
    });

    test('club-only routes are dropped for a coordinator without a club', () {
      expect(
        isPendingNavigationAllowed(
          user: _user(),
          route: RouteNames.homeActivities,
          acting: false,
        ),
        isFalse,
      );
    });
  });
}
