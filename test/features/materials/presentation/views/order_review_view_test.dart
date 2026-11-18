import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_receipt_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/order.dart';
import 'package:sacdia_app/features/materials/domain/entities/receipt.dart';
import 'package:sacdia_app/features/materials/presentation/providers/order_detail_provider.dart';
import 'package:sacdia_app/features/materials/presentation/providers/receipts_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/order_review_view.dart';

import '../../support/materials_test_support.dart';

void main() {
  setUpAll(initMaterialsL10n);

  Future<void> pumpOrder(
    WidgetTester tester,
    Order order, {
    List<Receipt> receipts = const [],
  }) async {
    final key = order.routeKey;
    await pumpMaterials(
      tester,
      OrderReviewView(folioOrId: key),
      overrides: [
        orderDetailProvider(key).overrideWith((ref) async => order),
        receiptsProvider(key).overrideWith((ref) async => receipts),
      ],
    );
    await tester.pump();
  }

  testWidgets('approved: warning panel, step 2 of 4 and one "Pagar" action',
      (tester) async {
    await pumpOrder(tester, testOrder());

    expect(find.text('Aprobado: falta pagar'), findsOneWidget);
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    expect(find.text(r'Pagar $410.00'), findsOneWidget);
    expect(find.byType(SacButton), findsOneWidget);
    // No refresh button in the bar, no hand-made banners.
    expect(find.byTooltip('Actualizar'), findsNothing);
    expect(find.text('Camisa caqui'), findsOneWidget);
    expect(find.text(r'2 × $205.00'), findsOneWidget);
  });

  testWidgets('tapping the panel lists the four states in a sheet',
      (tester) async {
    await pumpOrder(tester, testOrder());

    await tester.tap(find.byKey(const ValueKey('order-state-panel')));
    await tester.pumpAndSettle();

    expect(find.text('Estados del pedido'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Pagado: lo preparan'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('Lo recoges en el campo local'), findsOneWidget);
  });

  testWidgets('"Pagar" opens the payment sheet over the order', (tester) async {
    await pumpOrder(tester, testOrder());

    await tester.tap(find.byKey(const ValueKey('order-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-amount')), findsOneWidget);
    expect(find.text('012180001234567890'), findsOneWidget);
    expect(find.text('Ya pagué · subir comprobante'), findsOneWidget);
  });

  testWidgets('rejected receipt: error panel, quoted reason, other receipt',
      (tester) async {
    final rejected = testReceipt(
      status: MaterialReceiptStatus.rechazado,
      rejectReason: r'El monto ($400.00) no coincide con el total ($410.00).',
    );
    await pumpOrder(tester, testOrder(), receipts: [rejected]);

    expect(find.text('Comprobante rechazado'), findsWidgets);
    expect(find.text('Sube uno nuevo para continuar.'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-reject-reason')), findsOneWidget);
    expect(
      find.text(r'«El monto ($400.00) no coincide con el total ($410.00).»'),
      findsOneWidget,
    );
    expect(find.text('Subir otro comprobante'), findsOneWidget);
    expect(find.text(r'Pagar $410.00'), findsNothing);
  });

  testWidgets('a receipt under review leaves no action', (tester) async {
    await pumpOrder(tester, testOrder(), receipts: [testReceipt()]);
    expect(find.text('Revisando tu pago'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-action')), findsNothing);
  });

  testWidgets('receipts with a picker temp name show a readable label',
      (tester) async {
    await pumpOrder(
      tester,
      testOrder(),
      receipts: [
        testReceipt(fileName: 'image_picker_9A085501-1B2C.png'),
        testReceipt(
          status: MaterialReceiptStatus.rechazado,
          fileName: 'mi_pago.pdf',
        ),
      ],
    );
    expect(find.text('Comprobante 1'), findsOneWidget);
    expect(find.text('mi_pago.pdf'), findsOneWidget);
    expect(find.textContaining('image_picker_'), findsNothing);
  });

  for (final status in [MaterialStatus.pagada, MaterialStatus.entregada]) {
    testWidgets('${status.name}: panel without action', (tester) async {
      await pumpOrder(tester, testOrder(status: status));
      expect(find.byKey(const ValueKey('order-state-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-action')), findsNothing);
    });
  }

  testWidgets('cancel lives in the menu, with the reason asked in a sheet',
      (tester) async {
    await pumpOrder(
      tester,
      testOrder(status: MaterialStatus.enRevision, folio: 'MAT-2026-0138'),
    );

    expect(find.byKey(const ValueKey('order-action')), findsNothing);
    expect(find.text('Cancelar pedido'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('order-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-menu-copy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('order-menu-cancel')));
    await tester.pumpAndSettle();

    // Confirming with no reason shows the error next to the field.
    await tester.tap(find.byKey(const ValueKey('cancel-confirm')));
    await tester.pump();
    expect(find.byKey(const ValueKey('cancel-reason-error')), findsOneWidget);
    expect(find.text('Ingresa un motivo de cancelación.'), findsOneWidget);
  });

  testWidgets('cancelled order shows its reason and no action', (tester) async {
    await pumpOrder(
      tester,
      testOrder(
        status: MaterialStatus.cancelada,
        cancelReason: 'Pedí de más',
      ),
    );
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Pedí de más'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-action')), findsNothing);
  });
}
