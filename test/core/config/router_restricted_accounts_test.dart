import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/restricted_account_view.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/teen/domain/entities/teen_supervision.dart';
import 'package:sacdia_app/features/teen/domain/repositories/teen_repository.dart';
import 'package:sacdia_app/features/teen/presentation/providers/teen_providers.dart';
import 'package:sacdia_app/features/teen/presentation/views/teen_pending_home_view.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_test_harness.dart';

/// Cuenta sin fecha de nacimiento (alta nueva con Google/Apple) y cuenta con un
/// principal que la app no conoce: ambas fallan cerrado en el router REAL.

const _ageUnknown = PrincipalInfo(
  kind: PrincipalKind.ageUnknownUser,
  scopes: ['account:manage', 'profile:write'],
);

UserEntity _user({
  required PrincipalInfo principal,
  AccountMode? mode,
  bool postRegisterComplete = false,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      name: 'Ana',
      postRegisterComplete: postRegisterComplete,
      principal: principal,
      serverMode: mode,
      analyticsAnonymous: true,
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

UserEntity _unknownBirthday({bool postRegisterComplete = false}) => _user(
      principal: _ageUnknown,
      mode: AccountMode.profileIncomplete,
      postRegisterComplete: postRegisterComplete,
    );

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity user;
  int signOuts = 0;

  @override
  Future<UserEntity?> build() async => user;

  /// Simula el `/auth/me` siguiente.
  void emit(UserEntity next) => state = AsyncValue.data(next);

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
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

/// El post-registro real queda cargando: no toca la red.
class _PendingCompletion extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() => Completer<CompletionStatus?>().future;
}

class _TeenRepo implements TeenRepository {
  @override
  Future<Either<Failure, TeenSupervision>> getSupervision() async =>
      const Right(TeenSupervision(status: SupervisionStatus.pendingGuardian));

  @override
  Future<Either<Failure, TeenLinkCode>> issueLinkCode() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> revokePendingLink(String id) =>
      throw UnimplementedError();
}

class _CountingNotifications extends FakeNotificationsRepository {
  int unreadCalls = 0;

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    unreadCalls++;
    return const Right(0);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<({ProviderContainer c, _Auth auth, dynamic router})> mount(
    WidgetTester tester,
    UserEntity user, {
    NotificationsRepository? notifications,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final auth = _Auth(user);
    final c = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        teenRepositoryProvider.overrideWithValue(_TeenRepo()),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        completionStatusProvider.overrideWith(_PendingCompletion.new),
        notificationsRepositoryProvider.overrideWithValue(
          notifications ?? FakeNotificationsRepository(),
        ),
      ],
    );
    addTearDown(() {
      c.read(routerProvider).dispose();
      c.dispose();
    });
    await c.read(authNotifierProvider.future);
    final router = c.read(routerProvider);
    await pumpLocalizedRouterApp(tester, c, router);
    await _settle(tester);
    return (c: c, auth: auth, router: router);
  }

  String where(dynamic router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation as String;

  group('no birthday (age_unknown_user / profile_incomplete)', () {
    testWidgets('lands in post-registration and cannot leave it',
        (tester) async {
      final h = await mount(tester, _unknownBirthday());

      expect(where(h.router), RouteNames.postRegistration);

      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.teenPendingHome,
        RouteNames.notificationsInbox,
      ]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.postRegistration, reason: path);
      }
    });

    testWidgets(
        'a stale local "post-registration done" flag does not free the account',
        (tester) async {
      final h = await mount(
        tester,
        _unknownBirthday(postRegisterComplete: true),
      );

      expect(where(h.router), RouteNames.postRegistration);
      h.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      expect(where(h.router), RouteNames.postRegistration);
    });

    testWidgets(
        'a minor, once /auth/me says teen_pending, lands on the '
        'pending-teen screen', (tester) async {
      final h = await mount(tester, _unknownBirthday());
      expect(where(h.router), RouteNames.postRegistration);

      // Paso 2 guardó una fecha de menor y el cliente volvió a pedir /auth/me;
      // el paso 3 terminó y marcó el post-registro como completo.
      h.auth.emit(_user(
        principal: const PrincipalInfo(
          kind: PrincipalKind.supervisedUser,
          supervision: SupervisionInfo(
            status: SupervisionStatus.pendingGuardian,
          ),
        ),
        mode: AccountMode.teenPending,
        postRegisterComplete: true,
      ));
      await _settle(tester);

      expect(where(h.router), RouteNames.teenPendingHome);
      expect(find.byType(TeenPendingHomeView), findsOneWidget);
    });

    testWidgets(
        'an adult, once /auth/me says adult, keeps post-registration '
        'while it is open and then goes home', (tester) async {
      final h = await mount(tester, _unknownBirthday());

      h.auth.emit(_user(
        principal: const PrincipalInfo(kind: PrincipalKind.user),
        mode: AccountMode.adult,
      ));
      await _settle(tester);
      expect(where(h.router), RouteNames.postRegistration);

      h.auth.emit(_user(
        principal: const PrincipalInfo(kind: PrincipalKind.user),
        mode: AccountMode.adult,
        postRegisterComplete: true,
      ));
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
    });

    testWidgets('does not ask for the unread count (it would 403)',
        (tester) async {
      final notifications = _CountingNotifications();
      final h = await mount(
        tester,
        _unknownBirthday(),
        notifications: notifications,
      );

      await h.c.read(unreadNotificationsCountProvider.notifier).refresh();

      expect(notifications.unreadCalls, 0);
    });
  });

  group('unknown principal kind', () {
    UserEntity unknownKind() => _user(
          principal: const PrincipalInfo(kind: PrincipalKind.unknown),
          postRegisterComplete: true,
        );

    testWidgets('is restricted: info screen only, never the adult home',
        (tester) async {
      final h = await mount(tester, unknownKind());

      expect(where(h.router), RouteNames.restrictedAccount);
      expect(find.byType(RestrictedAccountView), findsOneWidget);

      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.family,
        RouteNames.postRegistration,
        RouteNames.teenPendingHome,
      ]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.restrictedAccount, reason: path);
      }
    });

    testWidgets('can sign out from the info screen', (tester) async {
      final h = await mount(tester, unknownKind());

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();

      expect(h.auth.signOuts, 1);
    });

    testWidgets('is anonymous in analytics and counts as a limited account',
        (tester) async {
      final user = unknownKind();
      expect(user.canIdentifyInAnalytics, isFalse);
      expect(user.mode, AccountMode.restricted);
      expect(user.isLimitedAccount, isTrue);
    });
  });
}
