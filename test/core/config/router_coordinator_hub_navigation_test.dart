/// A coordinator WITHOUT a club has the coordination hub as dashboard home (no
/// fifth "Coordinación" tab). Its drill-ins (`/coordinator/...`) live in the
/// coordination shell branch, so they must still open from that home.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_reports_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/sla_dashboard_view.dart';

import '../../features/coordinator/coordinator_test_harness.dart';

const _user = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: [],
    globalGrants: [AuthorizationGrant(roleName: 'coordinator')],
  ),
);

const _scope = CoordinatorScope(
  isCoordinator: true,
  clubSectionIds: [1],
  sections: [CoordinatorSectionScope(clubSectionId: 1, clubTypeId: 1)],
);

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [],
  pipeline: [],
);

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _user;
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  testWidgets(
      'the hub is the home of a coordinator without a club and its drill-ins '
      'open from there', (tester) async {
    useTallSurface(tester);
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        coordinatorScopeProvider.overrideWith((ref) async => _scope),
        slaDashboardProvider.overrideWith((ref) async => _sla),
        pendingEvidenceOverride((type, page) async => singlePage(const [])),
        coordinatorClubsRawProvider.overrideWith((ref) async => const []),
        reportComplianceProvider.overrideWith(
          (ref, query) async => throw StateError('reports not under test'),
        ),
      ],
    );
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });
    await container.read(authNotifierProvider.future);
    await container.read(appBootstrapProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localized((context) => localizedRouterApp(context, router)),
      ),
    );
    router.go(RouteNames.homeDashboard);
    await tester.pumpAndSettle();

    // Home = the hub; no second coordination destination in the shell.
    expect(find.byType(CoordinatorHubView), findsOneWidget);

    // Drill-in from the home.
    unawaited(router.push(RouteNames.coordinatorSla));
    await tester.pumpAndSettle();
    expect(find.byType(SLADashboardView), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      RouteNames.coordinatorSla,
    );

    // Back to the hub (home), not to a different tab.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SLADashboardView), findsNothing);
    expect(find.byType(CoordinatorHubView), findsOneWidget);
  });
}
