import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Sin traducciones a propósito: las aserciones leen las llaves crudas.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

InventoryItem _item({
  int id = 1,
  String name = 'Tienda de campaña',
  InventoryCategory category = const InventoryCategory(id: 1, name: 'Equipo'),
  ItemCondition condition = ItemCondition.bueno,
  String? location,
}) =>
    InventoryItem(
      id: id,
      name: name,
      category: category,
      quantity: 2,
      condition: condition,
      location: location,
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
    bool canManage = true,
  }) async {
    tester.view.physicalSize = const Size(900 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final container = createTestContainer(
      overrides: [
        inventoryItemsProvider.overrideWith((ref) async => items),
        canManageInventoryProvider.overrideWith((ref) async => canManage),
        inventoryCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );

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
        const InventoryFilters(categoryIds: {99});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('inventory.view.no_results_title'), findsOneWidget);
    expect(find.text('inventory.view.empty_title'), findsNothing);
  });

  final camp = _item(id: 1, name: 'Tienda de campaña', location: 'Bodega');
  final chair = _item(
    id: 2,
    name: 'Silla plegable',
    condition: ItemCondition.regular,
  );
  final rope = _item(
    id: 3,
    name: 'Cuerda',
    category: const InventoryCategory(id: 2, name: 'Cuerdas'),
    condition: ItemCondition.malo,
  );

  testWidgets('groups items by category and has no top bar actions',
      (tester) async {
    await pumpView(tester, items: [camp, chair, rope]);

    expect(find.byKey(const ValueKey('inventory-group-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-group-2')), findsOneWidget);
    expect(find.text('EQUIPO'), findsOneWidget);
    expect(find.text('CUERDAS'), findsOneWidget);
    expect(find.text('Tienda de campaña'), findsOneWidget);
    // "+" and "Actualizar" left the top bar.
    expect(find.byTooltip('inventory.view.add_button'), findsNothing);
    expect(find.byTooltip('common.refresh'), findsNothing);
    // One fixed primary action.
    expect(find.byKey(const ValueKey('inventory-add-button')), findsOneWidget);
  });

  testWidgets('state chips show counts and filter by condition',
      (tester) async {
    final container = await pumpView(tester, items: [camp, chair, rope]);

    Finder chip(String name) => find.byKey(ValueKey('inventory-chip-$name'));
    expect(
      find.descendant(of: chip('all'), matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chip('regular'), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.ensureVisible(chip('malo'));
    await tester.tap(chip('malo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      container.read(inventoryFiltersProvider).condition,
      ItemCondition.malo,
    );
    expect(find.text('Cuerda'), findsOneWidget);
    expect(find.text('Silla plegable'), findsNothing);
  });

  testWidgets('filter button badge counts the sheet filters', (tester) async {
    final container = await pumpView(tester, items: [camp, chair, rope]);

    expect(find.byKey(const ValueKey('inventory-filter-badge')), findsNothing);

    container.read(inventoryFiltersProvider.notifier).state =
        const InventoryFilters(
      categoryIds: {1, 2},
      sortOrder: InventorySortOrder.newest,
      // The state is a chip, not a sheet filter: it must not count.
      condition: ItemCondition.bueno,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final badge = find.byKey(const ValueKey('inventory-filter-badge'));
    expect(badge, findsOneWidget);
    expect(
        find.descendant(of: badge, matching: find.text('3')), findsOneWidget);
    // Pills for the active sheet filters, removable.
    expect(find.byKey(const ValueKey('inventory-pill-category-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-pill-sort')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inventory-pill-sort')));
    await tester.pump();
    expect(
      container.read(inventoryFiltersProvider).sortOrder,
      InventorySortOrder.nameAsc,
    );
  });

  testWidgets('the more button opens the actions sheet, delete last',
      (tester) async {
    await pumpView(tester, items: [camp]);

    await tester.tap(find.byKey(const ValueKey('inventory-more-1')));
    await tester.pumpAndSettle();

    final view = find.text('inventory.actions.view');
    final edit = find.text('common.edit');
    final change = find.text('inventory.actions.change_condition');
    final delete = find.text('common.delete');
    expect(view, findsOneWidget);
    expect(edit, findsOneWidget);
    expect(change, findsOneWidget);
    expect(delete, findsOneWidget);

    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(view) < top(edit), isTrue);
    expect(top(edit) < top(change), isTrue);
    expect(top(change) < top(delete), isTrue);

    await tester.tap(change);
    await tester.pumpAndSettle();
    for (final condition in ItemCondition.values) {
      expect(
        find.byKey(ValueKey('inventory-condition-${condition.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('read-only roles get no more button and no footer',
      (tester) async {
    await pumpView(tester, items: [camp], canManage: false);

    expect(find.byKey(const ValueKey('inventory-more-1')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-add-button')), findsNothing);
  });
}
