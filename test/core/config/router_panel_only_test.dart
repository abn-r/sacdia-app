import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/panel_only_account_view.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

/// Router REAL con una cuenta `panel_only`: siempre termina en su pantalla
/// (también por enlace profundo), el tutor conserva Mi familia, y entrar a un
/// dependiente y salir lo devuelve a la pantalla, no a un inicio de club.

const _guardianFamily = FamilySummary(isGuardian: true, dependentsCount: 1);

UserEntity _panelOnly({FamilySummary? family}) => UserEntity(
      id: 'guardian-1',
      email: 'g@example.com',
      name: 'María',
      postRegisterComplete: false,
      analyticsAnonymous: true,
      onboardingMode: OnboardingMode.panelOnly,
      family: family,
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

UserEntity _dependent() => const UserEntity(
      id: 'ana-1',
      name: 'Ana',
      postRegisterComplete: true,
      analyticsAnonymous: true,
      actingFor: ActingForInfo(
        actorUserId: 'guardian-1',
        dependentUserId: 'ana-1',
      ),
      authorization: AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

UserEntity _clubMember() => const UserEntity(
      id: 'guardian-1',
      email: 'g@example.com',
      name: 'María',
      postRegisterComplete: true,
      analyticsAnonymous: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;

  void emit(UserEntity next) => state = AsyncValue.data(next);
}

class _Ready extends AppBootstrapNotifier {
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

class _PendingCompletion extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() => Completer<CompletionStatus?>().future;
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
        ProviderContainer c,
        _Auth auth,
        ActingForSession session,
        GoRouter router
      })> mount(
    WidgetTester tester,
    UserEntity user,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final auth = _Auth(user);
    final session = ActingForSession();
    final c = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        actingForSessionProvider.overrideWithValue(session),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        completionStatusProvider.overrideWith(_PendingCompletion.new),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
      ],
    );
    addTearDown(() {
      c.read(routerProvider).dispose();
    });
    await c.read(authNotifierProvider.future);
    final router = c.read(routerProvider);
    await pumpLocalizedRouterApp(tester, c, router);
    await _settle(tester);
    return (c: c, auth: auth, session: session, router: router);
  }

  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('panel-only account without dependents', () {
    testWidgets('lands on the panel-only screen from splash', (tester) async {
      final h = await mount(tester, _panelOnly());

      expect(where(h.router), RouteNames.panelOnlyAccount);
      expect(find.byType(PanelOnlyAccountView), findsOneWidget);
    });

    testWidgets('every other route, deep links included, ends on the screen',
        (tester) async {
      final h = await mount(tester, _panelOnly());

      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.postRegistration,
        RouteNames.family,
        RouteNames.familyAdd,
        '/family/ana-1',
        RouteNames.notificationsInbox,
        RouteNames.login,
        RouteNames.splash,
      ]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.panelOnlyAccount, reason: path);
      }
    });

    testWidgets('leaves the screen once the server stops saying panel_only',
        (tester) async {
      final h = await mount(tester, _panelOnly());
      expect(where(h.router), RouteNames.panelOnlyAccount);

      h.auth.emit(_clubMember());
      await _settle(tester);

      expect(where(h.router), RouteNames.homeDashboard);
    });

    testWidgets('a change of mode alone is enough to republish the user',
        (tester) async {
      expect(
        AuthNotifier.authorizationChanged(
          _panelOnly(),
          _panelOnly().withPrincipal(null),
        ),
        isFalse,
      );
      final changed = UserEntity(
        id: 'guardian-1',
        authorization: _panelOnly().authorization,
        onboardingMode: OnboardingMode.clubExempt,
      );
      expect(AuthNotifier.authorizationChanged(_panelOnly(), changed), isTrue);
    });
  });

  group('panel-only guardian', () {
    testWidgets('lands on the screen and keeps Mi familia', (tester) async {
      final h = await mount(tester, _panelOnly(family: _guardianFamily));

      expect(where(h.router), RouteNames.panelOnlyAccount);
      expect(find.byKey(const ValueKey('panel_only_family')), findsOneWidget);

      h.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      expect(where(h.router), RouteNames.panelOnlyAccount);
    });

    testWidgets(
        'entering a dependent follows the dependent flow and leaving brings '
        'the guardian back to the screen, not to a club home', (tester) async {
      final h = await mount(tester, _panelOnly(family: _guardianFamily));
      expect(where(h.router), RouteNames.panelOnlyAccount);

      // Entrar: la sesión pasa a ser la del dependiente (modo `club`).
      h.session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      h.auth.emit(_dependent());
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);

      // Mi familia sigue cerrada mientras se actúa, y la pantalla de solo
      // panel no es del menor.
      h.router.go(RouteNames.family);
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
      h.router.go(RouteNames.panelOnlyAccount);
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);

      // Salir: vuelve el tutor y el router lo lleva a la pantalla.
      h.session.exit();
      h.auth.emit(_panelOnly(family: _guardianFamily));
      await _settle(tester);
      expect(where(h.router), RouteNames.panelOnlyAccount);
    });
  });
}
