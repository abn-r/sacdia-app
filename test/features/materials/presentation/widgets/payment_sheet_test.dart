import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/presentation/widgets/payment_sheet.dart';

import '../../support/materials_test_support.dart';

void main() {
  setUpAll(initMaterialsL10n);

  testWidgets('shows the data whole and copies each row with a 44pt button',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpMaterials(
      tester,
      Scaffold(
          body: SingleChildScrollView(child: PaymentSheet(order: testOrder()))),
    );

    expect(find.text(r'$410.00'), findsOneWidget);
    expect(find.text('BBVA'), findsOneWidget);
    expect(find.text('012180001234567890'), findsOneWidget);
    expect(find.text('Campo Local Ejemplo A.C.'), findsOneWidget);
    expect(find.text('MAT-2026-0142'), findsOneWidget);
    expect(
      find.textContaining('usa el folio para que lo encontremos'),
      findsOneWidget,
    );

    for (final label in [
      'Copiar CLABE',
      'Copiar Beneficiario',
      'Copiar Concepto',
    ]) {
      final finder = find.bySemanticsLabel(label);
      expect(finder, findsOneWidget, reason: label);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(finder).width, greaterThanOrEqualTo(44));
    }

    await tester.tap(find.bySemanticsLabel('Copiar CLABE'));
    await tester.pump();
    expect(copied.last, '012180001234567890');
    expect(find.text('Copiado: CLABE'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Copiar Concepto'));
    await tester.pump();
    expect(copied.last, 'MAT-2026-0142');
  });

  testWidgets('"Ya pagué" closes the sheet resolving true', (tester) async {
    bool? result;
    await pumpMaterials(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                result = await showPaymentSheet(context, testOrder()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-paid')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
