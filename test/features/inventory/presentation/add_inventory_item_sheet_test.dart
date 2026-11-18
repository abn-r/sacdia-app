import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/add_inventory_item_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Sin traducciones a propósito: las aserciones leen las llaves crudas.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> openForm(
    WidgetTester tester, {
    Future<List<InventoryCategory>> Function()? categories,
  }) async {
    tester.view.physicalSize = const Size(900 * 2, 1800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          inventoryCategoriesProvider.overrideWith(
            (ref) =>
                categories?.call() ??
                Future.value(const [
                  InventoryCategory(id: 1, name: 'Equipo'),
                  InventoryCategory(id: 2, name: 'Cuerdas'),
                ]),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _NoTranslations(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showInventoryItemForm(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // MaterialLocalizations (es) names the close tooltip "Cerrar".
  Finder closeButton() => find.byTooltip('Cerrar');

  testWidgets('closing a clean form just closes it', (tester) async {
    await openForm(tester);

    await tester.tap(closeButton());
    await tester.pumpAndSettle();

    expect(find.text('inventory.form.discard_title'), findsNothing);
    expect(find.byKey(const ValueKey('inventory-form-save')), findsNothing);
  });

  testWidgets('closing with unsaved changes asks for confirmation',
      (tester) async {
    await openForm(tester);

    await tester.enterText(find.byType(SacTextField).first, 'Tienda');
    await tester.pumpAndSettle();
    await tester.tap(closeButton());
    await tester.pumpAndSettle();

    expect(find.text('inventory.form.discard_title'), findsOneWidget);

    // Keep editing: the form stays open with what was typed.
    await tester.tap(find.text('inventory.form.keep_editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-form-save')), findsOneWidget);
    expect(find.text('Tienda'), findsOneWidget);

    // Discard: closes for real.
    await tester.tap(closeButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('inventory.form.discard_confirm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-form-save')), findsNothing);
  });

  testWidgets('the quantity changes with the stepper, no keyboard',
      (tester) async {
    await openForm(tester);

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('common.increase_quantity'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the category opens a picker sheet and shows the choice',
      (tester) async {
    await openForm(tester);

    await tester.tap(find.text('inventory.form.category_hint'));
    await tester.pumpAndSettle();
    expect(find.text('Cuerdas'), findsOneWidget);

    await tester.tap(find.text('Cuerdas'));
    await tester.pumpAndSettle();
    expect(find.text('Cuerdas'), findsOneWidget);
    expect(find.text('inventory.form.category_hint'), findsNothing);
  });

  testWidgets('a categories failure shows the retry row', (tester) async {
    await openForm(
      tester,
      categories: () => Future<List<InventoryCategory>>.error('boom'),
    );

    expect(find.text('inventory.form.categories_error'), findsOneWidget);
    expect(find.text('common.retry'), findsOneWidget);
  });

  testWidgets('"Más detalles" is collapsed until tapped', (tester) async {
    await openForm(tester);

    expect(find.text('inventory.form.location_label'), findsNothing);
    await tester.tap(find.text('inventory.form.more_details'));
    await tester.pumpAndSettle();
    expect(find.text('inventory.form.location_label'), findsOneWidget);
  });
}
