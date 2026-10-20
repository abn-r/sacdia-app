import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/utils/consent_access.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

import '../../members_test_support.dart';

UserEntity _user(
  List<String> permissions, {
  List<AuthorizationGrant> globalGrants = const [],
  List<String> activeRolePermissions = const [],
}) =>
    UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: permissions,
        activeAssignmentId: 'asg-1',
        globalGrants: globalGrants,
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'asg-1',
            roleName: 'counselor',
            permissions: activeRolePermissions,
            clubId: 1,
            sectionId: 12,
            status: 'active',
          ),
        ],
      ),
    );

/// Rol global de coordinación con `consent:verify` (como lo entrega
/// `/auth/me` en `authorization.grants.global_roles`).
AuthorizationGrant _coordinatorRole([String name = 'coordinator']) =>
    AuthorizationGrant(
      roleName: name,
      permissions: const ['consent:verify'],
    );

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _EmptyContinuations extends AnnualContinuationsNotifier {
  @override
  Future<AnnualContinuationsState> build() async =>
      const AnnualContinuationsState(items: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  Future<void> openMembers(
    WidgetTester tester,
    List<String> permissions, {
    UserEntity? user,
  }) async {
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuth(user ?? _user(permissions)),
        ),
        membersRepositoryProvider.overrideWithValue(repo),
        annualContinuationsNotifierProvider.overrideWith(
          _EmptyContinuations.new,
        ),
      ],
      home: const MembersView(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRequests(
    WidgetTester tester,
    List<String> permissions, {
    UserEntity? user,
  }) async {
    await openMembers(tester, permissions, user: user);
    await tester.tap(find.text('Solicitudes').first);
    await tester.pumpAndSettle();
  }

  group('access by permission', () {
    test('join requests access resolves approve, verify-only and none', () {
      expect(
        joinRequestsAccess(_user(['club_members:approve'])),
        JoinRequestsAccess.approve,
      );
      expect(
        joinRequestsAccess(_user(['consent:verify'])),
        JoinRequestsAccess.verifyOnly,
      );
      expect(
        joinRequestsAccess(_user(['consent:verify', 'club_members:approve'])),
        JoinRequestsAccess.approve,
        reason: 'approve implies the full director view',
      );
      expect(
          joinRequestsAccess(_user(['members:read'])), JoinRequestsAccess.none);
      expect(joinRequestsAccess(null), JoinRequestsAccess.none);
    });

    test('verify-only keeps the member list and the requests, not the rest',
        () {
      expect(effectiveMembersMode(1, canApprove: false, canVerify: true), 1);
      expect(effectiveMembersMode(2, canApprove: false, canVerify: true), 0);
      expect(effectiveMembersMode(1, canApprove: false), 0);
    });

    testWidgets('without approve or verify there is no requests mode',
        (tester) async {
      await openMembers(tester, ['members:read']);

      expect(find.text('Solicitudes'), findsNothing);
      expect(find.text('No inscritos'), findsNothing);
    });

    testWidgets('with approve the requests and the not-enrolled modes exist',
        (tester) async {
      await openMembers(tester, ['club_members:approve']);

      expect(find.text('Solicitudes'), findsWidgets);
      expect(find.text('No inscritos'), findsWidgets);
    });

    testWidgets(
        'with approve a pending adult keeps the approve and reject actions',
        (tester) async {
      repo.requests = [adultRequest()];
      // The approve/reject icons are gated on a club role manager too.
      await pumpMembersApp(
        tester,
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuth(
              _user(['club_members:approve', 'club_roles:assign']),
            ),
          ),
          membersRepositoryProvider.overrideWithValue(repo),
          annualContinuationsNotifierProvider.overrideWith(
            _EmptyContinuations.new,
          ),
        ],
        home: const MembersView(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitudes').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Aprobar'), findsOneWidget);
      expect(find.bySemanticsLabel('Rechazar'), findsOneWidget);
    });
  });

  group('verify-only reviewer (consent:verify)', () {
    const perms = ['consent:verify'];

    testWidgets('sees the requests mode but not the not-enrolled one',
        (tester) async {
      await openMembers(tester, perms);

      expect(find.text('Solicitudes'), findsWidgets);
      expect(find.text('No inscritos'), findsNothing);
    });

    testWidgets('a pending minor offers verify and never approve or reject',
        (tester) async {
      repo.requests = [minorRequest(evidence: true)];
      await openRequests(tester, perms);

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.bySemanticsLabel('Verificar consentimiento'), findsOneWidget);
      expect(find.bySemanticsLabel('Aprobar'), findsNothing);
      expect(find.bySemanticsLabel('Rechazar'), findsNothing);
    });

    testWidgets('an adult request gets no action at all', (tester) async {
      repo.requests = [adultRequest()];
      await openRequests(tester, perms);

      expect(find.bySemanticsLabel('Aprobar'), findsNothing);
      expect(find.bySemanticsLabel('Rechazar'), findsNothing);
      expect(find.bySemanticsLabel('Verificar consentimiento'), findsNothing);
    });

    testWidgets('a verified minor cannot be approved from here',
        (tester) async {
      repo.requests = [minorRequest(status: 'verified', evidence: true)];
      await openRequests(tester, perms);

      expect(find.bySemanticsLabel('Aprobar'), findsNothing);
      expect(repo.approveCalls, isEmpty);
    });

    testWidgets('the empty state says there are no forms to verify',
        (tester) async {
      repo.requests = [];
      await openRequests(tester, perms);

      expect(find.text('No hay fichas por verificar'), findsOneWidget);
      expect(find.text('Sin solicitudes'), findsNothing);
    });

    testWidgets('explains that approving belongs to a director',
        (tester) async {
      repo.requests = [minorRequest(evidence: true)];
      await openRequests(tester, perms);

      expect(
        find.text(
          'Puedes verificar fichas de consentimiento. Aprobar o rechazar '
          'solicitudes le corresponde a un director.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'verify opens the verification in verify-only mode and sends '
        'approve=false', (tester) async {
      repo.requests = [minorRequest(evidence: true)];
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(guardianshipId: 'gs-1', approved: false),
        ),
      ];
      await openRequests(tester, perms);

      await tester.tap(find.bySemanticsLabel('Verificar consentimiento'));
      await tester.pumpAndSettle();

      final view = tester.widget<ConsentVerificationView>(
        find.byType(ConsentVerificationView),
      );
      expect(view.canApprove, isFalse);
      expect(find.text('Confirmar y aprobar'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar verificación'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.verifyCalls, [
        (assignmentId: '12/membership-requests/req-1', approve: false),
      ]);
      expect(repo.approveCalls, isEmpty);
    });

    testWidgets('tapping the row opens the verification, not the profile',
        (tester) async {
      repo.requests = [minorRequest(evidence: true)];
      await openRequests(tester, perms);

      await tester.tap(find.text('Ana Pérez'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentVerificationView), findsOneWidget);
    });
  });
  group('verify-only needs club authority, not a coordinator role', () {
    test('a coordinator role alone does not open the requests', () {
      for (final role in [
        'coordinator',
        'zone-coordinator',
        'general-coordinator',
      ]) {
        expect(
          joinRequestsAccess(
            _user(['consent:verify'], globalGrants: [_coordinatorRole(role)]),
          ),
          JoinRequestsAccess.none,
          reason: '$role is coordinator authority, it opens the hub instead',
        );
      }
    });

    test('a club role that carries consent:verify opens verify-only', () {
      expect(
        joinRequestsAccess(
          _user(['consent:verify'], activeRolePermissions: ['consent:verify']),
        ),
        JoinRequestsAccess.verifyOnly,
      );
    });

    test('a coordinator who also has the club role keeps verify-only', () {
      expect(
        joinRequestsAccess(
          _user(
            ['consent:verify'],
            globalGrants: [_coordinatorRole()],
            activeRolePermissions: ['consent:verify'],
          ),
        ),
        JoinRequestsAccess.verifyOnly,
      );
    });

    test('a non-coordinator global role with the permission keeps it', () {
      expect(
        joinRequestsAccess(
          _user(
            ['consent:verify'],
            globalGrants: const [
              AuthorizationGrant(
                roleName: 'admin',
                permissions: ['consent:verify'],
              ),
            ],
          ),
        ),
        JoinRequestsAccess.verifyOnly,
      );
    });

    test('approve is never taken away by a coordinator role', () {
      expect(
        joinRequestsAccess(
          _user(
            ['consent:verify', 'club_members:approve'],
            globalGrants: [_coordinatorRole()],
          ),
        ),
        JoinRequestsAccess.approve,
      );
    });

    test('a role that is not active in the section does not count', () {
      final user = UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        name: 'Laura',
        postRegisterComplete: true,
        authorization: AuthorizationSnapshot(
          effectivePermissions: const ['consent:verify'],
          globalGrants: [_coordinatorRole()],
          activeAssignmentId: 'asg-1',
          clubAssignments: const [
            AuthorizationGrant(
              assignmentId: 'asg-2',
              roleName: 'secretary',
              permissions: ['consent:verify'],
              clubId: 2,
              sectionId: 30,
              status: 'active',
            ),
            AuthorizationGrant(
              assignmentId: 'asg-1',
              roleName: 'member',
              clubId: 1,
              sectionId: 12,
              status: 'active',
            ),
          ],
        ),
      );
      expect(joinRequestsAccess(user), JoinRequestsAccess.none);
    });

    testWidgets('a coordinator has no requests mode in the members screen',
        (tester) async {
      await openMembers(
        tester,
        const [],
        user: _user(['consent:verify'], globalGrants: [_coordinatorRole()]),
      );

      expect(find.text('Solicitudes'), findsNothing);
    });

    testWidgets('a club reviewer keeps the requests mode', (tester) async {
      await openMembers(
        tester,
        const [],
        user: _user(
          ['consent:verify'],
          activeRolePermissions: ['consent:verify'],
        ),
      );

      expect(find.text('Solicitudes'), findsWidgets);
    });

    testWidgets(
        'a 403 GUARD_CLUB_SCOPE_REQUIRED shows an info state, not an empty list',
        (tester) async {
      repo.requestsBySection[12] = const Left(
        AuthFailure(
          message: 'x',
          code: 403,
          errorCode: 'GUARD_CLUB_SCOPE_REQUIRED',
        ),
      );
      await openRequests(
        tester,
        const [],
        user: _user(
          ['consent:verify'],
          activeRolePermissions: ['consent:verify'],
        ),
      );

      expect(
          find.text('Sin acceso a las fichas de esta sección'), findsOneWidget);
      expect(find.text('No hay fichas por verificar'), findsNothing);
      expect(find.text('Sin solicitudes'), findsNothing);
    });

    testWidgets('any other failure is still an empty list', (tester) async {
      repo.requestsBySection[12] =
          const Left(ServerFailure(message: 'x', code: 500));
      await openRequests(
        tester,
        const [],
        user: _user(
          ['consent:verify'],
          activeRolePermissions: ['consent:verify'],
        ),
      );

      expect(
          find.text('Sin acceso a las fichas de esta sección'), findsNothing);
      expect(find.text('No hay fichas por verificar'), findsOneWidget);
    });
  });
}
