import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
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
        find.text('El club quedará a cargo de Ana mientras tanto.'),
        findsOneWidget,
        reason: 'snackbar with the outcome the server returned',
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
