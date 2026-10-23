import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';

class _NullDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

const _guardianNoClub = UserEntity(
  id: 'guardian-1',
  email: 'maria@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(),
  family: FamilySummary(isGuardian: true, dependentsCount: 1),
);

const _plainNoClub = UserEntity(
  id: 'user-2',
  email: 'pedro@example.com',
  authorization: AuthorizationSnapshot(),
);

class _AuthNotifier extends AuthNotifier {
  _AuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

Future<GoRouter> _pump(WidgetTester tester, UserEntity user) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardView()),
      GoRoute(
        path: RouteNames.family,
        builder: (_, __) => const Scaffold(body: Text('family-screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardNotifierProvider.overrideWith(_NullDashboardNotifier.new),
        authNotifierProvider.overrideWith(() => _AuthNotifier(user)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('DashboardView for a guardian without a club', () {
    testWidgets('shows the dedicated empty state instead of the load error',
        (tester) async {
      await _pump(tester, _guardianNoClub);

      expect(find.text('dashboard.guardian_no_club.title'), findsOneWidget);
      expect(find.text('dashboard.guardian_no_club.subtitle'), findsOneWidget);
      expect(
        find.text('dashboard.guardian_no_club.family_action'),
        findsOneWidget,
      );
      expect(find.text('dashboard.load_null_error'), findsNothing);
    });

    testWidgets('the primary CTA opens Mi familia', (tester) async {
      await _pump(tester, _guardianNoClub);

      await tester.tap(find.text('dashboard.guardian_no_club.family_action'));
      await tester.pumpAndSettle();

      expect(find.text('family-screen'), findsOneWidget);
    });

    testWidgets('a clubless user who is not a guardian keeps the load error',
        (tester) async {
      await _pump(tester, _plainNoClub);

      expect(find.text('dashboard.load_null_error'), findsOneWidget);
      expect(find.text('dashboard.guardian_no_club.title'), findsNothing);
    });
  });

  group('isGuardianWithoutClub', () {
    const club = AuthorizationGrant(
      assignmentId: 'a-1',
      status: 'active',
      roleName: 'member',
      clubId: 1,
      sectionId: 2,
    );

    test('is true for a guardian with no club assignment', () {
      expect(isGuardianWithoutClub(_guardianNoClub), isTrue);
    });

    test('is true with dependents even if the flag is missing', () {
      const user = UserEntity(
        id: 'g',
        authorization: AuthorizationSnapshot(),
        family: FamilySummary(isGuardian: false, dependentsCount: 2),
      );
      expect(isGuardianWithoutClub(user), isTrue);
    });

    test('is false when the guardian also belongs to a club', () {
      const user = UserEntity(
        id: 'g',
        postRegisterComplete: true,
        authorization: AuthorizationSnapshot(clubAssignments: [club]),
        family: FamilySummary(isGuardian: true, dependentsCount: 1),
      );
      expect(isGuardianWithoutClub(user), isFalse);
    });

    test('is false while acting for a dependent and for null', () {
      const acting = UserEntity(
        id: 'ana',
        authorization: AuthorizationSnapshot(),
        postRegisterComplete: true,
        actingFor: ActingForInfo(actorUserId: 'g', dependentUserId: 'ana'),
      );
      expect(isGuardianWithoutClub(acting), isFalse);
      expect(isGuardianWithoutClub(null), isFalse);
    });

    test('is false for a clubless user who is not a guardian', () {
      expect(isGuardianWithoutClub(_plainNoClub), isFalse);
    });
  });
}
