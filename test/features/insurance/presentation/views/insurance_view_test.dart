import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_view.dart';
import 'package:sacdia_app/features/insurance/presentation/widgets/insurance_skeleton.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';
import '../insurance_test_support.dart';

const _director = InsuranceAccess(
  canIssue: true,
  canReassign: true,
  canViewOrders: true,
);

Future<void> _pump(
  WidgetTester tester, {
  Future<InsuranceOverview?> Function()? overview,
  InsuranceAccess access = _director,
  List<FreeCoverage> free = const [],
}) {
  return pumpApp(
    tester,
    const InsuranceView(),
    overrides: [
      clubContextProvider.overrideWith((ref) async => testClubContext),
      insuranceAccessProvider.overrideWith((ref) async => access),
      insuranceOverviewProvider
          .overrideWith((ref) => (overview ?? () async => mockupOverview())()),
      freeCoveragesProvider.overrideWith((ref) async => free),
    ],
  );
}

const _free = FreeCoverage(
  assignmentId: 31,
  holderUserId: 'u-99',
  holderName: 'Pablo Ruiz',
);

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('summary: covered of total, missing, legend, cost and deadline',
      (tester) async {
    await _pump(tester);

    // Title in the top bar, like the other module screens; no large header.
    expect(find.text('Seguros'), findsOneWidget);
    expect(find.text('Conquistadores · año eclesiástico 2027'), findsNothing);
    expect(find.text('Con seguro 2027'), findsOneWidget);
    expect(find.textContaining('4 de 12'), findsOneWidget);
    // "faltan" counts only people with no order yet (uninsured: 3).
    expect(find.textContaining('faltan 3'), findsOneWidget);
    expect(
      find.textContaining('Asegurados 4', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('En trámite 4', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sin seguro 3', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Costo por persona'), findsOneWidget);
    expect(find.text('\$350.00'), findsOneWidget);
    expect(find.text('Pagar antes del'), findsOneWidget);
    expect(find.text('28 feb 2027'), findsOneWidget);
  });

  testWidgets('no "por vencer", "vencido", manual registration or plus',
      (tester) async {
    await _pump(tester);

    expect(find.textContaining('vencer'), findsNothing);
    expect(find.textContaining('Vencido'), findsNothing);
    expect(find.textContaining('Registrar seguro'), findsNothing);
  });

  testWidgets('to attend: free insurance, rejected receipt and receipt due',
      (tester) async {
    await _pump(tester, free: const [_free]);

    expect(find.text('POR ATENDER'), findsOneWidget);
    expect(find.text('Seguro libre de Pablo Ruiz'), findsOneWidget);
    expect(find.text('Pásalo a alguien sin seguro'), findsOneWidget);
    expect(find.text('Recibo rechazado'), findsOneWidget);
    expect(find.text('ORD20270041 · 1 persona'), findsOneWidget);
    expect(find.text('Sube el recibo'), findsOneWidget);
    expect(find.text('ORD20270044 · antes del 21 feb'), findsOneWidget);
  });

  testWidgets('people list: avatar rows with the line that matters',
      (tester) async {
    await _pump(tester);

    expect(find.text('MIEMBROS Y DIRECTIVA'), findsOneWidget);
    expect(find.text('Diego Campos'), findsOneWidget);
    // Staff: the raw role is localized and flagged as leadership.
    expect(find.text('Consejero · directiva'), findsOneWidget);
    expect(find.text('Falta pagar · 21 feb'), findsNWidgets(2));
    expect(find.text('Sube otro recibo'), findsOneWidget);
    expect(find.text('Pago enviado'), findsOneWidget);
    expect(find.text('Pagado en Guías Mayores'), findsOneWidget);
    expect(find.text('Reasignado de Ximena Lara'), findsOneWidget);
    expect(find.text('Pagado · ORD20270031'), findsNWidgets(3));
    expect(find.text('Asegurado'), findsWidgets);
    expect(find.text('Rechazado'), findsOneWidget);
  });

  testWidgets('filter chips narrow the list', (tester) async {
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Sin seguro, 3'));
    await tester.pump();

    expect(find.text('Diego Campos'), findsOneWidget);
    expect(find.text('Andrés Vidal'), findsNothing);
    expect(find.text('Tomás Aguilar'), findsNothing);
  });

  testWidgets('search finds a person without caring about accents',
      (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'andres');
    await tester.pump();

    expect(find.text('Andrés Vidal'), findsOneWidget);
    expect(find.text('Diego Campos'), findsNothing);
  });

  testWidgets('footer: "Asegurar a quienes faltan (N)" for who can issue',
      (tester) async {
    await _pump(tester);

    expect(find.text('Asegurar a quienes faltan (3)'), findsOneWidget);
  });

  testWidgets('read-only: no footer and an explanation', (tester) async {
    await _pump(tester, access: InsuranceAccess.readOnly);

    expect(find.textContaining('Asegurar a quienes faltan'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(
        'Solo director, secretario y tesorero pueden asegurar o reasignar.',
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The list is still readable.
    expect(find.text('Diego Campos'), findsOneWidget);
    // Nothing to attend without permission to act on it.
    expect(find.text('POR ATENDER'), findsNothing);
  });

  testWidgets('start of year: 0 of N, message and a footer for the whole club',
      (tester) async {
    await _pump(
      tester,
      overview: () async => InsuranceOverview(
        // The banner only shows in the first weeks of the year.
        year: InsuranceYear(id: 9, label: '2027', startDate: DateTime.now()),
        cycle: testCycle(),
        counts: const InsuranceCounts(total: 12, uninsured: 12),
        freeCoveragesCount: 0,
        people: [
          for (var i = 0; i < 12; i++) uninsuredPerson('p$i', 'Persona $i'),
        ],
      ),
    );

    expect(find.textContaining('0 de 12'), findsOneWidget);
    expect(find.text('Empezó el año 2027'), findsOneWidget);
    expect(
      find.text(
        'El seguro del año pasado terminó. Asegura a tu club antes del 28 feb.',
      ),
      findsOneWidget,
    );
    expect(find.text('Asegurar al club (12)'), findsOneWidget);
  });

  testWidgets('everyone covered: says so and offers no insure button',
      (tester) async {
    await _pump(
      tester,
      overview: () async => InsuranceOverview(
        year: testYear,
        cycle: testCycle(),
        counts: const InsuranceCounts(total: 12, covered: 12),
        freeCoveragesCount: 0,
        people: const [
          InsurancePerson(
            userId: 'a',
            name: 'Ana',
            status: InsurancePersonStatus.covered,
          ),
        ],
      ),
    );

    expect(find.textContaining('12 de 12'), findsOneWidget);
    expect(find.text('Todo el club está asegurado'), findsOneWidget);
    expect(find.textContaining('año eclesiástico 2028'), findsOneWidget);
    expect(find.textContaining('Asegurar'), findsNothing);
  });

  testWidgets('no cost published: explains and has no insure button',
      (tester) async {
    await _pump(
      tester,
      overview: () async => const InsuranceOverview(
        year: testYear,
        cycle: null,
        counts: InsuranceCounts(total: 12, uninsured: 12),
        freeCoveragesCount: 0,
        people: [],
      ),
    );

    expect(find.text('Aún no hay costo para 2027'), findsOneWidget);
    expect(find.textContaining('todavía no publica el costo'), findsOneWidget);
    expect(find.textContaining('Asegurar a'), findsNothing);
  });

  testWidgets('loading shows a skeleton, not a spinner', (tester) async {
    final never = Completer<InsuranceOverview?>();
    tester.view.physicalSize = const Size(800, 1800);
    await tester.pumpWidget(
      wrapApp(
        const InsuranceView(),
        overrides: [
          clubContextProvider.overrideWith((ref) async => testClubContext),
          insuranceAccessProvider.overrideWith((ref) async => _director),
          insuranceOverviewProvider.overrideWith((ref) => never.future),
          freeCoveragesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(InsuranceSkeleton), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('offline: says what happened and retries', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      overview: () async {
        calls++;
        if (calls == 1) {
          throw const ConnectionFailure(message: 'offline');
        }
        return mockupOverview();
      },
    );

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await settle(tester);

    expect(calls, 2);
    expect(find.text('Con seguro 2027'), findsOneWidget);
  });
}
