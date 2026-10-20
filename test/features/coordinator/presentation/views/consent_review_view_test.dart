import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/consent_review_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/consent_review_view.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

import '../../../members/members_test_support.dart';

CoordinatorScope _scope(int count) => CoordinatorScope(
      isCoordinator: true,
      clubSectionIds: [for (var i = 1; i <= count; i++) i],
      sections: [
        for (var i = 1; i <= count; i++)
          CoordinatorSectionScope(
            clubSectionId: i,
            name: 'Conquistadores',
            clubTypeId: 2,
            clubTypeName: 'Conquistadores',
            clubId: 100 + i,
            clubName: 'Club $i',
          ),
      ],
    );

JoinRequest _minor(int sectionId, String name) => JoinRequest(
      assignmentId: '$sectionId/membership-requests/req-$sectionId',
      userId: 'user-$sectionId',
      name: name,
      paternalSurname: 'Pérez',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
      consent: const JoinRequestConsent(
        guardianshipId: 'gs-1',
        status: JoinRequestConsentStatus.pending,
        evidenceUploaded: true,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  Future<void> open(WidgetTester tester, {int sections = 3}) async {
    await pumpMembersApp(
      tester,
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        coordinatorScopeProvider.overrideWith(
          (ref) async => _scope(sections),
        ),
      ],
      home: const ConsentReviewView(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the minors by section and club, skipping empty sections',
      (tester) async {
    repo.requestsBySection[1] = Right([_minor(1, 'Ana')]);
    repo.requestsBySection[3] = Right([_minor(3, 'Bruno')]);
    await open(tester);

    expect(find.text('Club 1 · Conquistadores'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Club 3 · Conquistadores'), findsOneWidget);
    expect(find.text('Bruno Pérez'), findsOneWidget);
    expect(find.text('Club 2 · Conquistadores'), findsNothing);
    expect(find.text('Menor · consentimiento pendiente'), findsNWidgets(2));
  });

  testWidgets('offers verify only: no approve and no reject', (tester) async {
    repo.requestsBySection[1] = Right([_minor(1, 'Ana')]);
    await open(tester);

    expect(find.bySemanticsLabel('Verificar consentimiento'), findsOneWidget);
    expect(find.bySemanticsLabel('Aprobar'), findsNothing);
    expect(find.bySemanticsLabel('Rechazar'), findsNothing);
  });

  testWidgets(
      'opens the verification in verify-only mode, sends approve=false and '
      'removes the verified form', (tester) async {
    repo.requestsBySection[1] = Right([_minor(1, 'Ana')]);
    repo.requestsBySection[2] = Right([_minor(2, 'Bruno')]);
    repo.verifyResults = [
      const Right(
        ConsentVerificationResult(guardianshipId: 'gs-1', approved: false),
      ),
    ];
    await open(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    final view = tester.widget<ConsentVerificationView>(
      find.byType(ConsentVerificationView),
    );
    expect(view.canApprove, isFalse);
    expect(view.request.assignmentId, '1/membership-requests/req-1');
    expect(find.text('Confirmar y aprobar'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar verificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(repo.verifyCalls, [
      (assignmentId: '1/membership-requests/req-1', approve: false),
    ]);
    expect(repo.approveCalls, isEmpty);
    expect(find.byType(ConsentVerificationView), findsNothing);
    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Club 1 · Conquistadores'), findsNothing);
    expect(find.text('Bruno Pérez'), findsOneWidget);
  });

  testWidgets('backing out of the verification keeps the form in the list',
      (tester) async {
    repo.requestsBySection[1] = Right([_minor(1, 'Ana')]);
    await open(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ConsentVerificationView))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(repo.verifyCalls, isEmpty);
  });

  testWidgets('a section outside the scope (403) is dropped with a notice',
      (tester) async {
    repo.requestsBySection[1] = const Left(
      AuthFailure(
        message: 'x',
        code: 403,
        errorCode: 'GUARD_CLUB_SCOPE_REQUIRED',
      ),
    );
    repo.requestsBySection[2] = Right([_minor(2, 'Bruno')]);
    await open(tester);

    expect(find.text('Bruno Pérez'), findsOneWidget);
    expect(
      find.text('Ya no tienes acceso a 1 sección; se omitió.'),
      findsOneWidget,
    );
    // Not treated as a failure: nothing to retry.
    expect(find.text('Reintentar esas secciones'), findsNothing);
  });

  testWidgets('a failed section can be retried', (tester) async {
    repo.requestsBySection[1] =
        const Left(ServerFailure(message: 'x', code: 500));
    repo.requestsBySection[2] = Right([_minor(2, 'Bruno')]);
    await open(tester);

    expect(find.text('No se pudo revisar 1 sección.'), findsOneWidget);

    repo.requestsBySection[1] = Right([_minor(1, 'Ana')]);
    await tester.tap(find.text('Reintentar esas secciones'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo revisar 1 sección.'), findsNothing);
    expect(find.text('Ana Pérez'), findsOneWidget);
  });

  testWidgets('with many sections it checks a page and loads more on demand',
      (tester) async {
    repo.requestsBySection[8] = Right([_minor(8, 'Hugo')]);
    await open(tester, sections: 8);

    expect(repo.joinRequestSectionCalls, hasLength(5));
    expect(find.text('Revisadas 5 de 8 secciones'), findsOneWidget);
    expect(find.text('Hugo Pérez'), findsNothing);

    await tester.ensureVisible(find.text('Revisar más secciones'));
    await tester.tap(find.text('Revisar más secciones'));
    await tester.pumpAndSettle();

    expect(repo.joinRequestSectionCalls, hasLength(8));
    expect(find.text('Hugo Pérez'), findsOneWidget);
    expect(find.text('Revisar más secciones'), findsNothing);
  });

  testWidgets('nothing waiting: says so', (tester) async {
    await open(tester);

    expect(find.text('No hay fichas por verificar'), findsOneWidget);
    expect(
      find.text(
        'Ninguna de las secciones revisadas tiene fichas esperando verificación.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unreadable scope shows an error with retry', (tester) async {
    await pumpMembersApp(
      tester,
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        coordinatorScopeProvider.overrideWith(
          (ref) async => throw Exception('network'),
        ),
      ],
      home: const ConsentReviewView(),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar tus secciones.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  test('the notifier page size is the documented bound', () {
    expect(ConsentReviewNotifier.sectionsPerPage, 5);
  });
}
