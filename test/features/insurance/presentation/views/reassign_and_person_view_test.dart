import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_person_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/reassign_insurance_view.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';
import '../insurance_test_support.dart';

const _director = InsuranceAccess(
  canIssue: true,
  canReassign: true,
  canViewOrders: true,
);

final _free = FreeCoverage(
  assignmentId: 31,
  holderUserId: 'u-99',
  holderName: 'Pablo Ruiz',
  orderFolio: 'ORD20270031',
  leftAt: DateTime(2027, 2, 10),
);

Future<FakePaymentOrdersRepo> _pumpReassign(
  WidgetTester tester, {
  List<FreeCoverage>? free,
  int? assignmentId,
  InsuranceAccess access = _director,
  InsuranceOverview? overview,
}) async {
  final repo = FakePaymentOrdersRepo();
  await pumpApp(
    tester,
    ReassignInsuranceView(assignmentId: assignmentId),
    overrides: [
      insuranceAccessProvider.overrideWith((ref) async => access),
      insuranceOverviewProvider
          .overrideWith((ref) async => overview ?? mockupOverview()),
      freeCoveragesProvider.overrideWith((ref) async => free ?? [_free]),
      paymentOrdersRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return repo;
}

Future<void> _pumpPerson(
  WidgetTester tester,
  String userId, {
  List<PaymentOrder> orders = const [],
}) {
  return pumpApp(
    tester,
    InsurancePersonView(userId: userId),
    overrides: [
      insuranceAccessProvider.overrideWith((ref) async => _director),
      insuranceOverviewProvider.overrideWith((ref) async => mockupOverview()),
      paymentOrdersListProvider.overrideWith((ref, filter) async => orders),
    ],
  );
}

PaymentOrder _order(String folio, String id) => PaymentOrder(
      orderId: id,
      purpose: PaymentOrderPurpose.insurance,
      folioReference: folio,
      currency: 'MXN',
      unitCostCentavos: 35000,
      totalCentavos: 35000,
      status: PaymentOrderStatus.approved,
      expiresAt: DateTime(2027, 3, 1),
      createdAt: DateTime(2027, 2, 1),
    );

void main() {
  setUpAll(initInvestitureTestEnv);

  group('Reasignar', () {
    testWidgets('free insurance box and the people without insurance',
        (tester) async {
      await _pumpReassign(tester);

      expect(find.text('Reasignar seguro'), findsOneWidget);
      expect(find.text('Seguro libre'), findsOneWidget);
      expect(find.text('Pablo Ruiz'), findsOneWidget);
      expect(find.text('Dejó el club el 10 feb'), findsOneWidget);
      expect(find.text('Todo el año eclesiástico 2027'), findsOneWidget);
      expect(find.text('Se pagó en'), findsOneWidget);
      expect(find.text('ORD20270031'), findsOneWidget);
      expect(find.text('¿A QUIÉN PASA?'), findsOneWidget);
      // Only uninsured people who are not in an order.
      expect(find.text('Diego Campos'), findsOneWidget);
      expect(find.text('Valeria Ríos'), findsOneWidget);
      expect(find.text('Tomás Aguilar'), findsNothing);
      expect(find.text('Andrés Vidal'), findsNothing);
      expect(
        find.text(
            'Solo aparecen quienes no tienen seguro ni están en una orden.'),
        findsOneWidget,
      );
    });

    testWidgets('the first one is picked and the footer names them',
        (tester) async {
      await _pumpReassign(tester);

      expect(find.text('Pasar a Diego'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reassign-person-u-2')));
      await tester.pump();

      expect(find.text('Pasar a Valeria'), findsOneWidget);
    });

    testWidgets('confirm sheet says what happens and who is recorded',
        (tester) async {
      await _pumpReassign(tester);

      await tester.tap(find.text('Pasar a Diego'));
      await settle(tester);

      expect(find.text('¿Pasar el seguro a Diego Campos?'), findsOneWidget);
      expect(
        find.text(
          'El seguro cubre a Diego Campos el resto del año eclesiástico 2027. '
          'Pablo Ruiz pierde la cobertura. Queda registrado que tú lo hiciste.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pasar seguro'), findsOneWidget);
    });

    testWidgets('cancelling the sheet sends nothing', (tester) async {
      final repo = await _pumpReassign(tester);

      await tester.tap(find.text('Pasar a Diego'));
      await settle(tester);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      expect(repo.reassignCalls, 0);
    });

    testWidgets('nobody without insurance: explains, no footer',
        (tester) async {
      await _pumpReassign(
        tester,
        overview: InsuranceOverview(
          year: testYear,
          cycle: testCycle(),
          counts: const InsuranceCounts(total: 1, covered: 1),
          freeCoveragesCount: 1,
          people: const [
            InsurancePerson(
              userId: 'a',
              name: 'Ana',
              status: InsurancePersonStatus.covered,
            ),
          ],
        ),
      );

      expect(find.textContaining('No hay nadie sin seguro'), findsOneWidget);
      expect(find.textContaining('Pasar a'), findsNothing);
    });

    testWidgets('several free insurances: pick which one first',
        (tester) async {
      await _pumpReassign(
        tester,
        free: [
          _free,
          const FreeCoverage(
            assignmentId: 32,
            holderUserId: 'u-98',
            holderName: 'Ximena Lara',
          ),
        ],
      );

      expect(find.text('Elige qué seguro pasar'.toUpperCase()), findsOneWidget);
      expect(find.text('Pablo Ruiz'), findsOneWidget);
      expect(find.text('Ximena Lara'), findsOneWidget);
      expect(find.textContaining('Pasar a'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('reassign-free-32')));
      await tester.pump();

      expect(find.text('¿A QUIÉN PASA?'), findsOneWidget);
      expect(find.text('Pasar a Diego'), findsOneWidget);
    });

    testWidgets('an assignment id picks that insurance', (tester) async {
      await _pumpReassign(
        tester,
        assignmentId: 32,
        free: [
          _free,
          const FreeCoverage(
            assignmentId: 32,
            holderUserId: 'u-98',
            holderName: 'Ximena Lara',
          ),
        ],
      );

      expect(find.text('Ximena Lara'), findsOneWidget);
      expect(find.text('Pablo Ruiz'), findsNothing);
    });

    testWidgets('no free insurance: says so', (tester) async {
      await _pumpReassign(tester, free: const []);

      expect(find.text('No hay seguros libres'), findsOneWidget);
    });

    testWidgets('without permission nothing can be reassigned', (tester) async {
      await _pumpReassign(tester, access: InsuranceAccess.readOnly);

      expect(find.text('Sin permiso'), findsOneWidget);
      expect(find.textContaining('Pasar a'), findsNothing);
    });
  });

  group('Seguro de la persona', () {
    testWidgets('paid here: year, where, order and approval', (tester) async {
      await _pumpPerson(
        tester,
        'u-10',
        orders: [_order('ORD20270031', 'o-31')],
      );

      expect(find.text('Andrés Vidal'), findsOneWidget);
      expect(find.text('Asegurado todo 2027'), findsOneWidget);
      expect(
        find.text('Cubierto hasta que empiece el año eclesiástico 2028.'),
        findsOneWidget,
      );
      expect(find.text('Año eclesiástico'), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
      expect(find.text('Orden'), findsOneWidget);
      expect(find.text('ORD20270031'), findsOneWidget);
      // No policy, insurer or amount fields.
      expect(find.textContaining('póliza'), findsNothing);
      expect(find.textContaining('Aseguradora'), findsNothing);
    });

    testWidgets('paid in another section: says where, order does not open',
        (tester) async {
      await _pumpPerson(
        tester,
        'u-8',
        orders: [_order('ORD20270012', 'o-12')],
      );

      expect(find.text('Asegurado en otra sección'), findsOneWidget);
      expect(
        find.text(
          'Su seguro 2027 se pagó en Guías Mayores · Club Orión. No necesita otro.',
        ),
        findsOneWidget,
      );
      expect(find.text('Guías Mayores · Club Orión'), findsWidgets);
      expect(find.text('ORD20270012'), findsOneWidget);
      // The order belongs to another section: no chevron next to it.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('insurance-person-details')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('reassigned: from whom, by whom and the original order',
        (tester) async {
      await _pumpPerson(tester, 'u-9');

      expect(find.text('Asegurado todo 2027'), findsOneWidget);
      expect(
        find.text(
            'Recibió el seguro que Ximena Lara dejó libre al salir del club.'),
        findsOneWidget,
      );
      expect(find.text('Reasignado de'), findsOneWidget);
      expect(find.text('Ximena Lara'), findsWidgets);
    });

    testWidgets('unknown person: a clear message', (tester) async {
      await _pumpPerson(tester, 'nobody');

      expect(find.text('No encontramos a esta persona'), findsOneWidget);
    });
  });
}
