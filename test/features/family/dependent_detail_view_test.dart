import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/family_outcome_messages.dart';
import 'package:sacdia_app/features/family/presentation/views/dependent_detail_view.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';

DependentDetail _detail({
  String consent = 'pending',
  bool evidence = false,
  Map<String, Object?>? club,
  List<Map<String, Object?>>? guardians,
}) =>
    FamilyJson.detail(
      detailJson(
        consent: consent,
        evidence: evidence,
        club: club,
        guardians: guardians,
      ),
    );

final _other = guardianJson(
  id: 'gs-2',
  userId: 'guardian-2',
  name: 'Pedro Pérez',
  primary: false,
  me: false,
  consent: 'verified',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier();
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth),
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        GoRoute(
          path: '/family/:dependentId',
          builder: (_, state) => DependentDetailView(
            dependentId: state.pathParameters['dependentId']!,
            picker: ConsentEvidencePicker(
              pickPdf: () async =>
                  (path: '/tmp/ficha.pdf', name: 'ficha.pdf', size: 2048),
            ),
          ),
        ),
      ],
    );
    unawaited(router.push('/family/ana-1'));
    await tester.pumpAndSettle();
    return router;
  }

  group('detail', () {
    testWidgets('lists guardians with you, primary and consent',
        (tester) async {
      repo.detail = Right(_detail(guardians: [guardianJson(), _other]));

      await pump(tester);

      expect(find.text('Ana Pérez López'), findsOneWidget);
      expect(find.text('María Pérez'), findsOneWidget);
      expect(find.text('Pedro Pérez'), findsOneWidget);
      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Consentimiento verificado'), findsOneWidget);
    });

    testWidgets('pulling down refetches, so a verification shows up',
        (tester) async {
      repo.detail = Right(_detail(evidence: true));
      await pump(tester);
      expect(repo.detailFetches, 1);
      expect(
        find.text(
            'Ficha firmada subida. Esperando la verificación del director.'),
        findsOneWidget,
      );

      // El director verifica con la pantalla abierta.
      repo.detail = Right(_detail(consent: 'verified', evidence: true));
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pumpAndSettle();
      await refresh;

      expect(repo.detailFetches, 2);
      expect(
        find.text('El director verificó el consentimiento.'),
        findsOneWidget,
      );
    });

    testWidgets('consent text follows evidence and status', (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);
      expect(
          find.textContaining('Aún no hay una ficha firmada'), findsOneWidget);
    });

    testWidgets('uploaded form waits for the director', (tester) async {
      repo.detail = Right(_detail(evidence: true));
      await pump(tester);
      expect(
        find.text(
            'Ficha firmada subida. Esperando la verificación del director.'),
        findsOneWidget,
      );
    });

    testWidgets('a verified consent says so', (tester) async {
      repo.detail = Right(_detail(consent: 'verified', evidence: true));
      await pump(tester);
      expect(
        find.text('El director verificó el consentimiento.'),
        findsOneWidget,
      );
    });

    testWidgets('a primary guardian can remove a secondary one',
        (tester) async {
      repo.detail = Right(_detail(guardians: [guardianJson(), _other]));
      await pump(tester);

      expect(find.text('Quitar a Pedro Pérez'), findsOneWidget);
      await tester.tap(find.text('Quitar a Pedro Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar').last);
      await tester.pumpAndSettle();

      expect(repo.revokeCalls, [
        (guardianshipId: 'gs-2', removedByPrimary: true),
      ]);
    });

    testWidgets('a secondary guardian has no remove action', (tester) async {
      repo.detail = Right(_detail(guardians: [
        guardianJson(id: 'gs-1', primary: false, userId: 'guardian-1'),
        guardianJson(
          id: 'gs-2',
          userId: 'guardian-2',
          name: 'Pedro Pérez',
          me: false,
        ),
      ]));
      await pump(tester);

      expect(find.textContaining('Quitar a'), findsNothing);
      expect(find.text('Dejar de ser tutor'), findsOneWidget);
    });

    testWidgets('custodian rows cannot be removed and are labeled',
        (tester) async {
      repo.detail = Right(_detail(guardians: [
        guardianJson(),
        guardianJson(
          id: 'gs-9',
          userId: null,
          name: 'Club Águilas',
          primary: false,
          custodian: true,
          me: false,
        ),
      ]));
      await pump(tester);

      expect(find.text('Custodia del club'), findsOneWidget);
      expect(find.textContaining('Quitar a'), findsNothing);
    });
  });

  group('invite a second guardian', () {
    testWidgets('shows the XXXX-XXXX code with its expiry', (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      await tester.tap(find.text('Invitar a otro tutor'));
      await tester.pumpAndSettle();

      expect(repo.issueCalls, ['ana-1']);
      expect(find.text('7KQ4-M9TX'), findsOneWidget);
      expect(find.text('Código de vinculación'), findsOneWidget);
      expect(find.textContaining('Vence'), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
    });

    testWidgets('"Compartir" is a positive action, not the destructive style',
        (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      await tester.tap(find.text('Invitar a otro tutor'));
      await tester.pumpAndSettle();

      final share =
          tester.widget<SacButton>(find.widgetWithText(SacButton, 'Compartir'));
      expect(share.variant, SacButtonVariant.success);
    });

    testWidgets('the guardian limit shows its own message', (tester) async {
      repo.detail = Right(_detail());
      repo.issued = const Left(
        ServerFailure(
          message: 'x',
          code: 409,
          errorCode: 'GUARDIANSHIP_GUARDIAN_LIMIT_REACHED',
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Invitar a otro tutor'));
      await tester.pumpAndSettle();

      expect(
        find.text('Este menor ya tiene el máximo de tutores.'),
        findsOneWidget,
      );
      expect(find.text('7KQ4-M9TX'), findsNothing);
    });
  });

  group('leave', () {
    Future<void> openLeave(WidgetTester tester) async {
      await tester.tap(find.text('Dejar de ser tutor'));
      await tester.pumpAndSettle();
    }

    testWidgets('warns about the other guardian outcome', (tester) async {
      repo.detail = Right(_detail(guardians: [guardianJson(), _other]));
      await pump(tester);

      await openLeave(tester);

      expect(find.text('¿Dejar de ser tutor de Ana?'), findsOneWidget);
      expect(
        find.text('Otro tutor seguirá a cargo de Ana.'),
        findsOneWidget,
      );
    });

    testWidgets('warns about club custody when the minor has a club request',
        (tester) async {
      repo.detail = Right(_detail(club: clubPending));
      await pump(tester);

      await openLeave(tester);

      expect(
        find.text('El club quedará a cargo de Ana mientras tanto.'),
        findsOneWidget,
      );
    });

    testWidgets('warns about freezing when nobody else can take over',
        (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      await openLeave(tester);

      expect(
        find.text(
          'Ana quedará congelado y su información se borrará en 90 días.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirming revokes, shows the real outcome and goes back',
        (tester) async {
      repo.detail = Right(_detail());
      repo.revoked = const Right(
        RevokeResult(
          guardianshipId: 'gs-ana-1',
          outcome: DependentOutcome.clubCustody,
        ),
      );
      final router = await pump(tester);

      await openLeave(tester);
      await tester.tap(find.text('Dejar de ser tutor').last);
      await tester.pumpAndSettle();

      expect(repo.revokeCalls, [
        (guardianshipId: 'gs-1', removedByPrimary: false),
      ]);
      expect(
        find.text(
          'Dejaste de gestionar el perfil de Ana. '
          'El club quedará a cargo de Ana mientras tanto.',
        ),
        findsOneWidget,
        reason: 'snackbar with the confirmation and the real outcome, shown '
            'on the screen we returned to',
      );
      expect(router.state.uri.path, '/family');
    });

    testWidgets('cancelling does not call the server', (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      await openLeave(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.revokeCalls, isEmpty);
    });

    testWidgets('a forbidden revoke explains why', (tester) async {
      repo.detail = Right(_detail());
      repo.revoked = const Left(
        AuthFailure(
          message: 'x',
          code: 403,
          errorCode: 'GUARDIANSHIP_REVOKE_FORBIDDEN',
        ),
      );
      await pump(tester);

      await openLeave(tester);
      await tester.tap(find.text('Dejar de ser tutor').last);
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes permiso para quitar a este tutor.'),
        findsOneWidget,
      );
    });
  });

  group('consent form (FP-78)', () {
    testWidgets('a pending dependent without a form can upload one',
        (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.text('Ficha de consentimiento'), findsOneWidget);
      expect(find.textContaining('Imprime y firma la ficha del club'),
          findsOneWidget);
      expect(find.text('Subir ficha firmada'), findsOneWidget);
      expect(find.text('Ver ficha subida'), findsNothing);
    });

    testWidgets('with a form it can be viewed or replaced', (tester) async {
      repo.detail = Right(_detail(evidence: true));
      await pump(tester);

      expect(find.text('Ver ficha subida'), findsOneWidget);
      expect(find.text('Reemplazar ficha'), findsOneWidget);
      expect(find.text('Subir ficha firmada'), findsNothing);
    });

    testWidgets('a verified consent can only view the form', (tester) async {
      repo.detail = Right(_detail(consent: 'verified', evidence: true));
      await pump(tester);

      expect(find.text('Ver ficha subida'), findsOneWidget);
      expect(find.text('Reemplazar ficha'), findsNothing);
      expect(find.text('Subir ficha firmada'), findsNothing);
      expect(find.textContaining('Imprime y firma la ficha del club'),
          findsNothing);
    });

    testWidgets('a verified consent without a form shows no upload either',
        (tester) async {
      repo.detail = Right(_detail(consent: 'verified'));
      await pump(tester);

      expect(find.text('Subir ficha firmada'), findsNothing);
      expect(find.text('Ver ficha subida'), findsNothing);
    });

    testWidgets('a frozen dependent has no form card', (tester) async {
      repo.detail = Right(
        FamilyJson.detail({...detailJson(), 'frozen': true}),
      );
      await pump(tester);

      expect(find.text('Ficha de consentimiento'), findsNothing);
      expect(find.text('Subir ficha firmada'), findsNothing);
    });

    testWidgets(
        'uploading sends the file for that dependent, waits for the director '
        'and does NOT verify the consent', (tester) async {
      final server = _EvidenceRepo();
      repo = server;
      repo.detail = Right(_detail());
      await pump(tester);

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.evidenceUploads, [
        (dependentId: 'ana-1', fileName: 'ficha.pdf'),
      ]);
      expect(
        find.text('Ficha subida. Esperando la verificación del director.'),
        findsOneWidget,
        reason: 'toast',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
            'Ficha firmada subida. Esperando la verificación del director.'),
        findsOneWidget,
      );
      expect(find.text('Consentimiento pendiente'), findsWidgets);
      expect(find.text('Consentimiento verificado'), findsNothing);
    });

    testWidgets('503 shows that forms are not available yet', (tester) async {
      repo.detail = Right(_detail());
      repo.evidenceUploaded = const Left(
        ServerFailure(
          message: 'x',
          code: 503,
          errorCode: 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Las fichas de consentimiento aún no están disponibles. Inténtalo más tarde.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        '409 already verified: explains it, refreshes the detail and closes '
        'the upload', (tester) async {
      repo.detail = Right(_detail());
      repo.evidenceUploaded = const Left(
        ServerFailure(
          message: 'x',
          code: 409,
          errorCode: 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED',
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      // Meanwhile the director verified: the next read of the detail says so.
      repo.detail = Right(_detail(consent: 'verified', evidence: true));
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(find.text('La ficha ya fue verificada.'), findsWidgets);
      expect(find.text('Subir ficha firmada'), findsNothing);
      expect(find.text('Reemplazar ficha'), findsNothing);
      expect(find.text('Ver ficha subida'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a 403 scope-denied is an action error, not a sign-out',
        (tester) async {
      repo.detail = Right(_detail());
      repo.evidenceUploaded = const Left(
        AuthFailure(
          message: 'x',
          code: 403,
          errorCode: 'ACTING_FOR_SCOPE_DENIED',
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      expect(auth.switchCalls, isEmpty, reason: 'does not leave the profile');
    });

    testWidgets('viewing the form asks for a fresh signed URL', (tester) async {
      repo.detail = Right(_detail(evidence: true));
      await pump(tester);

      await tester.tap(find.text('Ver ficha subida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.evidenceReads, ['ana-1']);
      final viewer = tester.widget<SacImageViewer>(find.byType(SacImageViewer));
      expect(viewer.allowShare, isFalse);
      expect(viewer.cacheNetwork, isFalse);
    });

    testWidgets('a missing form explains it instead of opening a viewer',
        (tester) async {
      repo.detail = Right(_detail(evidence: true));
      repo.evidenceAccess = const Left(
        ServerFailure(
          message: 'x',
          code: 404,
          errorCode: 'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Ver ficha subida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Aún no se ha subido la ficha de consentimiento firmada.'),
        findsOneWidget,
      );
      expect(find.byType(SacImageViewer), findsNothing);
    });
  });

  group('view as', () {
    testWidgets('switches to the dependent', (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      await tester.tap(find.text('Ver como Ana'));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, [(id: 'ana-1', firstName: 'Ana')]);
    });
  });

  group('errors', () {
    testWidgets('not found offers to go back', (tester) async {
      repo.detail = const Left(
        ServerFailure(
          message: 'x',
          code: 404,
          errorCode: 'GUARDIANSHIP_NOT_FOUND',
        ),
      );
      await pump(tester);

      expect(find.text('No encontramos a este menor.'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
    });
  });

  group('predictLeaveOutcome', () {
    test('another human guardian wins over everything', () {
      expect(
        predictLeaveOutcome(
          _detail(club: clubPending, guardians: [guardianJson(), _other]),
        ),
        DependentOutcome.otherGuardian,
      );
    });

    test('a custodian row does not count as another guardian', () {
      expect(
        predictLeaveOutcome(
          _detail(club: clubPending, guardians: [
            guardianJson(),
            guardianJson(
              id: 'gs-9',
              userId: null,
              primary: false,
              custodian: true,
              me: false,
            ),
          ]),
        ),
        DependentOutcome.clubCustody,
      );
    });

    test('a rejected or expired request is not a live club membership', () {
      expect(
        predictLeaveOutcome(
          _detail(club: {...clubPending, 'status': 'rejected'}),
        ),
        DependentOutcome.frozen,
      );
    });

    test('an active membership keeps club custody', () {
      expect(
        predictLeaveOutcome(
          _detail(club: {...clubPending, 'status': 'active'}),
        ),
        DependentOutcome.clubCustody,
      );
    });
  });
}

/// Emula al servidor: subir la ficha marca `evidence_uploaded` en el detalle,
/// pero el consentimiento sigue pendiente.
class _EvidenceRepo extends FakeFamilyRepository {
  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String dependentId,
    required ConsentEvidenceLocalFile file,
  }) async {
    final result = await super.uploadConsentEvidence(
      dependentId: dependentId,
      file: file,
    );
    detail = Right(_detail(evidence: true));
    return result;
  }
}
