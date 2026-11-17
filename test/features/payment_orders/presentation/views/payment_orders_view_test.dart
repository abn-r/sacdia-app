import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/payment_orders_view.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';

PaymentOrder _order(
  String folio,
  PaymentOrderStatus status, {
  int people = 1,
}) =>
    PaymentOrder(
      orderId: folio,
      purpose: PaymentOrderPurpose.insurance,
      folioReference: folio,
      currency: 'MXN',
      unitCostCentavos: 35000,
      totalCentavos: 35000 * people,
      status: status,
      expiresAt: DateTime(2027, 2, 21),
      createdAt: DateTime(2027, 2, 1),
      lines: [
        for (var i = 0; i < people; i++)
          PaymentOrderLine(
            lineId: '$folio-$i',
            sequence: i + 1,
            beneficiaryUserId: '$folio-u$i',
            unitCostCentavos: 35000,
          ),
      ],
    );

Future<void> _pump(WidgetTester tester, List<PaymentOrder> orders) {
  return pumpApp(
    tester,
    const PaymentOrdersView(purpose: PaymentOrderPurpose.insurance),
    overrides: [
      paymentOrdersListProvider.overrideWith((ref, filter) async => orders),
      pendingPaymentObligationsProvider
          .overrideWith((ref) async => const <PaymentObligation>[]),
    ],
  );
}

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('groups orders: Por atender, En revisión and Cerradas',
      (tester) async {
    await _pump(tester, [
      _order('ORD41', PaymentOrderStatus.proofRejected),
      _order('ORD44', PaymentOrderStatus.issued, people: 2),
      _order('ORD39', PaymentOrderStatus.proofSubmitted),
      _order('ORD31', PaymentOrderStatus.approved, people: 5),
      _order('ORD27', PaymentOrderStatus.cancelled, people: 2),
    ]);

    expect(find.text('Órdenes de pago'), findsOneWidget);
    expect(find.text('POR ATENDER'), findsOneWidget);
    expect(find.text('EN REVISIÓN'), findsOneWidget);
    expect(find.text('CERRADAS'), findsOneWidget);

    double y(String folio) => tester.getTopLeft(find.text(folio)).dy;
    expect(y('ORD41'), lessThan(y('ORD39')));
    expect(y('ORD44'), lessThan(y('ORD39')));
    expect(y('ORD39'), lessThan(y('ORD31')));
    expect(y('ORD31'), lessThan(y('ORD27')));

    expect(find.text('1 persona · \$350.00'), findsNWidgets(2));
    expect(find.text('2 personas · \$700.00 · vence 21 feb'), findsOneWidget);
    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text('Emitida'), findsOneWidget);
    expect(find.text('En revisión'), findsWidgets);
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('empty groups are not drawn', (tester) async {
    await _pump(tester, [_order('ORD31', PaymentOrderStatus.approved)]);

    expect(find.text('POR ATENDER'), findsNothing);
    expect(find.text('EN REVISIÓN'), findsNothing);
    expect(find.text('CERRADAS'), findsOneWidget);
  });

  testWidgets('no orders: says so', (tester) async {
    await _pump(tester, const []);

    expect(find.text('No hay órdenes de pago todavía'), findsOneWidget);
  });
}
