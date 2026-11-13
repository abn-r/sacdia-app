import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/adult_claim_view.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/release_frozen_view.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/release_view.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

/// Router REAL con la compuerta de liberación (Fase 4): matriz por modo, la
/// compuerta va antes que la legal y `/adult-claim` es pública.

UserEntity _user({
  required PrincipalInfo principal,
  AccountMode? mode,
  bool legalPending = false,
  bool postRegisterComplete = true,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      name: 'Ana',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      principal: principal,
      serverMode: mode,
      analyticsAnonymous: true,
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

UserEntity _released({bool frozen = false, bool legalPending = false}) => _user(
      principal: PrincipalInfo(
        kind: PrincipalKind.releasedUser,
        release: ReleaseInfo(
          status: frozen ? ReleaseStatus.frozen : ReleaseStatus.pending,
          needsEmail: true,
        ),
      ),
      mode: AccountMode.released,
      legalPending: legalPending,
    );

UserEntity _adult() => _user(
      principal: const PrincipalInfo(kind: PrincipalKind.user),
      mode: AccountMode.adult,
    );

class _Auth extends AuthNotifier {
  _Auth(this.user);

  UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;

  void emit(UserEntity? next) => state = AsyncValue.data(next);

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

class _PendingCompletion extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() => Completer<CompletionStatus?>().future;
}

const _legal = LegalStatus(
  requiresAcceptance: true,
  documents: [
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.terms,
      version: '2.0.0-family',
      url: 'https://example.com/terms',
      accepted: false,
    ),
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.privacy,
      version: '2.0.0-family',
      url: 'https://example.com/privacy',
      accepted: false,
    ),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<({_Auth auth, dynamic router})> mount(
    WidgetTester tester,
    UserEntity? user,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final auth = _Auth(user);
    final c = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        completionStatusProvider.overrideWith(_PendingCompletion.new),
        myLegalStatusProvider.overrideWith((ref) async => _legal),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
      ],
    );
    addTearDown(() => c.read(routerProvider).dispose());
    await c.read(authNotifierProvider.future);
    final router = c.read(routerProvider);
    await pumpLocalizedRouterApp(tester, c, router);
    await _settle(tester);
    return (auth: auth, router: router);
  }

  String where(dynamic router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation as String;

  group('released:pending', () {
    testWidgets('lands on /release and cannot leave it', (tester) async {
      final h = await mount(tester, _released());
      expect(where(h.router), RouteNames.release);
      expect(find.byType(ReleaseView), findsOneWidget);

      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.family,
        RouteNames.familyReleased,
        RouteNames.notificationsInbox,
        RouteNames.postRegistration,
        RouteNames.teenPendingHome,
        RouteNames.releaseFrozen,
        RouteNames.adultClaim,
        RouteNames.login,
      ]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.release, reason: path);
      }
    });

    testWidgets('the release gate runs before the legal gate', (tester) async {
      // /auth/me.legal.requires_acceptance is true for a released person until
      // they accept the release documents: the generic gate must not grab them.
      final h = await mount(tester, _released(legalPending: true));
      expect(where(h.router), RouteNames.release);
      h.router.go(RouteNames.legalAcceptance);
      await _settle(tester);
      expect(where(h.router), RouteNames.release);
    });

    testWidgets('access-denied is reachable (screen-catalog guard is last)',
        (tester) async {
      final h = await mount(tester, _released());
      h.router.go(RouteNames.accessDenied);
      await _settle(tester);
      expect(where(h.router), RouteNames.accessDenied);
    });

    testWidgets('completion (server says adult) leaves /release for home',
        (tester) async {
      final h = await mount(tester, _released());
      expect(where(h.router), RouteNames.release);

      h.auth.emit(_adult());
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);

      // No loop: an adult never sees the release screens again.
      h.router.go(RouteNames.release);
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
      h.router.go(RouteNames.releaseFrozen);
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
    });
  });

  group('released:frozen (never deleted: R6)', () {
    testWidgets('lands on /release/frozen; /release stays open for the thaw',
        (tester) async {
      final h = await mount(tester, _released(frozen: true));
      expect(where(h.router), RouteNames.releaseFrozen);
      expect(find.byType(ReleaseFrozenView), findsOneWidget);

      h.router.go(RouteNames.release);
      await _settle(tester);
      expect(where(h.router), RouteNames.release);
      expect(find.byType(ReleaseView), findsOneWidget);

      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.family,
        RouteNames.legalAcceptance,
        RouteNames.adultClaim,
      ]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.releaseFrozen, reason: path);
      }
    });

    testWidgets('pending -> frozen -> pending follows /auth/me',
        (tester) async {
      final h = await mount(tester, _released());
      expect(where(h.router), RouteNames.release);
      h.auth.emit(_released(frozen: true));
      await _settle(tester);
      // /release is allowed for the frozen too: no forced hop while on it.
      expect(where(h.router), RouteNames.release);
      h.router.go(RouteNames.homeDashboard);
      await _settle(tester);
      expect(where(h.router), RouteNames.releaseFrozen);
    });

    testWidgets('thaw: accepted + email => adult => home', (tester) async {
      final h = await mount(tester, _released(frozen: true));
      h.auth.emit(_adult());
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
    });
  });

  group('everyone else', () {
    testWidgets('an adult never reaches the release screens', (tester) async {
      final h = await mount(tester, _adult());
      for (final path in [RouteNames.release, RouteNames.releaseFrozen]) {
        h.router.go(path);
        await _settle(tester);
        expect(where(h.router), RouteNames.homeDashboard, reason: path);
      }
    });

    testWidgets('a supervised teen never reaches them either', (tester) async {
      final h = await mount(
        tester,
        _user(
          principal: const PrincipalInfo(
            kind: PrincipalKind.supervisedUser,
            supervision:
                SupervisionInfo(status: SupervisionStatus.pendingGuardian),
          ),
          mode: AccountMode.teenPending,
        ),
      );
      h.router.go(RouteNames.release);
      await _settle(tester);
      expect(where(h.router), RouteNames.teenPendingHome);
    });

    testWidgets('/adult-claim is public: no session needed', (tester) async {
      final h = await mount(tester, null);
      h.router.go(RouteNames.adultClaim);
      await _settle(tester);
      expect(where(h.router), RouteNames.adultClaim);
      expect(find.byType(AdultClaimView), findsOneWidget);
    });

    testWidgets('/release needs a session: logged out goes to login',
        (tester) async {
      final h = await mount(tester, null);
      h.router.go(RouteNames.release);
      await _settle(tester);
      expect(where(h.router), isNot(RouteNames.release));
    });

    testWidgets('a signed-in adult on /adult-claim goes home', (tester) async {
      final h = await mount(tester, _adult());
      h.router.go(RouteNames.adultClaim);
      await _settle(tester);
      expect(where(h.router), RouteNames.homeDashboard);
    });
  });
}
