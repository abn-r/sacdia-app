import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../../family/family_test_harness.dart';
import 'auth_notifier_test_support.dart';

UserEntity _me({
  required PrincipalKind kind,
  SupervisionStatus? status,
  String id = 'teen-1',
  bool legalPending = false,
}) =>
    UserEntity(
      id: id,
      email: '$id@example.com',
      postRegisterComplete: true,
      legalAcceptancePending: legalPending,
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
      principal: PrincipalInfo(
        kind: kind,
        supervision: status == null ? null : SupervisionInfo(status: status),
      ),
    );

class _Repo extends FakeAuthRepository {
  _Repo(this.me);

  Either<Failure, UserEntity?> me;
  int meCalls = 0;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    meCalls++;
    return me;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<ProviderContainer> build(_Repo repo,
      {List<Override> extra = const []}) async {
    final container = await buildAuthContainer(
      repo: repo,
      extraOverrides: [
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        ...extra,
      ],
    );
    addTearDown(() {
      container.dispose();
    });
    await container.read(authNotifierProvider.future);
    return container;
  }

  group('refreshSupervision', () {
    test('publishes the new mode when the guardian was verified', () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);
      expect(
        c.read(authNotifierProvider).valueOrNull!.mode,
        AccountMode.teenPending,
      );

      repo.me = Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.active,
      ));
      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isTrue);
      expect(
        c.read(authNotifierProvider).valueOrNull!.mode,
        AccountMode.teenSupervised,
      );
    });

    test('an unchanged answer does not republish (no bootstrap churn)',
        () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);
      final before = c.read(authNotifierProvider).valueOrNull;

      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isFalse);
      expect(
          identical(c.read(authNotifierProvider).valueOrNull, before), isTrue);
    });

    test('an adult never triggers a request', () async {
      final repo = _Repo(Right(_me(kind: PrincipalKind.user, id: 'adult-1')));
      final c = await build(repo);
      final calls = repo.meCalls;

      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isFalse);
      expect(repo.meCalls, calls);
    });

    test('a failure leaves the state alone', () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);

      repo.me = const Left(NetworkFailure(message: 'offline'));
      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isFalse);
      expect(
        c.read(authNotifierProvider).valueOrNull!.mode,
        AccountMode.teenPending,
      );
    });

    test('a response for another account is ignored', () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);

      repo.me = Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.active,
        id: 'someone-else',
      ));
      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isFalse);
      expect(c.read(authNotifierProvider).valueOrNull!.id, 'teen-1');
    });

    test('the minimum interval throttles scope-denied storms', () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);
      final notifier = c.read(authNotifierProvider.notifier);
      final calls = repo.meCalls;

      await notifier.refreshSupervision(
        minInterval: AuthNotifier.scopeDeniedRefreshInterval,
      );
      await notifier.refreshSupervision(
        minInterval: AuthNotifier.scopeDeniedRefreshInterval,
      );
      await notifier.refreshSupervision(
        minInterval: AuthNotifier.scopeDeniedRefreshInterval,
      );

      expect(repo.meCalls - calls, 1);
    });

    test('never runs while acting for a minor', () async {
      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final session = ActingForSession();
      final c = await build(
        repo,
        extra: [actingForSessionProvider.overrideWithValue(session)],
      );
      session.enter(const ActingDependent(userId: 'ana-1'));
      final calls = repo.meCalls;

      final changed =
          await c.read(authNotifierProvider.notifier).refreshSupervision();

      expect(changed, isFalse);
      expect(repo.meCalls, calls);
    });
  });

  group('switchProfile is refused unless the principal is a guardian', () {
    for (final kind in [
      PrincipalKind.supervisedUser,
      PrincipalKind.linkedDevice,
      PrincipalKind.unknown,
    ]) {
      test('$kind never enters the acting mode', () async {
        final repo = _Repo(Right(_me(
          kind: kind,
          status: SupervisionStatus.active,
        )));
        final session = ActingForSession();
        final c = await build(
          repo,
          extra: [actingForSessionProvider.overrideWithValue(session)],
        );
        final calls = repo.meCalls;

        final outcome = await c
            .read(authNotifierProvider.notifier)
            .switchProfile('ana-1', firstName: 'Ana');

        expect(outcome, SwitchProfileOutcome.failed);
        expect(session.isActing, isFalse);
        expect(repo.meCalls, calls, reason: 'no /auth/me with a header');
      });
    }
  });

  group('REAL router: the shell flips without a restart', () {
    testWidgets('pending -> supervised leaves the status screen',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      )));
      final c = await build(repo);
      addTearDown(() => c.read(routerProvider).dispose());
      final router = c.read(routerProvider);
      await pumpLocalizedRouterApp(tester, c, router);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      String where() =>
          router.routerDelegate.currentConfiguration.last.matchedLocation;
      expect(where(), RouteNames.teenPendingHome);

      repo.me = Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.active,
      ));
      await c.read(authNotifierProvider.notifier).refreshSupervision();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(where(), RouteNames.homeDashboard);
    });

    testWidgets('a verified teen whose guardian left drops back to pending',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final repo = _Repo(Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.active,
      )));
      final c = await build(repo);
      addTearDown(() => c.read(routerProvider).dispose());
      final router = c.read(routerProvider);
      await pumpLocalizedRouterApp(tester, c, router);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      String where() =>
          router.routerDelegate.currentConfiguration.last.matchedLocation;
      expect(where(), RouteNames.homeDashboard);

      repo.me = Right(_me(
        kind: PrincipalKind.supervisedUser,
        status: SupervisionStatus.pendingGuardian,
      ));
      await c.read(authNotifierProvider.notifier).refreshSupervision();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(where(), RouteNames.teenPendingHome);
    });
  });
}
