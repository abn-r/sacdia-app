import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/authorizer_requests_view.dart';

import '../../../investiture_requests/fake_investiture_requests_repository.dart';
import '../../../investiture_requests/presentation/authorizer_test_support.dart';
import '../../../investiture_requests/presentation/investiture_test_harness.dart';

/// Resuelve el usuario en el primer frame (como en la app real, donde el
/// router espera a la sesión antes de mostrar el inicio).
class _SyncAuthNotifier extends AuthNotifier {
  _SyncAuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() => SynchronousFuture(user);
}

class _CountingDashboardNotifier extends DashboardNotifier {
  _CountingDashboardNotifier(this.onBuild);

  final void Function() onBuild;

  @override
  Future<DashboardSummary?> build() async {
    onBuild();
    return null;
  }
}

UserEntity _user({required String role, bool withClub = false}) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        globalGrants: [AuthorizationGrant(roleName: role)],
        activeAssignmentId: withClub ? 'a1' : null,
        clubAssignments: withClub
            ? const [
                AuthorizationGrant(
                  assignmentId: 'a1',
                  roleName: 'counselor',
                  clubId: 1,
                  sectionId: 4,
                  status: 'active',
                ),
              ]
            : const [],
      ),
    );

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('a pastor without a club lands on the authorizations only',
      (tester) async {
    var dashboardBuilds = 0;
    final repo = FakeInvestitureRequestsRepository()
      ..authorizerRequests = [authorizerRequest()];

    await pumpApp(
      tester,
      const DashboardView(),
      overrides: [
        ...authorizerOverrides(repo),
        authNotifierProvider
            .overrideWith(() => _SyncAuthNotifier(_user(role: 'pastor'))),
        dashboardNotifierProvider.overrideWith(
          () => _CountingDashboardNotifier(() => dashboardBuilds++),
        ),
      ],
    );

    expect(find.byType(AuthorizerRequestsView), findsOneWidget);
    expect(find.text('Autorizaciones'), findsOneWidget);
    expect(find.text('Club Alfa'), findsOneWidget);
    // Nada del inicio de un miembro: ni acceso rápido ni resumen del club.
    expect(find.text('Acceso rápido'), findsNothing);
    expect(dashboardBuilds, 0);
  });

  testWidgets('a pastor who belongs to a club keeps the regular dashboard',
      (tester) async {
    var dashboardBuilds = 0;
    await pumpApp(
      tester,
      const DashboardView(),
      overrides: [
        ...authorizerOverrides(FakeInvestitureRequestsRepository()),
        authNotifierProvider.overrideWith(
          () => _SyncAuthNotifier(_user(role: 'pastor', withClub: true)),
        ),
        dashboardNotifierProvider.overrideWith(
          () => _CountingDashboardNotifier(() => dashboardBuilds++),
        ),
      ],
    );

    expect(find.byType(AuthorizerRequestsView), findsNothing);
    expect(dashboardBuilds, 1);
  });
}
