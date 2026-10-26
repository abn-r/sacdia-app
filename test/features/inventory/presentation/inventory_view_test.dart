import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sin traducciones a propósito: las aserciones leen las llaves crudas.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

InventoryItem _item() => InventoryItem(
      id: 1,
      name: 'Tienda de campaña',
      category: const InventoryCategory(id: 1, name: 'Equipo'),
      quantity: 2,
      condition: ItemCondition.bueno,
      registeredByName: 'Ana',
      registeredAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<ProviderContainer> pumpView(
    WidgetTester tester, {
    required List<InventoryItem> items,
  }) async {
    final container = ProviderContainer(
      overrides: [
        inventoryItemsProvider.overrideWith((ref) async => items),
        canManageInventoryProvider.overrideWith((ref) async => true),
        inventoryCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
              home: const InventoryView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  testWidgets('empty inventory without filters shows the empty state',
      (tester) async {
    await pumpView(tester, items: const []);

    expect(find.text('inventory.view.empty_title'), findsOneWidget);
    expect(find.text('inventory.view.no_results_title'), findsNothing);
  });

  testWidgets('empty list with an active search shows "no results"',
      (tester) async {
    final container = await pumpView(tester, items: [_item()]);

    container.read(inventoryFiltersProvider.notifier).state =
        const InventoryFilters(searchQuery: 'zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('inventory.view.no_results_title'), findsOneWidget);
    expect(find.text('inventory.view.no_results_subtitle'), findsOneWidget);
    expect(find.text('inventory.view.empty_title'), findsNothing);
    expect(find.text('inventory.view.add_first_item'), findsNothing);
  });

  testWidgets('empty list with a category filter shows "no results"',
      (tester) async {
    final container = await pumpView(tester, items: [_item()]);

    container.read(inventoryFiltersProvider.notifier).state =
        const InventoryFilters(categoryId: 99);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('inventory.view.no_results_title'), findsOneWidget);
    expect(find.text('inventory.view.empty_title'), findsNothing);
  });
}
