import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

UserEntity _user({
  required String role,
  bool global = true,
  bool postRegisterComplete = false,
  List<AuthorizationGrant> clubAssignments = const [],
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: postRegisterComplete,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        globalGrants: global ? [AuthorizationGrant(roleName: role)] : const [],
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
  group('isPastorWithoutClub', () {
    test('a global pastor with no club assignments qualifies', () {
      expect(isPastorWithoutClub(_user(role: 'pastor')), isTrue);
    });

    test('is case-insensitive on the role name', () {
      expect(isPastorWithoutClub(_user(role: 'Pastor')), isTrue);
    });

    test('a pastor with an active club assignment keeps the club home', () {
      expect(
        isPastorWithoutClub(
          _user(role: 'pastor', clubAssignments: const [_activeClubGrant]),
        ),
        isFalse,
      );
    });

    test('a pastor with only a pending membership is not club-less', () {
      expect(
        isPastorWithoutClub(
          _user(
            role: 'pastor',
            clubAssignments: const [
              AuthorizationGrant(
                assignmentId: 'a2',
                roleName: 'member',
                clubId: 1,
                sectionId: 4,
                status: 'pending',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('other global roles and anonymous users do not qualify', () {
      expect(isPastorWithoutClub(_user(role: 'director-lf')), isFalse);
      expect(isPastorWithoutClub(_user(role: 'coordinator')), isFalse);
      expect(isPastorWithoutClub(null), isFalse);
      expect(
          isPastorWithoutClub(_user(role: 'pastor', global: false)), isFalse);
    });
  });

  group('router redirect for a pastor without a club', () {
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
      final container = await setUpRouter(tester, _user(role: 'pastor'));
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('is sent home from a public route', (tester) async {
      final container = await setUpRouter(tester, _user(role: 'pastor'));
      expect(
        await redirectFor(container, RouteNames.login),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('can open any app route without the post-registration detour',
        (tester) async {
      final container = await setUpRouter(tester, _user(role: 'pastor'));
      expect(await redirectFor(container, RouteNames.homeProfile), isNull);
      expect(await redirectFor(container, RouteNames.investitureAuthorize),
          isNull);
    });

    testWidgets(
        'a regular user with an incomplete post-registration is sent to it',
        (tester) async {
      final container = await setUpRouter(
        tester,
        _user(role: 'user', clubAssignments: const [_activeClubGrant]),
      );
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.postRegistration,
      );
      expect(
        await redirectFor(container, RouteNames.homeProfile),
        RouteNames.postRegistration,
      );
    });

    testWidgets('a pastor with a club still completes post-registration',
        (tester) async {
      final container = await setUpRouter(
        tester,
        _user(role: 'pastor', clubAssignments: const [_activeClubGrant]),
      );
      expect(
        await redirectFor(container, RouteNames.splash),
        RouteNames.postRegistration,
      );
    });
  });

  group('shell navigation', () {
    test('a pastor without a club only gets Authorizations and Profile', () {
      final items = shellNavItemsForTesting(_user(role: 'pastor'));
      expect(items.map((i) => i.route), [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
      ]);
      expect(items.first.labelKey, 'router.nav.authorizations');
      expect(items.last.labelKey, 'router.nav.profile');
    });

    test('other users keep the regular tabs', () {
      final items = shellNavItemsForTesting(
        _user(role: 'user', clubAssignments: const [_activeClubGrant]),
      );
      expect(items.first.labelKey, 'router.nav.home');
      expect(items.last.route, RouteNames.homeProfile);
    });
  });
}
