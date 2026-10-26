import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/views/role_assignment_view.dart';

import '../../members_test_support.dart';

const _director = UserEntity(
  id: 'director-1',
  email: 'director@example.com',
  name: 'Laura',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: ['club_members:approve', 'club_roles:assign'],
    activeAssignmentId: 'asg-dir',
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'asg-dir',
        roleName: 'director',
        clubId: 1,
        sectionId: 12,
        status: 'active',
      ),
    ],
  ),
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _director;
}

const _context = ClubContext(clubId: 1, sectionId: 12, roleName: 'director');

const _ana = ClubMember(
  userId: 'ana-1',
  name: 'Ana',
  paternalSurname: 'Pérez',
);

const _notVerified = Left<Failure, bool>(
  ServerFailure(message: 'x', code: 409, errorCode: 'MR_CONSENT_NOT_VERIFIED'),
);

const _notVerifiedText =
    'No se puede asignar un cargo a este menor: el consentimiento de su tutor aún no está verificado.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;
  bool? popped;

  setUp(() {
    repo = FakeMembersRepository();
    popped = null;
  });

  Future<void> open(
    WidgetTester tester, {
    JoinRequest? pendingConsentRequest,
  }) async {
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        membersRepositoryProvider.overrideWithValue(repo),
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RoleAssignmentView(
                      member: _ana,
                      clubContext: _context,
                      pendingConsentRequest: pendingConsentRequest,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> saveTreasurer(WidgetTester tester) async {
    await tester.tap(find.text(RoleUtils.translate('treasurer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cargo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a successful assignment closes the view', (tester) async {
    await open(tester);

    await saveTreasurer(tester);
    await tester.pumpAndSettle();

    expect(repo.assignRoleCalls, [(userId: 'ana-1', role: 'treasurer')]);
    expect(popped, isTrue);
  });

  testWidgets(
      '409 MR_CONSENT_NOT_VERIFIED shows the translated message, not the '
      'server text, and stays on the view', (tester) async {
    repo.assignRoleResult = _notVerified;
    await open(tester);

    await saveTreasurer(tester);

    expect(find.text(_notVerifiedText), findsOneWidget);
    expect(find.text('x'), findsNothing);
    expect(find.text('Verificar consentimiento'), findsNothing,
        reason: 'no pending request to verify');
    expect(find.byType(RoleAssignmentView), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets(
      'for a pending minor with a join request it offers the verification',
      (tester) async {
    repo.assignRoleResult = _notVerified;
    await open(tester, pendingConsentRequest: minorRequest(evidence: true));

    await saveTreasurer(tester);

    expect(find.text(_notVerifiedText), findsOneWidget);
    await tester.tap(find.text('Verificar consentimiento'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentVerificationView), findsOneWidget);
    expect(repo.verifyCalls, isEmpty, reason: 'opening never verifies');
  });

  testWidgets('another business error keeps the generic role message',
      (tester) async {
    repo.assignRoleResult = const Left(ServerFailure(message: 'x', code: 500));
    await open(tester);

    await saveTreasurer(tester);

    expect(find.text('Error al asignar el cargo. Intenta de nuevo.'),
        findsOneWidget);
  });

  testWidgets('a 4xx without a known code still shows the backend reason',
      (tester) async {
    repo.assignRoleResult = const Left(
      ServerFailure(message: 'Cupo lleno para el cargo', code: 409),
    );
    await open(tester);

    await saveTreasurer(tester);

    expect(find.text('Cupo lleno para el cargo'), findsOneWidget);
  });
}
