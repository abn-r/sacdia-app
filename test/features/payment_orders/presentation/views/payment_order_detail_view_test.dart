import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/payment_order_detail_view.dart';

import '../../../investiture_requests/presentation/investiture_test_harness.dart';
import '../../../insurance/presentation/insurance_test_support.dart';

PaymentOrder _order({
  PaymentOrderStatus status = PaymentOrderStatus.issued,
  List<PaymentOrderProof> proofs = const [],
  PaymentOrderPurpose purpose = PaymentOrderPurpose.insurance,
}) =>
    PaymentOrder(
      orderId: 'o-44',
      purpose: purpose,
      folioReference: 'ORD20270044',
      currency: 'MXN',
      unitCostCentavos: 35000,
      totalCentavos: 70000,
      status: status,
      expiresAt: DateTime(2027, 2, 21),
      createdAt: DateTime(2027, 2, 7),
      lines: const [
        PaymentOrderLine(
          lineId: 'l1',
          sequence: 1,
          beneficiaryUserId: 'u-3',
          unitCostCentavos: 35000,
          beneficiaryName: 'Mateo Herrera',
          isStaff: true,
        ),
        PaymentOrderLine(
          lineId: 'l2',
          sequence: 2,
          beneficiaryUserId: 'u-5',
          unitCostCentavos: 35000,
          beneficiaryName: 'Tomás Aguilar',
        ),
      ],
      proofs: proofs,
    );

Future<void> _pump(
  WidgetTester tester,
  PaymentOrder order, {
  bool canManage = true,
}) {
  return pumpApp(
    tester,
    const PaymentOrderDetailView(orderId: 'o-44'),
    overrides: [
      paymentOrderDetailProvider('o-44').overrideWith((ref) async => order),
      canIssuePaymentOrdersProvider.overrideWith((ref) async => canManage),
      insuranceOverviewProvider.overrideWith((ref) async => mockupOverview()),
    ],
  );
}

