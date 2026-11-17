import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_conflict.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/views/issue_insurance_view.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:dartz/dartz.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';
import '../insurance_test_support.dart';

const _director = InsuranceAccess(canIssue: true, canReassign: true);

Future<FakePaymentOrdersRepo> _pump(
  WidgetTester tester, {
  InsuranceAccess access = _director,
  InsuranceOverview? overview,
}) async {
  final repo = FakePaymentOrdersRepo();
  await pumpApp(
    tester,
    const IssueInsuranceView(),
    overrides: [
      insuranceAccessProvider.overrideWith((ref) async => access),
      insuranceOverviewProvider
          .overrideWith((ref) async => overview ?? mockupOverview()),
      paymentOrdersRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return repo;
}

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('summary of the insurance and uninsured people preselected',
      (tester) async {
    await _pump(tester);

    expect(find.text('Asegurar'), findsOneWidget);
    expect(find.text('Seguro anual 2027'), findsOneWidget);
    expect(find.text('\$350.00'), findsOneWidget);
    expect(find.text('Todo el año eclesiástico 2027'), findsOneWidget);
    expect(find.text('SIN SEGURO'), findsOneWidget);
    expect(find.text('Diego Campos'), findsOneWidget);
    expect(find.text('Consejero · directiva'), findsOneWidget);
    // All three come selected: 3 x $350.00.
    expect(
      find.text('Emitir orden · 3 personas · \$1,050.00'),
      findsOneWidget,
    );
    expect(find.text('Quitar todos'), findsOneWidget);
  });

  testWidgets('people who cannot be added show why, with no checkbox',
      (tester) async {
    await _pump(tester);

    expect(find.text('NO SE PUEDEN AGREGAR'), findsOneWidget);
    expect(
      find.text('Ya tiene seguro · se pagó en Guías Mayores'),
      findsOneWidget,
    );
    expect(find.text('Falta pagar · 21 feb'), findsNWidgets(2));
    expect(find.text('Sube otro recibo'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue-person-u-8')), findsNothing);
    expect(find.byKey(const ValueKey('issue-blocked-u-8')), findsOneWidget);
    expect(
      find.text(
          'Nadie puede estar en dos órdenes ni tener dos seguros en el año.'),
      findsOneWidget,
    );
  });

  testWidgets('removing someone updates the count and the total',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('issue-person-u-1')));
    await tester.pump();

    expect(
      find.text('Emitir orden · 2 personas · \$700.00'),
      findsOneWidget,
    );
    await tester.tap(find.text('Elegir todos'));
    await tester.pump();
    expect(
      find.text('Emitir orden · 3 personas · \$1,050.00'),
      findsOneWidget,
    );
  });

  testWidgets('with nobody selected the button is disabled', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Quitar todos'));
    await tester.pump();
    await tester.tap(find.textContaining('Emitir orden · 0 personas'));
    await tester.pump();

    expect(find.text('¿Emitir la orden?'), findsNothing);
    expect(repo.keys, isEmpty);
  });

  testWidgets('confirm sheet explains how to pay and the deadline',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.textContaining('Emitir orden · 3 personas'));
    await settle(tester);

    expect(find.text('¿Emitir la orden?'), findsOneWidget);
    expect(find.textContaining('Orden de \$1,050.00 por 3 personas.'),
        findsOneWidget);
    expect(find.textContaining('caja del campo'), findsOneWidget);
    expect(find.textContaining('pastor de distrito'), findsOneWidget);
    expect(find.textContaining('transferencia'), findsOneWidget);
    expect(find.textContaining('28 feb'), findsOneWidget);
  });

  testWidgets('cancelling the confirm sheet sends nothing', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.textContaining('Emitir orden · 3 personas'));
    await settle(tester);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);

    expect(find.text('¿Emitir la orden?'), findsNothing);
    expect(repo.keys, isEmpty);
  });

  testWidgets('conflict: explains who, drops them and offers the rest',
      (tester) async {
    final repo = await _pump(tester);
    repo.createResult = const Left(
      DuplicateBeneficiariesFailure(
        message: 'dup',
        code: 409,
        conflicts: [
          InsuranceConflict(
            userId: 'u-2',
            name: 'Valeria Ríos',
            reason: InsuranceConflictReason.alreadyCovered,
            sectionName: 'Aventureros',
          ),
        ],
      ),
    );

    await tester.tap(find.textContaining('Emitir orden · 3 personas'));
    await settle(tester);
    await tester.tap(find.text('Emitir orden').last);
    await settle(tester);

    expect(repo.sentIds.single, ['u-1', 'u-2', 'u-3']);
    expect(find.text('Valeria Ríos ya tiene seguro'), findsOneWidget);
    expect(
      find.textContaining(
          'Se aseguró en Aventureros mientras armabas la orden.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('la orden queda con 2 personas por \$700.00'),
      findsOneWidget,
    );
    expect(find.text('Emitir con 2 personas'), findsOneWidget);
    expect(find.text('Revisar la lista'), findsOneWidget);
  });

  testWidgets('conflict: "Emitir con 2 personas" retries without them',
      (tester) async {
    final repo = await _pump(tester);
    repo.createResult = const Left(
      DuplicateBeneficiariesFailure(
        message: 'dup',
        conflicts: [
          InsuranceConflict(
            userId: 'u-2',
            name: 'Valeria Ríos',
            reason: InsuranceConflictReason.inLiveOrder,
            folio: 'ORD9',
          ),
        ],
      ),
    );

    await tester.tap(find.textContaining('Emitir orden · 3 personas'));
    await settle(tester);
    await tester.tap(find.text('Emitir orden').last);
    await settle(tester);

    expect(find.text('Valeria Ríos ya está en una orden'), findsOneWidget);
    expect(find.textContaining('Ya está en la orden ORD9.'), findsOneWidget);

    // The retry succeeds only without the conflicting person; the success
    // path navigates, which needs a router, so assert on the request.
    repo.createResult = Left(const ServerFailure(message: 'stop', code: 500));
    await tester.tap(find.text('Emitir con 2 personas'));
    await settle(tester);

    expect(repo.sentIds, hasLength(2));
    expect(repo.sentIds[1], ['u-1', 'u-3']);
    expect(repo.keys[0], isNot(repo.keys[1]));
  });

  testWidgets('read-only users cannot reach the issue screen', (tester) async {
    await _pump(tester, access: InsuranceAccess.readOnly);

    expect(find.text('Sin permiso'), findsOneWidget);
    expect(find.textContaining('Emitir orden'), findsNothing);
  });

  testWidgets('no cost published: nothing to issue', (tester) async {
    await _pump(
      tester,
      overview: const InsuranceOverview(
        year: testYear,
        cycle: null,
        counts: InsuranceCounts(total: 2, uninsured: 2),
        freeCoveragesCount: 0,
        people: [],
      ),
    );

    expect(find.text('Aún no hay costo para 2027'), findsOneWidget);
    expect(find.textContaining('Emitir orden'), findsNothing);
  });
}
