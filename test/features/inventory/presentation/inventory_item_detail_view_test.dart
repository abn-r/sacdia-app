import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_item_detail_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Sin traducciones a propósito: las aserciones leen las llaves crudas.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

InventoryItem _item({
  String? location,
  double? estimatedValue,
  DateTime? purchaseDate,
  String? serialNumber,
  String? notes,
  List<InventoryEvidence> evidences = const [],
}) =>
    InventoryItem(
      id: 1,
      name: 'Tienda de campaña',
      category: const InventoryCategory(id: 1, name: 'Equipo'),
      quantity: 2,
      condition: ItemCondition.bueno,
      location: location,
      estimatedValue: estimatedValue,
      purchaseDate: purchaseDate,
      serialNumber: serialNumber,
      notes: notes,
      evidences: evidences,
      registeredByName: 'Ana',
      registeredAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    InventoryItem item, {
    bool canManage = true,
  }) async {
    tester.view.physicalSize = const Size(900 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWith((ref) async => canManage),
          inventoryItemDetailProvider(1).overrideWith((ref) async => item),
          clubContextProvider.overrideWith((ref) async => null),
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
              home: InventoryItemDetailView(item: item),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('values never filled in read "Sin registrar"', (tester) async {
    await pumpDetail(tester, _item());

    // Ubicación, Valor por pieza, Adquirido, Número de serie.
    expect(find.text('inventory.detail.not_recorded'), findsNWidgets(4));
    // The category is filled in, so it shows its value.
    expect(find.text('Equipo'), findsOneWidget);
  });

  testWidgets('a filled-in field shows its value, not the placeholder',
      (tester) async {
    await pumpDetail(
      tester,
      _item(
        location: 'Bodega',
        estimatedValue: 1500,
        purchaseDate: DateTime(2026, 3, 5),
        serialNumber: 'SN-1',
      ),
    );

    expect(find.text('inventory.detail.not_recorded'), findsNothing);
    expect(find.text('Bodega'), findsOneWidget);
    expect(find.text(r'$1,500.00'), findsOneWidget);
    expect(find.text('SN-1'), findsOneWidget);
  });

  testWidgets('without notes there is no notes group', (tester) async {
    await pumpDetail(tester, _item());

    expect(find.text('INVENTORY.DETAIL.NOTES'), findsNothing);
  });

  testWidgets('notes show in their own group', (tester) async {
    await pumpDetail(tester, _item(notes: 'Revisar varillas'));

    expect(find.text('INVENTORY.DETAIL.NOTES'), findsOneWidget);
    expect(find.text('Revisar varillas'), findsOneWidget);
  });

  testWidgets('has no bottom action bar nor active/inactive text',
      (tester) async {
    await pumpDetail(tester, _item());

    expect(find.text('common.edit'), findsNothing);
    expect(find.text('common.delete'), findsNothing);
    expect(find.text('inventory.detail.active_status'), findsNothing);
    expect(find.text('inventory.detail.inactive_status'), findsNothing);
  });

  testWidgets('more menu offers edit, change state and delete, not view',
      (tester) async {
    await pumpDetail(tester, _item());

    await tester.tap(find.byKey(const ValueKey('inventory-detail-more')));
    await tester.pumpAndSettle();

    expect(find.text('common.edit'), findsOneWidget);
    expect(find.text('inventory.actions.change_condition'), findsOneWidget);
    expect(find.text('common.delete'), findsOneWidget);
    expect(find.text('inventory.actions.view'), findsNothing);
  });

  testWidgets('read-only roles get no more menu', (tester) async {
    await pumpDetail(tester, _item(), canManage: false);

    expect(find.byKey(const ValueKey('inventory-detail-more')), findsNothing);
  });

  testWidgets('no photo shows a tinted placeholder and no counter',
      (tester) async {
    await pumpDetail(tester, _item());

    expect(
      find.byKey(const ValueKey('inventory-hero-placeholder')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inventory-hero-counter')), findsNothing);
  });

  testWidgets('several photos show a page counter "1 / N"', (tester) async {
    final evidences = [
      for (var i = 1; i <= 3; i++)
        InventoryEvidence(
          id: i,
          inventoryId: 1,
          url: 'https://img.test/$i.jpg',
          fileName: '$i.jpg',
          fileType: 'image/jpeg',
          uploadedAt: DateTime(2026, 1, 1),
        ),
    ];
    await pumpDetail(tester, _item(evidences: evidences));

    expect(find.text('1 / 3'), findsOneWidget);
  });
}
