import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';
import 'package:sacdia_app/features/members/presentation/widgets/join_request_detail_sheet.dart';

import '../../members_test_support.dart';

const _director = UserEntity(
  id: 'director-1',
  email: 'director@example.com',
  name: 'Laura',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: ['club_members:approve'],
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

  Future<void> openRequests(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
    double textScale = 0.5,
  }) async {
    await pumpMembersApp(
      tester,
      size: size,
      textScale: textScale,
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

  JoinRequest waitingMinor() => const JoinRequest(
        assignmentId: '12/membership-requests/req-3',
        userId: 'beto-1',
        name: 'Beto',
        status: JoinRequestStatus.pending,
        consent: JoinRequestConsent(status: JoinRequestConsentStatus.pending),
      );

  testWidgets('renders the three group headers with their counts',
      (tester) async {
    repo.requests = [
      adultRequest(),
      minorRequest(evidence: true),
      waitingMinor(),
    ];

    await openRequests(tester);

    expect(find.text('Listas para aprobar · 1'), findsOneWidget);
    expect(find.text('Revisa la ficha del tutor · 1'), findsOneWidget);
    expect(find.text('Esperando al tutor · 1'), findsOneWidget);
    expect(find.text('Ficha subida por María Pérez'), findsOneWidget);
    expect(find.textContaining('Sin ficha firmada'), findsOneWidget);
  });

  testWidgets('hides the groups that are empty', (tester) async {
    repo.requests = [adultRequest()];

    await openRequests(tester);

    expect(find.text('Listas para aprobar · 1'), findsOneWidget);
    expect(find.textContaining('Revisa la ficha'), findsNothing);
    expect(find.textContaining('Esperando al tutor'), findsNothing);
  });

  testWidgets('«Aprobar» on a ready row approves it', (tester) async {
    repo.requests = [adultRequest()];
    await openRequests(tester);

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();

    expect(repo.approveCalls, ['12/membership-requests/req-2']);
  });

  testWidgets('«Revisar» opens the verification', (tester) async {
    repo.requests = [minorRequest(evidence: true)];
    await openRequests(tester);

    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentVerificationView), findsOneWidget);
    expect(repo.approveCalls, isEmpty);
  });

  testWidgets('tapping a row opens the sheet with the guardian rows',
      (tester) async {
    repo.requests = [minorRequest(evidence: true)];
    await openRequests(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(find.byType(JoinRequestDetailSheet), findsOneWidget);
    expect(find.text('Consentimiento'), findsOneWidget);
    expect(find.text('Por verificar'), findsOneWidget);
    expect(find.text('Subida'), findsOneWidget);
    expect(find.text('Tutor principal'), findsOneWidget);
    expect(find.text('María Pérez (Madre)'), findsOneWidget);
    expect(find.text('Revisar ficha'), findsOneWidget);
    expect(find.text('Ver perfil'), findsOneWidget);
  });

  testWidgets('the sheet «Rechazar» closes it and asks for confirmation',
      (tester) async {
    repo.requests = [adultRequest()];
    await openRequests(tester);

    await tester.tap(find.text('Luis Soto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(find.byType(JoinRequestDetailSheet), findsNothing);
    expect(find.text('¿Rechazar solicitud?'), findsOneWidget);
    expect(repo.rejectCalls, isEmpty);

    await tester.tap(find.text('Rechazar').last);
    await tester.pumpAndSettle();
    expect(repo.rejectCalls, ['12/membership-requests/req-2']);
  });

  testWidgets('the sheet «Aprobar» approves a ready request', (tester) async {
    repo.requests = [adultRequest()];
    await openRequests(tester);

    await tester.tap(find.text('Luis Soto'));
    await tester.pumpAndSettle();
    // Row pill and sheet button share the label; the sheet is on top.
    await tester.tap(find.text('Aprobar').last);
    await tester.pumpAndSettle();

    expect(find.byType(JoinRequestDetailSheet), findsNothing);
    expect(repo.approveCalls, ['12/membership-requests/req-2']);
  });

  testWidgets('swiping a row to the left asks to reject it', (tester) async {
    repo.requests = [adultRequest()];
    await openRequests(tester);

    await tester.drag(find.text('Luis Soto'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('¿Rechazar solicitud?'), findsOneWidget);
    // The row stays until the provider refreshes the list.
    expect(find.text('Luis Soto'), findsOneWidget);
  });

  testWidgets('an empty name falls back to the email, then to a label',
      (tester) async {
    repo.requests = [
      const JoinRequest(
        assignmentId: '12/membership-requests/req-4',
        userId: 'u-4',
        name: '',
        email: 'sin.nombre@example.com',
        status: JoinRequestStatus.pending,
      ),
      const JoinRequest(
        assignmentId: '12/membership-requests/req-5',
        userId: 'u-5',
        name: '',
        status: JoinRequestStatus.pending,
      ),
    ];

    await openRequests(tester);

    expect(find.text('sin.nombre@example.com'), findsOneWidget);
    expect(find.text('Solicitante sin nombre'), findsOneWidget);
  });

  testWidgets('fits a phone at full text size without overflow',
      (tester) async {
    repo.requests = [
      adultRequest(),
      minorRequest(evidence: true),
      const JoinRequest(
        assignmentId: '12/membership-requests/req-6',
        userId: 'u-6',
        name: 'Maria de los Angeles Fernanda',
        paternalSurname: 'Hernandez',
        maternalSurname: 'Villalobos de la Torre',
        status: JoinRequestStatus.pending,
        consent: JoinRequestConsent(
          status: JoinRequestConsentStatus.pending,
          evidenceUploaded: true,
          viewerVerifyBlock: ConsentVerifyBlock.selfCustodian,
        ),
      ),
    ];

    await openRequests(tester, size: const Size(402, 874), textScale: 1);

    expect(tester.takeException(), isNull);
    expect(find.text('Otro directivo debe verificarla'), findsOneWidget);
  });
}
