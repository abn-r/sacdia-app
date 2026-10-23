import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/consent/consent_evidence_uploader.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

import '../../members_test_support.dart';

const _gone = 'Esta ficha ya no está pendiente de verificación.';

const _uploadNote =
    'La ficha la sube el tutor o el director del club. Aquí solo puedes '
    'revisarla y verificarla.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;
  bool? popped;

  setUp(() {
    repo = FakeMembersRepository();
    popped = null;
  });

  /// Abre la vista desde una pantalla de partida para poder leer el `pop`.
  Future<void> open(
    WidgetTester tester, {
    required bool canApprove,
    JoinRequest? request,
  }) async {
    final target = request ?? minorRequest(evidence: true);
    await pumpMembersApp(
      tester,
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ConsentVerificationView(
                      request: target,
                      canApprove: canApprove,
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

  group('verify-only reviewers do not upload consent forms', () {
    testWidgets('no upload or replace control, and says who uploads',
        (tester) async {
      await open(tester, canApprove: false);

      expect(find.byType(ConsentEvidenceUploader), findsNothing);
      expect(find.text(_uploadNote), findsOneWidget);
      // The form can still be reviewed.
      expect(find.text('Ver ficha'), findsOneWidget);
      expect(find.text('Confirmar verificación'), findsOneWidget);
    });

    testWidgets('without a form there is no upload either', (tester) async {
      await open(
        tester,
        canApprove: false,
        request: minorRequest(),
      );

      expect(find.byType(ConsentEvidenceUploader), findsNothing);
      expect(find.text(_uploadNote), findsOneWidget);
    });

    testWidgets('approvers keep the upload control and not the note',
        (tester) async {
      await open(tester, canApprove: true);

      expect(find.byType(ConsentEvidenceUploader), findsOneWidget);
      expect(find.text(_uploadNote), findsNothing);
    });

    testWidgets(
        'a 403 MR_APPROVE_PERMISSION_REQUIRED switches an approver to '
        'verify-only and hides the upload', (tester) async {
      repo.verifyResults = [
        const Left(
          AuthFailure(
            message: 'x',
            code: 403,
            errorCode: 'MR_APPROVE_PERMISSION_REQUIRED',
          ),
        ),
      ];
      await open(tester, canApprove: true);
      expect(find.byType(ConsentEvidenceUploader), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y aprobar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentEvidenceUploader), findsNothing);
      expect(find.text(_uploadNote), findsOneWidget);
    });

    testWidgets('verify-only still verifies with approve=false',
        (tester) async {
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(guardianshipId: 'gs-1', approved: false),
        ),
      ];
      await open(tester, canApprove: false);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar verificación'));
      await tester.pumpAndSettle();

      expect(repo.verifyCalls, [
        (assignmentId: '12/membership-requests/req-1', approve: false),
      ]);
      expect(repo.uploadCalls, isEmpty);
      expect(popped, isFalse);
    });
  });
  group('404 MR_NOT_FOUND means the form is no longer pending', () {
    const notFound = ServerFailure(
      message: 'x',
      code: 404,
      errorCode: 'MR_NOT_FOUND',
    );

    testWidgets(
        'verifying a form that left the list says so and closes with false',
        (tester) async {
      repo.verifyResults = [const Left(notFound)];
      await open(tester, canApprove: false);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar verificación'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentVerificationView), findsNothing);
      expect(popped, isFalse);
      expect(find.text(_gone), findsOneWidget);
    });

    testWidgets('opening a form that is gone says so and closes with false',
        (tester) async {
      repo.evidenceResult = const Left(notFound);
      await open(tester, canApprove: false);

      expect(find.byType(ConsentVerificationView), findsNothing);
      expect(popped, isFalse);
      expect(find.text(_gone), findsOneWidget);
    });

    testWidgets('an approver keeps the inline error and stays on the screen',
        (tester) async {
      repo.verifyResults = [const Left(notFound)];
      await open(tester, canApprove: true);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y aprobar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentVerificationView), findsOneWidget);
      expect(
        find.text('La solicitud ya no existe o no pertenece a esta sección.'),
        findsOneWidget,
      );
      expect(find.text(_gone), findsNothing);
    });
  });
}
