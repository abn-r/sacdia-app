import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_judge_assignment.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/quick_access_grid.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _StaticUnitsNotifier extends UnitsNotifier {
  _StaticUnitsNotifier(this.initial);

  final UnitsState initial;

  @override
  UnitsState build() => initial;
}

Unit _unit({
  int id = 1,
  int sectionId = 2,
  String? captainId,
  String? secretaryId,
  String? advisorId,
  String? substituteAdvisorId,
}) {
  return Unit(
    id: id,
    name: 'Centinelas',
    type: 'Guias Mayores',
    memberCount: 3,
    clubSectionId: sectionId,
    captainId: captainId,
    secretaryId: secretaryId,
    advisorId: advisorId,
    substituteAdvisorId: substituteAdvisorId,
  );
}

UserEntity _userWithPermissions(
  List<String> permissions, {
  String roleName = 'counselor',
}) {
  const activeAssignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: activeAssignmentId,
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: activeAssignmentId,
          roleName: roleName,
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
  UserEntity user, {
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        camporeeJudgeAssignmentsProvider.overrideWith((ref) async => const []),
        ...extraOverrides,
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
      'shows camporees shortcut when the user can read camporees',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'camporees:read',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(find.text('dashboard.quick_access.camporees'), findsOne);
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

    testWidgets(
      'shows camporee judge shortcut when the user has a primary assignment',
      (tester) async {
        final user = _userWithPermissions(const ['camporees:read']);

        await _pumpQuickAccessGrid(
          tester,
          user,
          extraOverrides: [
            camporeeJudgeAssignmentsProvider.overrideWith(
              (ref) async => const [
                CamporeeJudgeAssignment(
                  assignmentId: 'asg-1',
                  eventId: 9,
                  judgeId: 'judge-1',
                  clubSectionId: 2,
                  judgeRole: 'primary',
                  active: true,
                  canSubmitScore: true,
                ),
              ],
            ),
          ],
        );

        expect(find.text('dashboard.quick_access.camporee_judge'), findsOne);
      },
    );

    testWidgets(
      'shortcut tiles use SacCard press, not Material InkWell',
      (tester) async {
        final user = _userWithPermissions(
          const [
            'users:read_detail',
            'clubs:update',
          ],
        );

        await _pumpQuickAccessGrid(tester, user);

        expect(
          find.descendant(
            of: find.byType(QuickAccessGrid),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(QuickAccessGrid),
            matching: find.byType(SacCard),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'hides camporee judge shortcut when assignments are empty',
      (tester) async {
        final user = _userWithPermissions(const ['camporees:read']);

        await _pumpQuickAccessGrid(tester, user);

        expect(
            find.text('dashboard.quick_access.camporee_judge'), findsNothing);
      },
    );

    for (final role in ['director', 'secretary', 'secretary-treasurer']) {
      testWidgets('shows the investiture shortcut to $role', (tester) async {
        await _pumpQuickAccessGrid(
          tester,
          _userWithPermissions(const ['reports:read'], roleName: role),
        );
        expect(find.text('dashboard.quick_access.investiture'), findsOne);
      });
    }

    for (final role in ['counselor', 'deputy-director', 'treasurer']) {
      testWidgets('hides the investiture shortcut from $role', (tester) async {
        await _pumpQuickAccessGrid(
          tester,
          _userWithPermissions(const ['reports:read'], roleName: role),
        );
        expect(find.text('dashboard.quick_access.investiture'), findsNothing);
      });
    }
  });

  group('QuickAccessGrid authorizer shortcut', () {
    UserEntity globalUser(String role) => UserEntity(
          id: 'user-1',
          email: 'user@example.com',
          authorization: AuthorizationSnapshot(
            effectivePermissions: const ['reports:read'],
            globalGrants: [AuthorizationGrant(roleName: role)],
          ),
        );

    for (final role in ['pastor', 'director-lf', 'assistant-lf']) {
      testWidgets('shows the authorizations shortcut to $role', (tester) async {
        await _pumpQuickAccessGrid(tester, globalUser(role));
        expect(find.text('dashboard.quick_access.authorizations'), findsOne);
      });
    }

    for (final role in ['coordinator', 'director-union']) {
      testWidgets('hides the authorizations shortcut from $role',
          (tester) async {
        await _pumpQuickAccessGrid(tester, globalUser(role));
        expect(
            find.text('dashboard.quick_access.authorizations'), findsNothing);
      });
    }

    // Coordination is now a main-shell tab, so the grid must not duplicate it.
    for (final role in ['coordinator', 'admin', 'director-lf']) {
      testWidgets('does not show a coordination shortcut to $role',
          (tester) async {
        await _pumpQuickAccessGrid(tester, globalUser(role));
        expect(find.text('dashboard.quick_access.coordination'), findsNothing);
      });
    }

    testWidgets('hides both investiture shortcuts from a super-admin only',
        (tester) async {
      await _pumpQuickAccessGrid(tester, globalUser('super-admin'));
      expect(find.text('dashboard.quick_access.authorizations'), findsNothing);
      expect(find.text('dashboard.quick_access.investiture'), findsNothing);
    });

    testWidgets('a super-admin who is also a section director keeps his tile',
        (tester) async {
      await _pumpQuickAccessGrid(
        tester,
        UserEntity(
          id: 'user-1',
          email: 'user@example.com',
          authorization: AuthorizationSnapshot(
            effectivePermissions: const ['reports:read'],
            globalGrants: const [AuthorizationGrant(roleName: 'super-admin')],
            activeAssignmentId: 'a1',
            clubAssignments: const [
              AuthorizationGrant(
                assignmentId: 'a1',
                roleName: 'director',
                clubId: 1,
                sectionId: 2,
                status: 'active',
              ),
            ],
          ),
        ),
      );
      expect(find.text('dashboard.quick_access.investiture'), findsOne);
      expect(find.text('dashboard.quick_access.authorizations'), findsNothing);
    });

    testWidgets('hides it from a plain club counselor', (tester) async {
      await _pumpQuickAccessGrid(
        tester,
        _userWithPermissions(const ['reports:read']),
      );
      expect(find.text('dashboard.quick_access.authorizations'), findsNothing);
    });
  });

  group('QuickAccessGrid units shortcut for unit leaders', () {
    const unitsLabel = 'dashboard.quick_access.units';

    // Un miembro sin `units:update`, solo con lectura de unidades.
    UserEntity member({
      List<String> permissions = const ['units:read'],
      ActingForInfo? actingFor,
      PrincipalInfo? principal,
    }) {
      final base = _userWithPermissions(permissions, roleName: 'member');
      return UserEntity(
        id: base.id,
        email: base.email,
        authorization: base.authorization,
        actingFor: actingFor,
        principal: principal,
      );
    }

    Future<void> pump(
      WidgetTester tester,
      UserEntity user,
      UnitsState units,
    ) {
      return _pumpQuickAccessGrid(
        tester,
        user,
        extraOverrides: [
          unitsNotifierProvider.overrideWith(() => _StaticUnitsNotifier(units)),
        ],
      );
    }

    for (final (label, led) in <(String, Unit)>[
      ('captain', _unit(captainId: 'user-1')),
      ('secretary', _unit(secretaryId: 'user-1')),
      ('advisor', _unit(advisorId: 'user-1')),
      ('substitute advisor', _unit(substituteAdvisorId: 'user-1')),
    ]) {
      testWidgets('shows the tile to a member who is the unit $label',
          (tester) async {
        await pump(tester, member(), UnitsState(units: [led]));
        expect(find.text(unitsLabel), findsOne);
      });
    }

    testWidgets('hides the tile from a plain member who leads no unit',
        (tester) async {
      await pump(
        tester,
        member(),
        UnitsState(units: [_unit(captainId: 'someone-else')]),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets('hides the tile when the led unit is in another section',
        (tester) async {
      await pump(
        tester,
        member(),
        UnitsState(units: [_unit(sectionId: 99, captainId: 'user-1')]),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets('hides the tile while the units are loading', (tester) async {
      await pump(
        tester,
        member(),
        UnitsState(
          units: [_unit(captainId: 'user-1')],
          isLoading: true,
        ),
      );
      expect(find.text(unitsLabel), findsNothing);
      // The rest of the grid is not broken.
      expect(find.byType(QuickAccessGrid), findsOne);
    });

    testWidgets('hides the tile when the units failed to load', (tester) async {
      await pump(
        tester,
        member(),
        const UnitsState(units: [], errorMessage: 'boom'),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets('does not show it without units:read even if leader',
        (tester) async {
      await pump(
        tester,
        member(permissions: const ['reports:read']),
        UnitsState(units: [_unit(captainId: 'user-1')]),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets('does not show it while acting for a minor', (tester) async {
      await pump(
        tester,
        member(
          actingFor: const ActingForInfo(
            actorUserId: 'guardian-1',
            dependentUserId: 'user-1',
          ),
        ),
        UnitsState(units: [_unit(captainId: 'user-1')]),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets('does not show it to a pending (restricted) teen',
        (tester) async {
      await pump(
        tester,
        member(
          principal: const PrincipalInfo(kind: PrincipalKind.supervisedUser),
        ),
        UnitsState(units: [_unit(captainId: 'user-1')]),
      );
      expect(find.text(unitsLabel), findsNothing);
    });

    testWidgets(
        'shows it to a supervised teen with a guardian who leads a unit',
        (tester) async {
      // The backend lets supervised teen leaders write weekly records
      // (member:write).
      await pump(
        tester,
        member(
          principal: const PrincipalInfo(
            kind: PrincipalKind.supervisedUser,
            supervision: SupervisionInfo(status: SupervisionStatus.active),
          ),
        ),
        UnitsState(units: [_unit(captainId: 'user-1')]),
      );
      expect(find.text(unitsLabel), findsOne);
    });

    testWidgets('director with units:update keeps the tile as before',
        (tester) async {
      await pump(
        tester,
        _userWithPermissions(
          const ['units:read', 'units:update', 'units:create'],
          roleName: 'director',
        ),
        const UnitsState(units: []),
      );
      expect(find.text(unitsLabel), findsOne);
    });

    testWidgets('units:update alone (no leadership) still opens the tile',
        (tester) async {
      await pump(
        tester,
        _userWithPermissions(const ['units:update']),
        const UnitsState(units: []),
      );
      expect(find.text(unitsLabel), findsOne);
    });
  });
}
