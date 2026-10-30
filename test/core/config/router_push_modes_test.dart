import 'dart:async';

import 'package:dartz/dartz.dart' show Either, Right;
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
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_fixtures.dart';
import '../../features/family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

const _childId = '0d6e6d54-3c1d-4f1c-9a52-1f2b6a7a9c11';

UserEntity _user({
  PrincipalKind kind = PrincipalKind.user,
  AccountMode mode = AccountMode.adult,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      serverMode: mode,
      principal: PrincipalInfo(
        kind: kind,
        supervision: kind == PrincipalKind.supervisedUser
            ? SupervisionInfo(
                status: mode == AccountMode.teenPending
                    ? SupervisionStatus.pendingGuardian
                    : SupervisionStatus.active,
              )
            : null,
      ),
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

/// Auth que se resuelve cuando el test lo decide (arranque en frío) y que, al
/// salir del perfil, baja la sesión de «actuar por» como la real.
class _GatedAuth extends AuthNotifier {
  _GatedAuth(this.user, {this.gate});

  UserEntity? user;
  final Completer<void>? gate;
  final switchCalls = <String?>[];

  @override
  Future<UserEntity?> build() async {
    if (gate != null) await gate!.future;
    return user;
  }

  @override
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentId, {
    String? firstName,
  }) async {
    switchCalls.add(dependentId);
    if (dependentId == null) {
      ref.read(actingForSessionProvider).exit();
      state = AsyncValue.data(_user());
      return SwitchProfileOutcome.exited;
    }
    return SwitchProfileOutcome.entered;
  }
}

/// Cuenta cuántas veces se lee el detalle de un menor.
class _CountingRepo extends FakeFamilyRepository {
  final detailCalls = <String>[];

  @override
  Future<Either<Failure, DependentDetail>> getDependent(String id) {
    detailCalls.add(id);
    return super.getDependent(id);
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

  Future<
      ({
        ProviderContainer container,
        GoRouter router,
        _GatedAuth auth,
        Completer<void> gate,
        PushNotificationService push,
        _CountingRepo repo,
      })> pumpApp(
    WidgetTester tester,
    UserEntity user, {
    bool coldStart = true,
    ActingForSession? session,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final gate = Completer<void>();
    final auth = _GatedAuth(user, gate: coldStart ? gate : null);
    final repo = _CountingRepo()
      ..overview = Right(
        FamilyOverview(
          dependents: [summary(id: _childId)],
          maxDependents: 10,
        ),
      );
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        familyRepositoryProvider.overrideWithValue(repo),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
    });
    if (!coldStart) await container.read(authNotifierProvider.future);
    final push = PushNotificationService(
      dio: Dio(),
      ref: container.read(Provider<Ref>((ref) => ref)),
      navigatorKey: pushNavigatorKey,
    );
    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);
    return (
      container: container,
      router: router,
      auth: auth,
      gate: gate,
      push: push,
      repo: repo,
    );
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  int stackDepth(GoRouter router) =>
      router.routerDelegate.currentConfiguration.matches.length;

  RemoteMessage tap(Map<String, dynamic> data) => RemoteMessage(data: data);

  const switchDialog = 'Esta notificación es de Ana. ¿Cambiar a su perfil?';

  group('REAL router: guardian taps a family push', () {
    for (final type in [
      'family:security',
      'family:evidence_uploaded',
      'family:age_nudge',
      'dependent_security',
      'dependent_evidence_uploaded',
      'dependent_age_milestone',
    ]) {
      testWidgets('$type from a cold start opens the child detail, no dialog',
          (tester) async {
        final app = await pumpApp(tester, _user());
        expect(location(app.router), RouteNames.splash);

        app.push.handleNotificationTapForTesting(
          tap({'type': type, 'dependent_user_id': _childId}),
        );
        app.gate.complete();
        await _settle(tester);

        expect(location(app.router), RouteNames.familyDetailPath(_childId));
        expect(find.text(switchDialog), findsNothing);
        expect(app.auth.switchCalls, isEmpty,
            reason: 'the guardian manages the child from their own profile');
        expect(app.container.read(pendingNavigationProvider), isNull);
      });
    }

    testWidgets('a warm tap pushes the detail over the current screen',
        (tester) async {
      final app = await pumpApp(tester, _user(), coldStart: false);
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      final before = stackDepth(app.router);

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:age_nudge', 'dependent_user_id': _childId}),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.familyDetailPath(_childId));
      expect(stackDepth(app.router), before + 1);
    });

    testWidgets('a second tap on the SAME detail refreshes, not stacks',
        (tester) async {
      final app = await pumpApp(tester, _user(), coldStart: false);
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:security', 'dependent_user_id': _childId}),
      );
      await _settle(tester);
      final depth = stackDepth(app.router);
      final reads = app.repo.detailCalls.length;

      app.push.handleNotificationTapForTesting(
        tap({
          'type': 'family:evidence_uploaded',
          'dependent_user_id': _childId
        }),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.familyDetailPath(_childId));
      expect(stackDepth(app.router), depth);
      expect(app.repo.detailCalls.length, greaterThan(reads),
          reason: 'the open view must re-read the child, not stay stale');
    });

    testWidgets('a malformed child id lands on the family list',
        (tester) async {
      final app = await pumpApp(tester, _user(), coldStart: false);
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:security', 'dependent_user_id': '../security'}),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.family);
    });

    testWidgets('acting for a child: leaves the child first, then opens it',
        (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: _childId, firstName: 'Ana'));
      final app = await pumpApp(
        tester,
        _user(kind: PrincipalKind.guardianActing),
        coldStart: false,
        session: session,
      );
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      expect(session.isActing, isTrue);

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:age_nudge', 'dependent_user_id': _childId}),
      );
      await _settle(tester);

      expect(app.auth.switchCalls, [null]);
      expect(session.isActing, isFalse);
      expect(location(app.router), RouteNames.familyDetailPath(_childId));
    });

    testWidgets('a non-family push of a child still asks to switch profile',
        (tester) async {
      final app = await pumpApp(tester, _user(), coldStart: false);
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);

      app.push.handleNotificationTapForTesting(
        tap({
          'route': RouteNames.notificationsInbox,
          'dependent_user_id': _childId,
        }),
      );
      await _settle(tester);

      expect(find.text(switchDialog), findsOneWidget);
    });
  });

  group('REAL router: a teen taps a push', () {
    testWidgets('pending teen: reminder from a cold start opens the status',
        (tester) async {
      final app = await pumpApp(
        tester,
        _user(
          kind: PrincipalKind.supervisedUser,
          mode: AccountMode.teenPending,
        ),
      );

      app.push.handleNotificationTapForTesting(
        tap({'type': 'teen_guardian_reminder', 'days_left': '60'}),
      );
      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.teenPendingHome);
      expect(app.container.read(pendingNavigationProvider), isNull);
    });

    testWidgets(
        'pending teen: a child id and a guardian type never open Mi '
        'familia nor ask to switch', (tester) async {
      final app = await pumpApp(
        tester,
        _user(
          kind: PrincipalKind.supervisedUser,
          mode: AccountMode.teenPending,
        ),
      );

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:security', 'dependent_user_id': _childId}),
      );
      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.teenPendingHome);
      expect(find.text(switchDialog), findsNothing);
      expect(app.auth.switchCalls, isEmpty);
    });

    testWidgets('pending teen already on the status screen: no second page',
        (tester) async {
      final app = await pumpApp(
        tester,
        _user(
          kind: PrincipalKind.supervisedUser,
          mode: AccountMode.teenPending,
        ),
        coldStart: false,
      );
      app.router.go(RouteNames.teenPendingHome);
      await _settle(tester);
      final depth = stackDepth(app.router);

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:teen_reminder'}),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.teenPendingHome);
      expect(stackDepth(app.router), depth);
    });

    testWidgets(
        'teen with a guardian: a non-family push with a child id '
        'opens its own destination, no dialog', (tester) async {
      final app = await pumpApp(
        tester,
        _user(
          kind: PrincipalKind.supervisedUser,
          mode: AccountMode.teenSupervised,
        ),
        coldStart: false,
      );
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);

      app.push.handleNotificationTapForTesting(
        tap({
          'route': RouteNames.notificationsInbox,
          'dependent_user_id': _childId,
        }),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.notificationsInbox);
      expect(find.text(switchDialog), findsNothing);
      expect(app.auth.switchCalls, isEmpty);
    });

    testWidgets(
        'teen with a guardian: a guardian-side family push goes to '
        'the notices, never /family', (tester) async {
      final app = await pumpApp(
        tester,
        _user(
          kind: PrincipalKind.supervisedUser,
          mode: AccountMode.teenSupervised,
        ),
        coldStart: false,
      );
      app.router.go(RouteNames.homeDashboard);
      await _settle(tester);

      app.push.handleNotificationTapForTesting(
        tap({'type': 'family:age_nudge', 'dependent_user_id': _childId}),
      );
      await _settle(tester);

      expect(location(app.router), RouteNames.notificationsInbox);
    });
  });
}
