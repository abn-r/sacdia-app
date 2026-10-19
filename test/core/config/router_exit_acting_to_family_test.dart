import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/family/presentation/views/family_view.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../features/family/family_test_harness.dart';

/// Sale de "actuar por" como el AuthNotifier real: la sesión sale, el estado
/// pasa a carga y `/auth/me` del tutor se vuelve a pedir DESPUÉS de que
/// `switchProfile` ya devolvió.
class _ExitingAuth extends AuthNotifier {
  _ExitingAuth(this.session, this.guardian, this.minor);

  final ActingForSession session;
  final UserEntity guardian;
  final UserEntity minor;
  final reload = Completer<void>();

  @override
  Future<UserEntity?> build() async {
    if (!session.isActing) await reload.future;
    return session.isActing ? minor : guardian;
  }

  @override
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentId, {
    String? firstName,
  }) async {
    if (dependentId != null) return SwitchProfileOutcome.entered;
    if (!session.isActing) return SwitchProfileOutcome.unchanged;
    session.exit();
    state = const AsyncLoading();
    ref.invalidateSelf();
    return SwitchProfileOutcome.exited;
  }
}

class _NullDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

const _guardian = UserEntity(
  id: 'guardian-1',
  email: 'maria@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(),
);

const _pendingMinor = UserEntity(
  id: 'ana-1',
  email: 'ana@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'pending-1',
        status: 'pending',
        roleName: 'member',
        clubId: 1,
        sectionId: 2,
      ),
    ],
  ),
);

/// El shell real tiene animaciones continuas: `pumpAndSettle` no termina.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  testWidgets(
      'the pending home CTA ends on Mi familia through the REAL router redirect',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    final auth = _ExitingAuth(session, _guardian, _pendingMinor);

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        actingForSessionProvider.overrideWithValue(session),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    await container.read(authNotifierProvider.future);

    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);
    router.go(RouteNames.homeDashboard);
    await _settle(tester);

    expect(find.text('Ir a Mi familia'), findsOneWidget);

    await tester.tap(find.text('Ir a Mi familia'));
    await tester.pump();
    // `/auth/me` del tutor responde un poco después de que el switch terminó.
    await tester.pump(const Duration(milliseconds: 50));
    auth.reload.complete();
    await _settle(tester);

    expect(session.isActing, isFalse);
    expect(find.byType(FamilyView), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      RouteNames.family,
    );
  });
}
