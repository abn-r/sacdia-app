import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_receipt_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/presentation/providers/history_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/order_history_view.dart';

import '../../support/materials_test_support.dart';

void main() {
  setUpAll(initMaterialsL10n);

  testWidgets('groups by what to do, with the action as the title',
      (tester) async {
    final orders = [
      testOrder(id: 'pay', folio: 'MAT-2026-0142'),
      testOrder(
        id: 'again',
        folio: 'MAT-2026-0150',
        receipts: [testReceipt(status: MaterialReceiptStatus.rechazado)],
      ),
      testOrder(
        id: 'review',
        folio: null,
        status: MaterialStatus.enRevision,
      ),
      testOrder(
          id: 'done', folio: 'MAT-2026-0119', status: MaterialStatus.entregada),
      testOrder(
          id: 'gone', folio: 'MAT-2026-0100', status: MaterialStatus.cancelada),
    ];
    await pumpMaterials(
      tester,
      const OrderHistoryView(),
      overrides: [historyProvider.overrideWith((ref) async => orders)],
    );

    expect(find.text('Pedidos'), findsOneWidget); // top bar
    expect(find.text('POR ATENDER'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('ENTREGADOS'), findsOneWidget);
    expect(find.text('CANCELADOS'), findsOneWidget);

    expect(find.text(r'Pagar $410.00'), findsOneWidget);
    expect(find.text('Subir otro comprobante'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    // The folio is whole.
    expect(find.text('MAT-2026-0142'), findsOneWidget);
    expect(find.text('Sin folio'), findsOneWidget);
    // Fixed footer.
    expect(find.text('Nuevo pedido'), findsOneWidget);
  });

  testWidgets('empty state keeps the new order button', (tester) async {
    await pumpMaterials(
      tester,
      const OrderHistoryView(),
      overrides: [historyProvider.overrideWith((ref) async => [])],
    );
    expect(find.text('No hay pedidos'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsOneWidget);
  });

  testWidgets('error state offers a retry', (tester) async {
    await pumpMaterials(
      tester,
      const OrderHistoryView(),
      overrides: [
        historyProvider.overrideWith((ref) async => throw Exception('boom')),
      ],
    );
    expect(find.text('No se pudo cargar el historial'), findsOneWidget);
  });
}
