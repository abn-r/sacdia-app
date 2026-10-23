import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';

class _NullDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _AuthNotifier extends AuthNotifier {
  _AuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 6, avgDays: 0, overdue: 2),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [],
  pipeline: [],
);

const _coordinatorNoClub = UserEntity(
  id: 'coord-1',
  email: 'coord@example.com',
  name: 'Carlos',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    globalGrants: [AuthorizationGrant(roleName: 'coordinator')],
  ),
);

// Coordinador que además es tutor: el inicio sigue siendo la coordinación.
const _coordinatorGuardianNoClub = UserEntity(
  id: 'coord-2',
  email: 'coord2@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    globalGrants: [AuthorizationGrant(roleName: 'zone-coordinator')],
  ),
  family: FamilySummary(isGuardian: true, dependentsCount: 2),
);

const _coordinatorWithClub = UserEntity(
  id: 'coord-3',
  email: 'coord3@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    globalGrants: [AuthorizationGrant(roleName: 'coordinator')],
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'a-1',
        status: 'active',
        roleName: 'counselor',
        clubId: 1,
        sectionId: 2,
      ),
    ],
  ),
);

Future<void> _pump(WidgetTester tester, UserEntity user) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardView()),
      GoRoute(
        path: RouteNames.notificationsInbox,
        builder: (_, __) => const Scaffold(body: Text('inbox-screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardNotifierProvider.overrideWith(_NullDashboardNotifier.new),
        authNotifierProvider.overrideWith(() => _AuthNotifier(user)),
        slaDashboardProvider.overrideWith((ref) async => _sla),
        coordinatorScopeProvider.overrideWith(
          (ref) async => const CoordinatorScope(
            isCoordinator: true,
            clubSectionIds: [2],
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DashboardView for a coordinator without a club', () {
    testWidgets('renders the coordination hub, not the load error',
        (tester) async {
      await _pump(tester, _coordinatorNoClub);

      expect(find.byType(CoordinatorHubView), findsOneWidget);
      expect(find.text('coordinator.hub.title'), findsOneWidget);
      expect(find.text('dashboard.load_null_error'), findsNothing);
      expect(find.text('dashboard.guardian_no_club.title'), findsNothing);
    });

    testWidgets('a coordinator who is also a guardian gets the hub too',
        (tester) async {
      await _pump(tester, _coordinatorGuardianNoClub);

      expect(find.byType(CoordinatorHubView), findsOneWidget);
      expect(find.text('dashboard.guardian_no_club.title'), findsNothing);
    });

    testWidgets('the hub offers the notifications inbox as its home',
        (tester) async {
      await _pump(tester, _coordinatorNoClub);

      await tester.tap(find.byTooltip('dashboard.notifications_tooltip'));
      await tester.pumpAndSettle();

      expect(find.text('inbox-screen'), findsOneWidget);
    });

    testWidgets('a coordinator with a club keeps the club dashboard path',
        (tester) async {
      await _pump(tester, _coordinatorWithClub);

      expect(find.byType(CoordinatorHubView), findsNothing);
      expect(find.text('dashboard.load_null_error'), findsOneWidget);
    });
  });
}
