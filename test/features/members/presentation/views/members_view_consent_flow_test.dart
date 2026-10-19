import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

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

  Future<void> openRequests(WidgetTester tester) async {
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
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
  }

  testWidgets('a pending minor shows the badge and the verify action',
      (tester) async {
    repo.requests = [minorRequest(), adultRequest()];

    await openRequests(tester);

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Menor · consentimiento pendiente'), findsOneWidget);
    expect(find.bySemanticsLabel('Verificar consentimiento'), findsOneWidget);
    // El adulto sigue con la aprobación normal.
    expect(find.bySemanticsLabel('Aprobar'), findsOneWidget);
  });

  testWidgets(
      'tapping verify on a pending minor opens the verification and never '
      'calls approve', (tester) async {
    repo.requests = [minorRequest(evidence: true)];
    await openRequests(tester);

    await tester.tap(find.bySemanticsLabel('Verificar consentimiento'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentVerificationView), findsOneWidget);
    expect(repo.approveCalls, isEmpty);
  });

  testWidgets('a verified minor is approved directly', (tester) async {
    repo.requests = [minorRequest(status: 'verified', evidence: true)];
    await openRequests(tester);

    expect(find.text('Menor · consentimiento verificado'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Aprobar'));
    await tester.pumpAndSettle();

    expect(repo.approveCalls, ['12/membership-requests/req-1']);
    expect(find.byType(ConsentVerificationView), findsNothing);
  });

  testWidgets(
      'a stale list: 409 MR_CONSENT_NOT_VERIFIED explains it and opens the '
      'verification', (tester) async {
    // La lista creía que el consentimiento ya estaba verificado.
    repo.requests = [minorRequest(status: 'verified', evidence: true)];
    repo.approveResult = const Left(
      ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'MR_CONSENT_NOT_VERIFIED',
      ),
    );
    await openRequests(tester);

    await tester.tap(find.bySemanticsLabel('Aprobar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repo.approveCalls, hasLength(1));
    expect(
      find.text(
        'Falta verificar el consentimiento del tutor. Se abrió la verificación.',
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConsentVerificationView), findsOneWidget);
  });

  testWidgets('any other approve failure keeps the generic message',
      (tester) async {
    repo.requests = [adultRequest()];
    repo.approveResult = const Left(ServerFailure(message: 'x', code: 500));
    await openRequests(tester);

    await tester.tap(find.bySemanticsLabel('Aprobar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Error al aprobar la solicitud'), findsOneWidget);
    expect(find.byType(ConsentVerificationView), findsNothing);
  });

  testWidgets('an adult is approved as before', (tester) async {
    repo.requests = [adultRequest()];
    await openRequests(tester);

    await tester.tap(find.bySemanticsLabel('Aprobar'));
    await tester.pumpAndSettle();

    expect(repo.approveCalls, ['12/membership-requests/req-2']);
  });
}
