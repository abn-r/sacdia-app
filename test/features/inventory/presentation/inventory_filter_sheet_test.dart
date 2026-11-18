import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Only the strings the assertions read: the live count needs real plurals.
class _Labels extends AssetLoader {
  const _Labels();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {
        'inventory': {
          'filter_sheet': {
            'show_items': {
              'one': 'Ver {count} artículo',
              'other': 'Ver {count} artículos',
            },
          },
        },
      };
}

InventoryItem _item(int id, int categoryId, ItemCondition condition) =>
    InventoryItem(
      id: id,
      name: 'Artículo $id',
      category: InventoryCategory(id: categoryId, name: 'Cat $categoryId'),
      quantity: 1,
      condition: condition,
      registeredByName: 'Ana',
      registeredAt: DateTime(2026, 1, id),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final items = [
      _item(1, 1, ItemCondition.bueno),
      _item(2, 1, ItemCondition.regular),
      _item(3, 2, ItemCondition.malo),
    ];
    final container = createTestContainer(
      overrides: [
        inventoryItemsProvider.overrideWith((ref) async => items),
      ],
    );
    // Keep the autoDispose providers alive, as the list behind the sheet does.
    container.listen(filteredInventoryItemsProvider, (_, __) {});
    await container.read(inventoryItemsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _Labels(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: const Scaffold(body: InventoryFilterSheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  testWidgets('the button shows how many items remain, live', (tester) async {
    final container = await pumpSheet(tester);

    expect(find.text('Ver 3 artículos'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inventory-category-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(inventoryFiltersProvider).categoryIds, {2});
    expect(find.text('Ver 1 artículo'), findsOneWidget);
  });

  testWidgets('categories are checkboxes with their counts', (tester) async {
    await pumpSheet(tester);

    final first = find.byKey(const ValueKey('inventory-category-1'));
    expect(
        find.descendant(of: first, matching: find.text('2')), findsOneWidget);

    // Several can be checked at once.
    await tester.tap(first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('inventory-category-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ver 3 artículos'), findsOneWidget);
  });

  testWidgets('sort is a single choice and Limpiar resets it', (tester) async {
    final container = await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('inventory-sort-newest')));
    await tester.pump();
    expect(
      container.read(inventoryFiltersProvider).sortOrder,
      InventorySortOrder.newest,
    );

    await tester.tap(find.byKey(const ValueKey('inventory-sort-valueDesc')));
    await tester.pump();
    expect(
      container.read(inventoryFiltersProvider).sortOrder,
      InventorySortOrder.valueDesc,
    );

    await tester.tap(find.byKey(const ValueKey('inventory-filter-clear')));
    await tester.pump();
    expect(
      container.read(inventoryFiltersProvider).sortOrder,
      InventorySortOrder.nameAsc,
    );
  });

  testWidgets('the state is not in the sheet and there is no "Aplicar"',
      (tester) async {
    await pumpSheet(tester);

    expect(find.text('inventory.filter_sheet.condition_title'), findsNothing);
    expect(find.text('inventory.filter_sheet.apply'), findsNothing);
    expect(find.byKey(const ValueKey('inventory-filter-show')), findsOneWidget);
  });
}
