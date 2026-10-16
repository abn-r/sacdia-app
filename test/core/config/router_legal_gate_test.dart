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

UserEntity _user({
  bool legalPending = false,
  bool postRegisterComplete = true,
  String? globalRole,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        globalGrants: globalRole == null
            ? const []
            : [AuthorizationGrant(roleName: globalRole)],
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
    UserEntity? user,
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

  group('legal acceptance gate: pending user', () {
    testWidgets('is sent to the gate from the splash', (tester) async {
      final c = await setUpRouter(tester, _user(legalPending: true));
      expect(
        await redirectFor(c, RouteNames.splash),
        RouteNames.legalAcceptance,
      );
    });

    testWidgets('is sent to the gate from home and from a deep link',
        (tester) async {
      final c = await setUpRouter(tester, _user(legalPending: true));
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.clubDetailPath('1'),
        RouteNames.postRegistration,
        RouteNames.login,
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.legalAcceptance,
          reason: path,
        );
      }
    });

    testWidgets('stays on the gate (no redirect loop)', (tester) async {
      final c = await setUpRouter(tester, _user(legalPending: true));
      expect(await redirectFor(c, RouteNames.legalAcceptance), isNull);
    });

    testWidgets('a pending pastor sees the gate first', (tester) async {
      final c = await setUpRouter(
        tester,
        _user(legalPending: true, globalRole: 'pastor'),
      );
      expect(
        await redirectFor(c, RouteNames.homeDashboard),
        RouteNames.legalAcceptance,
      );
      expect(
        await redirectFor(c, RouteNames.splash),
        RouteNames.legalAcceptance,
      );
      expect(await redirectFor(c, RouteNames.legalAcceptance), isNull);
    });

    testWidgets('is gated before post-registration', (tester) async {
      final c = await setUpRouter(
        tester,
        _user(legalPending: true, postRegisterComplete: false),
      );
      expect(
        await redirectFor(c, RouteNames.splash),
        RouteNames.legalAcceptance,
      );
    });
  });

  group('legal acceptance gate: leaving the gate', () {
    testWidgets('accepted user on the gate goes home', (tester) async {
      final c = await setUpRouter(tester, _user());
      expect(
        await redirectFor(c, RouteNames.legalAcceptance),
        RouteNames.homeDashboard,
      );
    });

    testWidgets('accepted user with post-registration pending goes there',
        (tester) async {
      final c = await setUpRouter(tester, _user(postRegisterComplete: false));
      expect(
        await redirectFor(c, RouteNames.legalAcceptance),
        RouteNames.postRegistration,
      );
    });

    testWidgets('logged-out user on the gate goes to login', (tester) async {
      final c = await setUpRouter(tester, null);
      expect(
        await redirectFor(c, RouteNames.legalAcceptance),
        RouteNames.login,
      );
    });

    testWidgets('accepted user is not gated anywhere else', (tester) async {
      final c = await setUpRouter(tester, _user());
      expect(await redirectFor(c, RouteNames.homeDashboard), isNull);
      expect(
        await redirectFor(c, RouteNames.splash),
        RouteNames.homeDashboard,
      );
    });
  });
}
