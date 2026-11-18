import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/presentation/providers/order_detail_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/upload_receipt_view.dart';

import '../../support/materials_test_support.dart';

void main() {
  setUpAll(initMaterialsL10n);

  Future<void> pumpUpload(WidgetTester tester) => pumpMaterials(
        tester,
        const UploadReceiptView(folioOrId: 'MAT-2026-0142'),
        overrides: [
          orderDetailProvider('MAT-2026-0142')
              .overrideWith((ref) async => testOrder()),
        ],
      );

  testWidgets('amount, date and concept come prefilled', (tester) async {
    await pumpUpload(tester);
    await tester.pump();

    expect(find.text(r'$410.00'), findsOneWidget);
    expect(find.textContaining('Hoy, '), findsOneWidget);
    expect(find.text('MAT-2026-0142'), findsOneWidget);
    expect(find.text('Agregar comprobante'), findsOneWidget);
  });

  testWidgets('missing file shows the error next to the field', (tester) async {
    await pumpUpload(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('receipt-submit')));
    await tester.pump();

    expect(find.byKey(const ValueKey('receipt-file-error')), findsOneWidget);
    expect(find.text('Selecciona un archivo para continuar.'), findsOneWidget);
  });

  testWidgets('the file card opens the Camera / Gallery / File sheet',
      (tester) async {
    await pumpUpload(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('receipt-add-file')));
    await tester.pumpAndSettle();

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Elegir archivo'), findsOneWidget);
  });
}
