import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

class _NullDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async {
    return const UserEntity(
      id: 'user-1',
      email: 'ana@example.com',
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
  }
}

class _NullProfileNotifier extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _CountingProfileNotifier extends ProfileNotifier {
  _CountingProfileNotifier(this.onBuild);

  final void Function() onBuild;

  @override
  Future<UserDetail?> build() async {
    onBuild();
    return null;
  }
}

void main() {
  testWidgets(
    'shows pending membership state instead of dashboard load error',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardNotifierProvider.overrideWith(_NullDashboardNotifier.new),
            authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
            profileNotifierProvider.overrideWith(_NullProfileNotifier.new),
          ],
          child: const MaterialApp(
            home: DashboardView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('dashboard.pending_state.title'), findsOneWidget);
      expect(find.text('dashboard.pending_state.body'), findsOneWidget);
      expect(
          find.text('dashboard.pending_state.profile_action'), findsOneWidget);
      expect(find.text('dashboard.load_null_error'), findsNothing);
    },
  );

  testWidgets(
    'does not load profile just to render pending membership state',
    (tester) async {
      var profileBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardNotifierProvider.overrideWith(_NullDashboardNotifier.new),
            authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
            profileNotifierProvider.overrideWith(
              () => _CountingProfileNotifier(() => profileBuilds++),
            ),
          ],
          child: const MaterialApp(
            home: DashboardView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(profileBuilds, 0);
    },
  );
}
