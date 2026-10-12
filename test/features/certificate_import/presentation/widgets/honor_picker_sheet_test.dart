import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_item_editor_sheet.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/honor_picker_sheet.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_category_chip.dart';

import '../../support/catalog_fakes.dart';
import '../../support/test_app.dart';

Future<void> _openPicker(
  WidgetTester tester,
  FakeGetHonors honors, {
  String query = 'Primeros Auxilos basico',
  int? categoryId,
}) async {
  phoneSurface(tester, height: 2400);
  await tester.pumpWidget(wrapTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => HonorPickerSheet.show(
            context,
            initialQuery: query,
            categoryId: categoryId,
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
    overrides: catalogOverrides(honors: honors),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  testWidgets('starts searching with what the OCR read', (tester) async {
    final honors = FakeGetHonors();
    await _openPicker(tester, honors);

    expect(honors.calls.single.search, 'Primeros Auxilos basico');
    expect(honors.calls.single.categoryId, isNull);
    expect(find.text('Primeros Auxilios'), findsOneWidget);
    expect(find.text('Nudos'), findsOneWidget);
  });

  testWidgets('debounces typing by 300 ms and sends one search',
      (tester) async {
    final honors = FakeGetHonors();
    await _openPicker(tester, honors);
    honors.calls.clear();

    await tester.enterText(find.byType(TextField), 'Nu');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'Nudo');
    await tester.pump(const Duration(milliseconds: 299));
    expect(honors.calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(honors.calls.map((c) => c.search), ['Nudo']);
  });

  testWidgets('does not query below 2 letters without a category',
      (tester) async {
    final honors = FakeGetHonors();
    await _openPicker(tester, honors);
    honors.calls.clear();

    await tester.enterText(find.byType(TextField), 'N');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(honors.calls, isEmpty);
    expect(find.text('Escribe al menos 2 letras o elige una categoría.'),
        findsOneWidget);
  });

  testWidgets('a category narrows the search and can be cleared',
      (tester) async {
    final honors = FakeGetHonors((params) => params.categoryId == 7
        ? const Right([knots])
        : const Right([firstAid, knots]));
    await _openPicker(tester, honors);
    honors.calls.clear();

    await tester.tap(find.widgetWithText(HonorCategoryChip, 'Naturaleza'));
    await tester.pumpAndSettle();
    expect(honors.calls.single.categoryId, 7);
    expect(honors.calls.single.search, 'Primeros Auxilos basico');
    expect(find.text('Primeros Auxilios'), findsNothing);
  });

  testWidgets('no results offers to search every category', (tester) async {
    final honors = FakeGetHonors((params) =>
        params.categoryId == null ? const Right([knots]) : const Right([]));
    await _openPicker(tester, honors, categoryId: 3, query: 'zzz');

    expect(find.text('No encontramos «zzz» en Salud'), findsOneWidget);
    await tester.tap(find.text('Buscar en todas las categorías'));
    await tester.pumpAndSettle();
    expect(honors.calls.last.categoryId, isNull);
    expect(find.text('Nudos'), findsOneWidget);
  });

  testWidgets('shows a mapped error with a retry, never the raw failure',
      (tester) async {
    var fail = true;
    final honors = FakeGetHonors((_) => fail
        ? const Left(ServerFailure(message: 'ORA-00942', errorCode: 'NETWORK'))
        : const Right([knots]));
    await _openPicker(tester, honors);

    expect(find.text('Revisa tu conexión a internet e inténtalo de nuevo.'),
        findsOneWidget);
    expect(find.textContaining('ORA-00942'), findsNothing);

    fail = false;
    await tester.tap(find.widgetWithText(SacButton, 'Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Nudos'), findsOneWidget);
  });

  testWidgets('choosing a result fills the editor field and its category',
      (tester) async {
    final honors = FakeGetHonors();
    phoneSurface(tester, height: 2400);
    CertificateImportItem? saved;
    await tester.pumpWidget(wrapTestApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showCertificateImportItemEditor(
              context,
              item: const CertificateImportItem(
                id: 'r',
                type: CertificateImportItemType.honor,
                detectedName: 'Primeros Auxilos basico',
                status: CertificateImportItemStatus.needsReview,
              ),
              onSave: (item) async => saved = item,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
      overrides: catalogOverrides(honors: honors),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elige la especialidad'));
    await tester.pumpAndSettle();
    expect(honors.calls.single.search, 'Primeros Auxilos basico');
    await tester.tap(find.text('Nudos'));
    await tester.pumpAndSettle();

    // The field shows the choice, the category follows it and there is no stamp.
    expect(find.text('Nudos'), findsOneWidget);
    expect(find.text('Naturaleza'), findsWidgets);
    expect(find.text('Sugerida'), findsNothing);

    await tester.tap(find.text('Seleccionar fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SacButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(saved!.honorId, 11);
    expect(saved!.honor!.categoryName, 'Naturaleza');
    expect(saved!.classId, isNull);
    expect(saved!.status, CertificateImportItemStatus.ready);
  });

  testWidgets('changing the category drops a honor that no longer fits',
      (tester) async {
    phoneSurface(tester, height: 2400);
    await tester.pumpWidget(wrapTestApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showCertificateImportItemEditor(
              context,
              item: const CertificateImportItem(
                id: 'r',
                type: CertificateImportItemType.honor,
                honorId: 10,
                honor: CertificateImportHonorRef(
                  id: 10,
                  name: 'Primeros Auxilios',
                  categoryId: 3,
                  categoryName: 'Salud',
                ),
                detectedName: 'Primeros Auxilios',
                status: CertificateImportItemStatus.needsReview,
              ),
              onSave: (_) async {},
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
      overrides: catalogOverrides(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salud').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Naturaleza'));
    await tester.pumpAndSettle();

    expect(find.text('Elige una especialidad de Naturaleza'), findsOneWidget);
    expect(find.text('Falta: especialidad, fecha'), findsOneWidget);
  });
}