void main() {
  setUpAll(initInvestitureTestEnv);

  testWidgets('issued: only the current state, "Paso 2 de 4" and a chevron',
      (tester) async {
    await _pump(tester, _order());

    expect(find.text('ORD20270044'), findsOneWidget);
    expect(find.text('Falta el recibo de pago'), findsOneWidget);
    expect(
      find.text(
        'Paga \$700.00 y sube el recibo antes del 21 feb. Si vence, las personas quedan libres para otra orden.',
      ),
      findsOneWidget,
    );
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    // Not an always-visible timeline nor a segmented bar.
    expect(find.byType(SacStepPath), findsNothing);
    expect(find.byType(SacStatusPanel), findsNothing);
    expect(find.text('El campo revisa el pago'), findsNothing);
  });

  testWidgets('tapping the panel opens "Estados de la orden" in order',
      (tester) async {
    await _pump(tester, _order());

    await tester.tap(find.byKey(const Key('payment-order-state-panel')));
    await settle(tester);

    expect(find.text('Estados de la orden'), findsOneWidget);
    expect(find.text('Orden emitida'), findsOneWidget);
    expect(find.text('7 feb'), findsOneWidget);
    expect(find.text('Pagar y subir el recibo'), findsOneWidget);
    expect(find.text('Antes del 21 feb'), findsOneWidget);
    expect(find.text('El campo revisa el pago'), findsOneWidget);
    expect(find.text('Quedan asegurados'), findsOneWidget);
    expect(find.text('Todo el año eclesiástico 2027'), findsWidgets);
  });

  testWidgets('amount, who it covers and documents', (tester) async {
    await _pump(tester, _order());

    expect(find.text('IMPORTE'), findsOneWidget);
    expect(find.text('\$700.00'), findsOneWidget);
    expect(find.text('\$350.00'), findsOneWidget);
    expect(find.text('Año eclesiástico 2027'), findsOneWidget);
    expect(find.text('CUBRE A'), findsOneWidget);
    expect(find.text('Mateo Herrera'), findsOneWidget);
    // Staff keep their role from the insurance overview.
    expect(find.text('Consejero · directiva'), findsOneWidget);
    expect(find.text('Tomás Aguilar'), findsOneWidget);
    expect(find.text('Miembro'), findsOneWidget);
    expect(find.text('DOCUMENTOS'), findsOneWidget);
    expect(find.text('Orden de pago'), findsOneWidget);
    expect(find.text('PDF · caja, pastor o transferencia'), findsOneWidget);
    // No receipt yet.
    expect(find.text('Recibo de pago'), findsNothing);
  });

  testWidgets('one footer action: Subir recibo, with the source sheet',
      (tester) async {
    await _pump(tester, _order());

    expect(find.text('Subir recibo'), findsOneWidget);
    expect(
      find.text(
          'Recibo de caja o comprobante de transferencia · PDF, JPG o PNG'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('payment-order-upload-proof')));
    await settle(tester);

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Elegir PDF'), findsOneWidget);
  });

  testWidgets('rejected: shows the field reason and a re-upload action',
      (tester) async {
    await _pump(
      tester,
      _order(
        status: PaymentOrderStatus.proofRejected,
        proofs: [
          PaymentOrderProof(
            proofId: 'p1',
            fileName: 'r.jpg',
            mimeType: 'image/jpeg',
            status: PaymentOrderProofStatus.rejected,
            rejectReason: 'El monto del depósito no coincide con el total.',
            createdAt: DateTime(2027, 2, 10),
          ),
        ],
      ),
    );

    expect(find.text('Recibo rechazado'), findsOneWidget);
    expect(find.text('Motivo del campo'), findsOneWidget);
    expect(
      find.text('«El monto del depósito no coincide con el total.»'),
      findsOneWidget,
    );
    expect(find.text('Volver a subir recibo'), findsOneWidget);
    expect(find.text('Recibo de pago'), findsOneWidget);
    expect(find.textContaining('Rechazado · 10 feb'), findsOneWidget);
  });

  testWidgets('in review: nothing to do, no footer action', (tester) async {
    await _pump(
      tester,
      _order(
        status: PaymentOrderStatus.proofSubmitted,
        proofs: [
          PaymentOrderProof(
            proofId: 'p1',
            fileName: 'r.jpg',
            mimeType: 'image/jpeg',
            status: PaymentOrderProofStatus.submitted,
            createdAt: DateTime(2027, 2, 9),
          ),
        ],
      ),
    );

    expect(find.text('El campo revisa el pago'), findsOneWidget);
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    expect(find.byKey(const Key('payment-order-upload-proof')), findsNothing);
    // Cancel lives in the menu only while the order can still be cancelled.
    expect(find.byTooltip('Más opciones'), findsNothing);
  });

  testWidgets('more opens one confirmation sheet: who is freed, paid hint',
      (tester) async {
    await _pump(tester, _order());

    await tester.tap(find.byTooltip('Más opciones'));
    await settle(tester);

    // A single sheet: no intermediate menu, no separate dialog.
    expect(find.text('¿Cancelar ORD20270044?'), findsOneWidget);
    expect(
      find.text('Las 2 personas de esta orden quedan libres para incluirlas '
          'en otra.'),
      findsOneWidget,
    );
    expect(find.text('Mateo Herrera'), findsWidgets);
    expect(find.text('Tomás Aguilar'), findsWidgets);
    expect(
      find.textContaining('Si ya pagaste, no la canceles'),
      findsOneWidget,
    );
    expect(find.text('Cancelar orden'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await settle(tester);
    expect(find.text('¿Cancelar ORD20270044?'), findsNothing);
  });

  testWidgets('read-only: no upload and no cancel', (tester) async {
    await _pump(tester, _order(), canManage: false);

    expect(find.byKey(const Key('payment-order-upload-proof')), findsNothing);
    expect(find.byTooltip('Más opciones'), findsNothing);
    // Still readable.
    expect(find.text('Falta el recibo de pago'), findsOneWidget);
  });

  testWidgets('approved: every state is done and nobody can act',
      (tester) async {
    await _pump(tester, _order(status: PaymentOrderStatus.approved));

    expect(find.text('Pago aprobado'), findsOneWidget);
    expect(find.text('Paso 4 de 4'), findsOneWidget);
    expect(
      find.text('Quedan asegurados todo el año eclesiástico 2027.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('payment-order-upload-proof')), findsNothing);
  });

  testWidgets('without the overview the order still renders (no year)',
      (tester) async {
    await pumpApp(
      tester,
      const PaymentOrderDetailView(orderId: 'o-44'),
      overrides: [
        paymentOrderDetailProvider('o-44')
            .overrideWith((ref) async => _order()),
        canIssuePaymentOrdersProvider.overrideWith((ref) async => true),
        insuranceOverviewProvider.overrideWith((ref) async => null),
      ],
    );

    expect(find.text('Falta el recibo de pago'), findsOneWidget);
    expect(find.text('Año eclesiástico 2027'), findsNothing);
    // The staff line falls back to the generic word.
    expect(find.text('Directiva'), findsOneWidget);
  });
}
