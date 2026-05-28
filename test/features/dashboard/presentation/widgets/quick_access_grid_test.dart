import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/quick_access_grid.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _userWithPermissions(List<String> permissions) {
  const activeAssignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: activeAssignmentId,
      clubAssignments: const [
        AuthorizationGrant(
          assignmentId: activeAssignmentId,
          roleName: 'counselor',
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pumpQuickAccessGrid(
  WidgetTester tester,
  UserEntity user,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuickAccessGrid(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QuickAccessGrid shortcuts', () {
    testWidgets(
      'shows reports shortcut when the user can read reports',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'reports:read',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(find.text('dashboard.quick_access.reports'), findsOne);
      },
    );

    testWidgets(
      'shows institutional club rankings shortcut when the user can read rankings',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'rankings:read',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(find.text('dashboard.quick_access.club_rankings'), findsOne);
      },
    );

    testWidgets(
      'does not expose legacy personal or section rankings from dashboard',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'member_rankings:read_self',
            'section_rankings:read_club',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(
          find.text('dashboard.quick_access.section_ranking'),
          findsNothing,
        );
        expect(find.text('dashboard.quick_access.my_ranking'), findsNothing);
      },
    );

    testWidgets(
      'does not expose personal ranking even when read_self is granted',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'member_rankings:read_self',
            'units:update',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(
          find.text('dashboard.quick_access.section_ranking'),
          findsNothing,
        );
        expect(find.text('dashboard.quick_access.my_ranking'), findsNothing);
      },
    );
  });
}
