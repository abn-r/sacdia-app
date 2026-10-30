import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

UserEntity _user({
  required AccountMode mode,
  bool postRegisterComplete = true,
  bool legalPending = false,
  String id = 'u1',
}) =>
    UserEntity(
      id: id,
      email: '$id@example.com',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      serverMode: mode,
      principal: mode != AccountMode.adult
          ? PrincipalInfo(
              kind: PrincipalKind.supervisedUser,
              supervision: SupervisionInfo(
                status: mode == AccountMode.teenPending
                    ? SupervisionStatus.pendingGuardian
                    : SupervisionStatus.active,
              ),
            )
          : const PrincipalInfo(kind: PrincipalKind.user),
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

/// Auth que se resuelve cuando el test lo decide, para simular la carga.
class _GatedAuth extends AuthNotifier {
  _GatedAuth(this.user, {this.gate});

  UserEntity? user;
  final Completer<void>? gate;

  @override
  Future<UserEntity?> build() async {
    if (gate != null) await gate!.future;
    return user;
  }
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

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
        authNotifierProvider.overrideWith(() => _GatedAuth(user)),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
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

  group('REAL router: pending teen (allowlist)', () {
    testWidgets('allowlisted destinations stay put', (tester) async {
      final c = await setUpRouter(tester, _user(mode: AccountMode.teenPending));
      expect(await redirectFor(c, RouteNames.teenPendingHome), isNull);
      expect(await redirectFor(c, RouteNames.legalAcceptance),
          RouteNames.teenPendingHome);
    });

    testWidgets('everything else goes back to the status screen',
        (tester) async {
      final c = await setUpRouter(tester, _user(mode: AccountMode.teenPending));
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.homeUnits,
        RouteNames.clubDetailPath('1'),
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.notificationsInbox,
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.teenPendingHome,
          reason: path,
        );
      }
    });

    testWidgets('splash and login land on the status screen', (tester) async {
      final c = await setUpRouter(tester, _user(mode: AccountMode.teenPending));
      expect(
          await redirectFor(c, RouteNames.splash), RouteNames.teenPendingHome);
      expect(
          await redirectFor(c, RouteNames.login), RouteNames.teenPendingHome);
    });

    testWidgets('before post-registration, the steps come first',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(mode: AccountMode.teenPending, postRegisterComplete: false),
      );
      expect(
          await redirectFor(c, RouteNames.splash), RouteNames.postRegistration);
      expect(await redirectFor(c, RouteNames.homeDashboard),
          RouteNames.postRegistration);
      expect(
          await redirectFor(c, RouteNames.family), RouteNames.postRegistration);
      expect(await redirectFor(c, RouteNames.postRegistration), isNull);
    });

    testWidgets('the legal gate still comes first and is reachable',
        (tester) async {
      final c = await setUpRouter(
        tester,
        _user(mode: AccountMode.teenPending, legalPending: true),
      );
      expect(await redirectFor(c, RouteNames.homeDashboard),
          RouteNames.legalAcceptance);
      expect(await redirectFor(c, RouteNames.teenPendingHome),
          RouteNames.legalAcceptance);
      expect(await redirectFor(c, RouteNames.legalAcceptance), isNull);
    });
  });

  group('REAL router: supervised teen with a guardian (denylist)', () {
    testWidgets('Mi familia and the status screen go home', (tester) async {
      final c =
          await setUpRouter(tester, _user(mode: AccountMode.teenSupervised));
      for (final path in [
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.familyLink,
        RouteNames.familyDetailPath('ana-1'),
        RouteNames.teenPendingHome,
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.homeDashboard,
          reason: path,
        );
      }
    });

    testWidgets('the member app is open', (tester) async {
      final c =
          await setUpRouter(tester, _user(mode: AccountMode.teenSupervised));
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.notificationsInbox,
      ]) {
        expect(await redirectFor(c, path), isNull, reason: path);
      }
      expect(await redirectFor(c, RouteNames.splash), RouteNames.homeDashboard);
    });
  });

  group('REAL router: adults and acting are unchanged', () {
    testWidgets('an adult keeps Mi familia and never sees the status screen',
        (tester) async {
      final c = await setUpRouter(tester, _user(mode: AccountMode.adult));
      expect(await redirectFor(c, RouteNames.family), isNull);
      expect(await redirectFor(c, RouteNames.homeClasses), isNull);
      expect(await redirectFor(c, RouteNames.teenPendingHome),
          RouteNames.homeDashboard);
    });

    testWidgets('a guardian acting for a minor still cannot open Mi familia',
        (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      final c = await setUpRouter(
        tester,
        _user(mode: AccountMode.adult, id: 'ana-1'),
        session: session,
      );
      expect(await redirectFor(c, RouteNames.family), RouteNames.homeDashboard);
      expect(await redirectFor(c, RouteNames.homeClasses), isNull);
    });
  });

  group('REAL router: a push that arrives while the session loads', () {
    Future<
        ({
          ProviderContainer container,
          GoRouter router,
          Completer<void> gate,
          PushNotificationService push,
        })> pumpApp(WidgetTester tester, UserEntity user) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final gate = Completer<void>();
      final container = createTestContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _GatedAuth(user, gate: gate)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          dashboardNotifierProvider.overrideWith(_NullDashboard.new),
          profileNotifierProvider.overrideWith(_NullProfile.new),
          notificationsRepositoryProvider
              .overrideWithValue(FakeNotificationsRepository()),
        ],
      );
      addTearDown(() {
        container.read(routerProvider).dispose();
      });
      final push = PushNotificationService(
        dio: Dio(),
        ref: container.read(Provider<Ref>((ref) => ref)),
        navigatorKey: pushNavigatorKey,
      );
      final router = container.read(routerProvider);
      await pumpLocalizedRouterApp(tester, container, router);
      return (container: container, router: router, gate: gate, push: push);
    }

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.last.matchedLocation;

    testWidgets('is parked on splash and delivered once the session is ready',
        (tester) async {
      final app = await pumpApp(tester, _user(mode: AccountMode.adult));
      expect(location(app.router), RouteNames.splash);

      app.push.handleNotificationTapForTesting(
        RemoteMessage(data: {'route': RouteNames.notificationsInbox}),
      );
      // Todavía cargando: el redirect lo habría descartado; queda en espera.
      expect(
        app.container.read(pendingNavigationProvider)?.route,
        RouteNames.notificationsInbox,
      );

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.notificationsInbox);
      expect(app.container.read(pendingNavigationProvider), isNull);
    });

    testWidgets('a pending teen never receives a member destination',
        (tester) async {
      final app = await pumpApp(tester, _user(mode: AccountMode.teenPending));

      app.push.handleNotificationTapForTesting(
        RemoteMessage(data: {'route': RouteNames.notificationsInbox}),
      );
      expect(app.container.read(pendingNavigationProvider), isNotNull);

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.teenPendingHome);
      expect(app.container.read(pendingNavigationProvider), isNull);
    });

    testWidgets('with nobody signed in the destination is dropped',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<void>();
      final container = createTestContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _GatedAuth(null, gate: gate)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() {
        container.read(routerProvider).dispose();
      });
      final router = container.read(routerProvider);
      await pumpLocalizedRouterApp(tester, container, router);

      container.read(pendingNavigationProvider.notifier).state =
          const PendingNavigation(route: RouteNames.notificationsInbox);
      gate.complete();
      await _settle(tester);

      expect(container.read(pendingNavigationProvider), isNull);
      expect(location(router), isNot(RouteNames.notificationsInbox));
    });
  });
}
