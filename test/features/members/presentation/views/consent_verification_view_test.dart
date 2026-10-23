import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

import '../../members_test_support.dart';

const _assignment = '12/membership-requests/req-1';

ConsentEvidencePicker _picker() => ConsentEvidencePicker(
      pickPdf: () async =>
          (path: '/tmp/ficha.pdf', name: 'ficha.pdf', size: 2048),
    );

const _approved = Right<Failure, ConsentVerificationResult>(
  ConsentVerificationResult(
    guardianshipId: 'gs-1',
    approved: true,
    verificationMethod: 'director_paper_form',
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

  setUp(() {
    repo = FakeMembersRepository();
    popped = null;
  });

  /// Abre la vista desde una pantalla de partida para poder leer el resultado
  /// del `pop` y comprobar que salir no verifica nada.
  Future<void> open(
    WidgetTester tester, {
    JoinRequest? request,
    ConsentEvidencePicker? picker,
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
                      picker: picker ?? _picker(),
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

  SacButton confirmButton(WidgetTester tester) => tester.widget<SacButton>(
        find.byWidgetPredicate(
            (w) => w is SacButton && w.text == 'Confirmar y aprobar'),
      );

  Future<void> tickReviewed(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Confirmar y aprobar'));
    await tester.pumpAndSettle();
  }

  group('opening', () {
    testWidgets('shows the minor, the guardians and an empty evidence state',
        (tester) async {
      await open(tester, request: minorRequest());

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Menor · consentimiento pendiente'), findsOneWidget);
      expect(find.text('María Pérez · Madre · Principal'), findsOneWidget);
      expect(
        find.text(
          'Aún no hay una ficha subida. Toma una foto o sube el PDF de la ficha firmada.',
        ),
        findsOneWidget,
      );
      expect(repo.evidenceReads, isEmpty,
          reason: 'no evidence yet, nothing to fetch');
    });

    testWidgets('with evidence it loads the signed URL and offers to view it',
        (tester) async {
      await open(tester);

      expect(repo.evidenceReads, [_assignment]);
      expect(find.textContaining('Subida por Laura Díaz'), findsOneWidget);
      expect(find.text('Ver ficha'), findsOneWidget);
    });

    testWidgets('viewing the form opens the image viewer (no share, no cache)',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('Ver ficha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final viewer = tester.widget<SacImageViewer>(find.byType(SacImageViewer));
      expect(viewer.allowShare, isFalse);
      expect(viewer.cacheNetwork, isFalse);
    });

    testWidgets('503 on the evidence says it is not available yet',
        (tester) async {
      repo.evidenceResult = const Left(
        ServerFailure(
          message: 'x',
          code: 503,
          errorCode: 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
        ),
      );
      await open(tester);

      expect(
        find.text(
          'Las fichas de consentimiento aún no están disponibles. Inténtalo más tarde.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ver ficha'), findsNothing);
    });

    testWidgets('other evidence errors offer a retry', (tester) async {
      repo.evidenceResult = const Left(ServerFailure(message: 'x', code: 500));
      await open(tester);

      expect(find.text('No se pudo cargar la ficha.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('confirm gating', () {
    testWidgets('without a form Confirm is disabled even if the box is ticked',
        (tester) async {
      await open(tester, request: minorRequest());

      await tickReviewed(tester);

      expect(confirmButton(tester).onPressed, isNull);
    });

    testWidgets('with a form but an unticked box Confirm is disabled',
        (tester) async {
      await open(tester);

      expect(confirmButton(tester).onPressed, isNull);
    });

    testWidgets('form + ticked box enables Confirm', (tester) async {
      await open(tester);

      await tickReviewed(tester);

      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('a chosen file that is not uploaded blocks Confirm',
        (tester) async {
      await open(tester);
      await tickReviewed(tester);

      await tester.tap(find.text('Reemplazar ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Sube el archivo elegido antes de confirmar.'),
          findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);
      expect(repo.verifyCalls, isEmpty);
    });
  });

  group('upload', () {
    testWidgets('uploading then ticking enables Confirm; upload never verifies',
        (tester) async {
      await open(tester, request: minorRequest());

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(repo.uploadCalls,
          [(assignmentId: _assignment, fileName: 'ficha.pdf')]);
      expect(repo.evidenceReads, [_assignment],
          reason: 'the uploaded form is fetched to show it');
      expect(repo.verifyCalls, isEmpty);
      expect(find.text('Ficha subida.'), findsOneWidget);

      await tickReviewed(tester);
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('a failed upload offers retry and verifies nothing',
        (tester) async {
      repo.uploadResult = const Left(ConnectionFailure(message: 'offline'));
      await open(tester, request: minorRequest());

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      expect(repo.verifyCalls, isEmpty);
      expect(confirmButton(tester).onPressed, isNull);
    });

    testWidgets(
        '409 already verified: explains it, closes the upload and verifies '
        'nothing', (tester) async {
      repo.uploadResult = const Left(
        ServerFailure(
          message: 'x',
          code: 409,
          errorCode: 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED',
        ),
      );
      await open(tester, request: minorRequest());

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(find.text('La ficha ya fue verificada.'), findsWidgets);
      expect(find.text('Subir ficha firmada'), findsNothing);
      expect(find.text('Reemplazar ficha'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(repo.verifyCalls, isEmpty);
      // La ficha vigente se vuelve a pedir y se puede ver.
      expect(repo.evidenceReads, [_assignment]);
      expect(find.text('Ver ficha'), findsOneWidget);
      // Ya no hay archivo pendiente: se puede confirmar.
      await tickReviewed(tester);
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('leaving mid-upload does not verify', (tester) async {
      final gate = Completer<void>();
      final slow = _SlowUploadRepo(repo, gate);
      await pumpMembersApp(
        tester,
        overrides: [membersRepositoryProvider.overrideWithValue(slow)],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ConsentVerificationView(
                    request: minorRequest(),
                    picker: _picker(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pump();

      // El director se va con la subida en vuelo.
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(repo.verifyCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('verify', () {
    testWidgets('confirm verifies with approve=true and pops true',
        (tester) async {
      await open(tester);
      await tickReviewed(tester);

      await tester.tap(find.text('Confirmar y aprobar'));
      await tester.pump();
      // Antes de que el snackbar caduque (pumpAndSettle lo esperaría).
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.verifyCalls, [(assignmentId: _assignment, approve: true)]);
      expect(popped, isTrue);
      expect(
        find.text(
            'Consentimiento verificado. Solicitud de Ana Pérez aprobada.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
        'approve failing after the commit keeps the screen and retries '
        'only the approval', (tester) async {
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(
            guardianshipId: 'gs-1',
            approved: false,
            approveError: 'MR_NOT_FOUND',
          ),
        ),
        _approved,
      ];
      await open(tester);
      await tickReviewed(tester);

      await confirm(tester);

      expect(popped, isNull, reason: 'still on the screen');
      expect(find.text('Menor · consentimiento verificado'), findsOneWidget);
      expect(
        find.textContaining(
          'La solicitud ya no existe o no pertenece a esta sección.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar aprobación'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Reemplazar ficha'), findsNothing,
          reason: 'consent is verified, no more uploads');

      await tester.tap(find.text('Reintentar aprobación'));
      await tester.pumpAndSettle();

      expect(repo.verifyCalls, [
        (assignmentId: _assignment, approve: true),
        (assignmentId: _assignment, approve: true),
      ]);
      expect(popped, isTrue);
    });

    testWidgets('an unknown approve_error code falls back to a generic reason',
        (tester) async {
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(
            guardianshipId: 'gs-1',
            approved: false,
            approveError: 'SOMETHING_NEW',
          ),
        ),
      ];
      await open(tester);
      await tickReviewed(tester);

      await confirm(tester);

      expect(
        find.textContaining(
            'No se pudo completar la acción. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('a retry that fails again stays on the retry state',
        (tester) async {
      repo.verifyResults = [
        const Right(
          ConsentVerificationResult(
            guardianshipId: 'gs-1',
            approved: false,
            approveError: 'MR_NOT_FOUND',
          ),
        ),
        _verifyError(409, 'MR_ALREADY_PENDING'),
      ];
      await open(tester);
      await tickReviewed(tester);
      await confirm(tester);

      await tester.tap(find.text('Reintentar aprobación'));
      await tester.pumpAndSettle();

      expect(find.text('Esta solicitud ya fue procesada.'), findsOneWidget);
      expect(find.text('Reintentar aprobación'), findsOneWidget);
      expect(popped, isNull);
    });
  });

  group('verify errors', () {
    Future<void> verifyWith(
      WidgetTester tester,
      Left<Failure, ConsentVerificationResult> result,
    ) async {
      repo.verifyResults = [result];
      await open(tester);
      await tickReviewed(tester);
      await confirm(tester);
    }

    testWidgets('four-eyes: custody must be verified by someone else',
        (tester) async {
      await verifyWith(
          tester, _verifyError(403, 'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY'));

      expect(
        find.text(
          'Este menor está bajo la custodia del club. Debe verificarlo otra persona autorizada del club, no quien subió la ficha ni quien lo recibió en custodia.',
        ),
        findsOneWidget,
      );
      expect(popped, isNull);
    });

    testWidgets('a guardian of the minor cannot verify it', (tester) async {
      await verifyWith(
          tester, _verifyError(403, 'GUARDIANSHIP_GUARDIAN_SELF_VERIFY'));

      expect(
        find.text(
          'No puedes verificar el consentimiento de un menor del que eres tutor. Debe hacerlo otra persona autorizada del club.',
        ),
        findsOneWidget,
      );
      expect(popped, isNull);
    });

    testWidgets('evidence required asks for the form again', (tester) async {
      await verifyWith(
          tester, _verifyError(409, 'GUARDIANSHIP_EVIDENCE_REQUIRED'));

      expect(
        find.text(
            'Sube la ficha de consentimiento firmada antes de verificar.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Aún no hay una ficha subida. Toma una foto o sube el PDF de la ficha firmada.',
        ),
        findsOneWidget,
      );
      expect(confirmButton(tester).onPressed, isNull);
    });

    testWidgets('confirmation required', (tester) async {
      await verifyWith(
          tester, _verifyError(400, 'MR_CONSENT_CONFIRMATION_REQUIRED'));

      expect(
        find.text(
            'Confirma que revisaste la ficha firmada antes de verificar.'),
        findsOneWidget,
      );
    });

    testWidgets('request already processed', (tester) async {
      await verifyWith(tester, _verifyError(409, 'MR_ALREADY_PENDING'));
      expect(find.text('Esta solicitud ya fue procesada.'), findsOneWidget);
    });

    testWidgets('request not found', (tester) async {
      await verifyWith(tester, _verifyError(404, 'MR_NOT_FOUND'));
      expect(
        find.text('La solicitud ya no existe o no pertenece a esta sección.'),
        findsOneWidget,
      );
    });

    testWidgets('missing permission', (tester) async {
      await verifyWith(tester, _verifyError(403, 'GUARD_PERMISSION_DENIED'));
      expect(find.text('No tienes permiso para realizar esta acción.'),
          findsOneWidget);
    });

    testWidgets('no connection', (tester) async {
      await verifyWith(
        tester,
        const Left(NetworkFailure(message: 'offline')),
      );
      expect(find.textContaining('conexión'), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('the user can try again after an error', (tester) async {
      repo.verifyResults = [
        _verifyError(409, 'MR_ALREADY_PENDING'),
        _approved,
      ];
      await open(tester);
      await tickReviewed(tester);
      await confirm(tester);
      expect(popped, isNull);

      await confirm(tester);

      expect(repo.verifyCalls, hasLength(2));
      expect(popped, isTrue);
    });
  });
}

/// Repositorio cuya subida queda retenida hasta que el test la libere.
class _SlowUploadRepo extends FakeMembersRepository {
  _SlowUploadRepo(this._inner, this._gate);

  final FakeMembersRepository _inner;
  final Completer<void> _gate;

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String assignmentId,
    required ConsentEvidenceLocalFile file,
  }) async {
    await _gate.future;
    return _inner.uploadConsentEvidence(assignmentId: assignmentId, file: file);
  }

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
          String assignmentId) =>
      _inner.getConsentEvidence(assignmentId);

  @override
  Future<Either<Failure, ConsentVerificationResult>> verifyConsent({
    required String assignmentId,
    required bool approve,
  }) =>
      _inner.verifyConsent(assignmentId: assignmentId, approve: approve);
}
