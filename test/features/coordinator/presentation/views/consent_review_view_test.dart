import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/consent_review_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/consent_review_view.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

import '../../../members/members_test_support.dart';
import '../../coordinator_test_support.dart';

Map<String, Object?> _item(
  String id,
  int sectionId,
  String name, {
  String club = 'Club Águilas',
  String type = 'Conquistadores',
  String? district = 'Distrito Norte',
}) =>
    pendingItemJson(
      id: id,
      sectionId: sectionId,
      name: name,
      club: club,
      type: type,
      district: district,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeCoordinatorRepository repo;
  late FakeMembersRepository members;

  setUp(() {
    repo = FakeCoordinatorRepository();
    members = FakeMembersRepository();
  });

  Future<void> open(WidgetTester tester) async {
    await pumpMembersApp(
      tester,
      overrides: [
        coordinatorRepositoryProvider.overrideWithValue(repo),
        membersRepositoryProvider.overrideWithValue(members),
      ],
      home: const ConsentReviewView(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the forms oldest-first with club · type · district',
      (tester) async {
    repo.results = [
      Right(
        pendingPage(
          items: [
            _item('a', 1, 'Ana'),
            _item('b', 2, 'Bruno',
                club: 'Club Leones', type: 'Aventureros', district: null),
          ],
          bySection: [
            pendingSectionJson(sectionId: 1, count: 1),
            pendingSectionJson(
                sectionId: 2,
                count: 1,
                club: 'Club Leones',
                type: 'Aventureros',
                district: null),
          ],
        ),
      ),
    ];
    await open(tester);

    expect(find.text('Ana Pérez Soto'), findsOneWidget);
    expect(find.text('Bruno Pérez Soto'), findsOneWidget);
    expect(
      find.text('Club Águilas · Conquistadores · Distrito Norte'),
      findsNWidgets(2), // the row and its summary line
    );
    expect(find.text('Club Leones · Aventureros'), findsNWidgets(2));
    // Server order is kept: Ana above Bruno.
    expect(tester.getTopLeft(find.text('Ana Pérez Soto')).dy,
        lessThan(tester.getTopLeft(find.text('Bruno Pérez Soto')).dy));
    expect(find.text('Menor · consentimiento pendiente'), findsNWidgets(2));
  });

  testWidgets('the header shows the total and a count per section',
      (tester) async {
    repo.results = [
      Right(
        pendingPage(
          items: [_item('a', 1, 'Ana')],
          total: 3,
          bySection: [
            pendingSectionJson(sectionId: 1, count: 2),
            pendingSectionJson(
                sectionId: 2,
                count: 1,
                club: 'Club Leones',
                type: 'Aventureros',
                district: null),
          ],
        ),
      ),
    ];
    await open(tester);

    expect(find.text('3 fichas por verificar'), findsOneWidget);
    expect(find.text('2 fichas por verificar'), findsOneWidget);
    expect(find.text('1 ficha por verificar'), findsOneWidget);
    expect(find.text('Club Leones · Aventureros'), findsOneWidget);
  });

  testWidgets('offers verify only: no approve and no reject', (tester) async {
    repo.results = [
      Right(pendingPage(items: [_item('a', 1, 'Ana')])),
    ];
    await open(tester);

    expect(find.bySemanticsLabel('Verificar consentimiento'), findsOneWidget);
    expect(find.bySemanticsLabel('Aprobar'), findsNothing);
    expect(find.bySemanticsLabel('Rechazar'), findsNothing);
  });

  testWidgets(
      'opens the verification in verify-only mode, sends approve=false, '
      'removes the form and decrements the total and its section',
      (tester) async {
    repo.results = [
      Right(
        pendingPage(
          items: [
            _item('a', 1, 'Ana'),
            _item('b', 2, 'Bruno',
                club: 'Club Leones', type: 'Aventureros', district: null),
          ],
          total: 2,
          bySection: [
            pendingSectionJson(sectionId: 1, count: 1),
            pendingSectionJson(
                sectionId: 2,
                count: 1,
                club: 'Club Leones',
                type: 'Aventureros',
                district: null),
          ],
        ),
      ),
    ];
    members.verifyResults = [
      const Right(
        ConsentVerificationResult(guardianshipId: 'gs-a', approved: false),
      ),
    ];
    await open(tester);
    expect(find.text('2 fichas por verificar'), findsOneWidget);

    await tester.tap(find.text('Ana Pérez Soto'));
    await tester.pumpAndSettle();

    final view = tester.widget<ConsentVerificationView>(
      find.byType(ConsentVerificationView),
    );
    expect(view.canApprove, isFalse);
    expect(view.request.assignmentId, '1/membership-requests/a');
    expect(find.text('Confirmar y aprobar'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar verificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(members.verifyCalls, [
      (assignmentId: '1/membership-requests/a', approve: false),
    ]);
    expect(members.approveCalls, isEmpty);
    expect(find.byType(ConsentVerificationView), findsNothing);
    expect(find.text('Ana Pérez Soto'), findsNothing);
    expect(find.text('Bruno Pérez Soto'), findsOneWidget);
    // Total decremented, emptied section left the summary.
    expect(find.text('1 ficha por verificar'), findsNWidgets(2));
    expect(find.text('2 fichas por verificar'), findsNothing);
    expect(find.text('Club Águilas · Conquistadores · Distrito Norte'),
        findsNothing);
    // No extra call to the server: the removal is local.
    expect(repo.calls, hasLength(1));
  });

  testWidgets('a form that is no longer pending (404) leaves the queue',
      (tester) async {
    repo.results = [
      Right(pendingPage(items: [_item('a', 1, 'Ana'), _item('b', 2, 'Bruno')])),
    ];
    members.verifyResults = [
      const Left(
        ServerFailure(code: 404, message: 'x', errorCode: 'MR_NOT_FOUND'),
      ),
    ];
    await open(tester);

    await tester.tap(find.text('Ana Pérez Soto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar verificación'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentVerificationView), findsNothing);
    expect(find.text('Ana Pérez Soto'), findsNothing);
    expect(find.text('Bruno Pérez Soto'), findsOneWidget);
  });

  testWidgets('backing out of the verification keeps the form in the list',
      (tester) async {
    repo.results = [
      Right(pendingPage(items: [_item('a', 1, 'Ana')])),
    ];
    await open(tester);

    await tester.tap(find.text('Ana Pérez Soto'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ConsentVerificationView))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez Soto'), findsOneWidget);
    expect(members.verifyCalls, isEmpty);
  });

  group('pagination', () {
    testWidgets('"Cargar más" asks for the next offset and appends',
        (tester) async {
      repo.results = [
        Right(pendingPage(items: [_item('a', 1, 'Ana')], total: 2)),
        Right(
          pendingPage(items: [_item('b', 1, 'Bruno')], total: 2, offset: 1),
        ),
      ];
      await open(tester);

      expect(find.text('Bruno Pérez Soto'), findsNothing);
      await tester.ensureVisible(find.text('Cargar más'));
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(repo.calls.last.offset, 1);
      expect(find.text('Ana Pérez Soto'), findsOneWidget);
      expect(find.text('Bruno Pérez Soto'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('no "Cargar más" when everything is loaded', (tester) async {
      repo.results = [
        Right(pendingPage(items: [_item('a', 1, 'Ana')], total: 1)),
      ];
      await open(tester);

      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('a failed page says so and can be retried', (tester) async {
      repo.results = [
        Right(pendingPage(items: [_item('a', 1, 'Ana')], total: 2)),
        const Left(ServerFailure(message: 'x', code: 500)),
        Right(
          pendingPage(items: [_item('b', 1, 'Bruno')], total: 2, offset: 1),
        ),
      ];
      await open(tester);

      await tester.ensureVisible(find.text('Cargar más'));
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar más fichas.'), findsOneWidget);
      expect(find.text('Ana Pérez Soto'), findsOneWidget);

      await tester.ensureVisible(find.text('Cargar más'));
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar más fichas.'), findsNothing);
      expect(find.text('Bruno Pérez Soto'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('nothing waiting: says so', (tester) async {
      repo.results = [Right(pendingPage(items: const []))];
      await open(tester);

      expect(find.text('No hay fichas por verificar'), findsOneWidget);
      expect(
        find.text(
          'Ninguna de tus secciones tiene fichas esperando verificación.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('403 GUARD_CLUB_SCOPE_REQUIRED: no assigned sections',
        (tester) async {
      repo.results = [const Left(noSectionsFailure)];
      await open(tester);

      expect(find.text('No tienes secciones asignadas'), findsOneWidget);
      expect(find.text('No hay fichas por verificar'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('403 GUARD_PERMISSION_DENIED: explains it is not for you',
        (tester) async {
      repo.results = [const Left(permissionDeniedFailure)];
      await open(tester);

      expect(find.text('No puedes verificar fichas'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a server error shows an error with retry', (tester) async {
      repo.results = [
        const Left(ServerFailure(message: 'x', code: 500)),
        Right(pendingPage(items: [_item('a', 1, 'Ana')])),
      ];
      await open(tester);

      expect(find.text('No se pudieron cargar las fichas.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Pérez Soto'), findsOneWidget);
      expect(repo.calls, hasLength(2));
    });

    testWidgets('the refresh button reloads the queue from the start',
        (tester) async {
      repo.results = [
        Right(pendingPage(items: [_item('a', 1, 'Ana')])),
        Right(pendingPage(items: [_item('b', 1, 'Bruno')])),
      ];
      await open(tester);

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();

      expect(repo.calls.last.offset, 0);
      expect(find.text('Ana Pérez Soto'), findsNothing);
      expect(find.text('Bruno Pérez Soto'), findsOneWidget);
    });

    testWidgets('shows a loader while the first page is in flight',
        (tester) async {
      repo.results = [Right(pendingPage(items: const []))];
      repo.gate = Completer<void>();
      await pumpMembersApp(
        tester,
        overrides: [
          coordinatorRepositoryProvider.overrideWithValue(repo),
          membersRepositoryProvider.overrideWithValue(members),
        ],
        home: const ConsentReviewView(),
      );

      expect(find.text('No hay fichas por verificar'), findsNothing);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('No hay fichas por verificar'), findsOneWidget);
    });
  });

  test('the notifier page size is the documented bound', () {
    expect(ConsentReviewNotifier.pageSize, 50);
  });
}
