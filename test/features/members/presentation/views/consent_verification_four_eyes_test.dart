import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

import '../../members_test_support.dart';

const _assignment = '12/membership-requests/req-9';

/// Menor bajo custodia del club: sin tutor vinculado, con ficha subida.
JoinRequest _custodyRequest({bool evidence = true}) => JoinRequest(
      assignmentId: _assignment,
      userId: 'luis-9',
      name: 'Luis',
      paternalSurname: 'Pérez',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
      consent: JoinRequestConsent(
        guardianshipId: 'gs-9',
        status: JoinRequestConsentStatus.pending,
        evidenceUploaded: evidence,
        dependent: true,
        guardianLinked: false,
        guardians: const [
          ConsentGuardianRef(displayName: 'Club ACV', isPrimary: true),
        ],
      ),
    );

/// Menor con un tutor vinculado: el cuatro ojos del club NO aplica.
JoinRequest _guardedRequest() => JoinRequest(
      assignmentId: '12/membership-requests/req-1',
      userId: 'ana-1',
      name: 'Ana',
      paternalSurname: 'Pérez',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
      consent: const JoinRequestConsent(
        guardianshipId: 'gs-1',
        status: JoinRequestConsentStatus.pending,
        evidenceUploaded: true,
        dependent: true,
        guardianLinked: true,
        guardians: [
          ConsentGuardianRef(
            displayName: 'María Pérez',
            relationshipTypeName: 'Madre',
            isPrimary: true,
          ),
        ],
      ),
    );

Left<Failure, ConsentVerificationResult> _verifyError(
        int status, String code) =>
    Left(
      status == 403
          ? AuthFailure(message: 'x', code: status, errorCode: code)
          : ServerFailure(message: 'x', code: status, errorCode: code),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;
  bool? popped;
  late ProviderContainer container;

  setUp(() {
    repo = FakeMembersRepository();
    popped = null;
  });

  Future<void> open(
    WidgetTester tester, {
    required JoinRequest request,
    bool canApprove = true,
    Set<String> created = const {},
    Set<String> uploaded = const {},
  }) async {
    await pumpMembersApp(
      tester,
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        createdMinorUserIdsProvider.overrideWith((ref) => created),
        uploadedFormMinorUserIdsProvider.overrideWith((ref) => uploaded),
      ],
      home: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ConsentVerificationView(
                      request: request,
                      canApprove: canApprove,
                      picker: ConsentEvidencePicker(
                        pickPdf: () async => (
                          path: '/tmp/ficha.pdf',
                          name: 'ficha.pdf',
                          size: 8
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SacButton button(WidgetTester tester, String text) =>
      tester.widget<SacButton>(find.widgetWithText(SacButton, text));

  Future<void> tick(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  const anotherPerson =
      'Otra persona debe verificar este consentimiento: tú registraste al menor o subiste la ficha.';

  group('four eyes: the creator or uploader', () {
    testWidgets(
        'creator of a custodial minor: Confirm is disabled with the '
        '"another person" notice, even with the box ticked', (tester) async {
      await open(tester, request: _custodyRequest(), created: {'luis-9'});

      expect(find.text(anotherPerson), findsOneWidget);
      await tick(tester);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNull);
      expect(repo.verifyCalls, isEmpty);
    });

    testWidgets('uploader (this session) of a custodial minor is blocked too',
        (tester) async {
      await open(tester, request: _custodyRequest(), uploaded: {'luis-9'});

      expect(find.text(anotherPerson), findsOneWidget);
      await tick(tester);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNull);
    });

    testWidgets(
        'uploading the form from this screen blocks Confirm for a custodial '
        'minor', (tester) async {
      await open(tester, request: _custodyRequest(evidence: false));

      expect(find.text(anotherPerson), findsNothing);
      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(find.text(anotherPerson), findsOneWidget);
      expect(container.read(uploadedFormMinorUserIdsProvider), {'luis-9'});
      await tick(tester);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNull);
    });

    testWidgets('a third person (not creator, not uploader) can confirm',
        (tester) async {
      await open(tester, request: _custodyRequest());

      expect(find.text(anotherPerson), findsNothing);
      await tick(tester);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNotNull);
    });

    testWidgets(
        'the rule is custody-only: a minor with a linked guardian is not '
        'blocked even if the user created the id', (tester) async {
      await open(tester, request: _guardedRequest(), created: {'ana-1'});

      expect(find.text(anotherPerson), findsNothing);
      await tick(tester);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNotNull);
    });

    testWidgets(
        'the server stays the authority: a forced 403 CUSTODIAN_SELF_VERIFY '
        'shows the message and disables Confirm', (tester) async {
      repo.verifyResults = [
        _verifyError(403, 'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY'),
      ];
      await open(tester, request: _custodyRequest());
      await tick(tester);

      await tester.tap(find.text('Confirmar y aprobar'));
      await tester.pumpAndSettle();

      expect(repo.verifyCalls, hasLength(1));
      expect(find.textContaining('Debe verificarlo otra persona autorizada'),
          findsOneWidget);
      expect(button(tester, 'Confirmar y aprobar').onPressed, isNull,
          reason: 'retrying with the same person can never work');
      expect(popped, isNull);
    });
  });

  group('verify-only reviewer (consent:verify without club_members:approve)',
      () {
    testWidgets('does not see Approve: verifies with approve=false',
        (tester) async {
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(guardianshipId: 'gs-9', approved: false),
        ),
      ];
      await open(tester, request: _custodyRequest(), canApprove: false);

      expect(find.text('Confirmar y aprobar'), findsNothing);
      expect(
        find.text(
            'Puedes verificar la ficha, pero aprobar la solicitud le corresponde a un director.'),
        findsOneWidget,
      );
      await tick(tester);
      await tester.tap(find.text('Confirmar verificación'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.verifyCalls, [(assignmentId: _assignment, approve: false)]);
      expect(popped, isFalse, reason: 'verified, NOT approved');
      expect(
        find.text(
            'Consentimiento verificado. Falta que un director apruebe la solicitud de Luis Pérez.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
        'a forced 403 MR_APPROVE_PERMISSION_REQUIRED explains it and falls '
        'back to verify-only without verifying anything', (tester) async {
      repo.verifyResults = [
        _verifyError(403, 'MR_APPROVE_PERMISSION_REQUIRED'),
        const Right(
          ConsentVerificationResult(guardianshipId: 'gs-9', approved: false),
        ),
      ];
      await open(tester, request: _custodyRequest());
      await tick(tester);

      await tester.tap(find.text('Confirmar y aprobar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'No tienes permiso para aprobar solicitudes. Solo puedes verificar el consentimiento.'),
        findsOneWidget,
      );
      expect(find.text('Confirmar y aprobar'), findsNothing);
      expect(find.text('Confirmar verificación'), findsOneWidget);
      expect(popped, isNull);

      await tester.tap(find.text('Confirmar verificación'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.verifyCalls.map((c) => c.approve), [true, false]);
      expect(popped, isFalse);
      await tester.pumpAndSettle();
    });
  });
}
